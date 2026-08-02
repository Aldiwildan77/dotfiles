# Dotfiles

Config and toolchain for coding, backend, infrastructure and sysadmin work —
reproducible on macOS, Linux and (best-effort) Windows.

Configs are symlinked with [GNU stow](https://www.gnu.org/software/stow/); the
toolchain is declared as plain-text manifests under `packages/` and installed
by the scripts in `install/`.

## Quick start

```bash
git clone https://github.com/Aldiwildan77/dotfiles ~/dotfiles
cd ~/dotfiles
./setup.sh
```

Clone to `~/dotfiles` specifically — the zsh config resolves everything relative
to that path. To use a different location, export `DOTFILES_DIR` in your shell.

**Windows** — from PowerShell:

```powershell
.\install\windows.ps1        # native packages via winget + scoop
.\install\windows.ps1 -Wsl   # WSL2 + Ubuntu, then run ./setup.sh inside it
```

## Usage

```bash
./setup.sh                  # every stage
./setup.sh packages         # OS package manager pass only
./setup.sh langs stow       # a specific subset, in the order given
./setup.sh --help           # stage list and environment variables

DRY_RUN=1 ./setup.sh        # print the plan, change nothing
SKIP_BREW=1 ./setup.sh      # Linux: skip the Homebrew parity set

./install/doctor.sh         # what is declared vs what is installed
./install/doctor.sh -v      # per-tool detail
./install/export.sh         # snapshot this machine into packages/*.local
```

### Stages

| Stage | What it does |
| --- | --- |
| `packages` | OS package manager — `brew bundle` on macOS, apt/dnf/pacman + Linuxbrew + vendor installers on Linux |
| `langs` | Runtimes via nvm / pyenv / rustup / SDKMAN!, then the tools installed through them |
| `stow` | Symlinks the config packages into `$HOME` |
| `shell` | oh-my-zsh, custom plugins, fzf key bindings, default shell |

Every stage is idempotent — re-running skips what is already in place.

## Layout

```
dotfiles/
├── setup.sh                 # wrapper around install/bootstrap.sh
├── install/
│   ├── bootstrap.sh         # entry point, stage dispatch
│   ├── lib.sh               # logging, OS detection, manifest parsing
│   ├── macos.sh             # Xcode CLT + Homebrew + Brewfile
│   ├── linux.sh             # native packages → Linuxbrew → vendor installers
│   ├── windows.ps1          # winget + scoop, or WSL2
│   ├── langs.sh             # node, python, go, rust, ruby, java
│   ├── stow.sh              # symlinking, with backup of displaced files
│   ├── shell.sh             # oh-my-zsh and friends
│   ├── doctor.sh            # declared vs installed
│   └── export.sh            # machine → packages/*.local snapshot
├── packages/                # the toolchain, as data
│   ├── Brewfile             # macOS (formulae + casks + taps)
│   ├── brew-linux.txt       # Linuxbrew parity set
│   ├── linux/{apt,dnf,pacman}.txt
│   ├── windows/{winget,scoop}.txt
│   ├── {go,cargo,npm,gem,pipx}.txt
│   └── runtimes.env         # pinned node/python/go/java versions
├── zsh/                     # stow package → ~/.zshrc, ~/.zshrc.local.example
│   └── zshrc.d/             # base, exports, plugins, aliases, functions,
│                            # completions, tools — sourced in that order
├── bash/                    # → ~/.bashrc, ~/.bash_profile (fallback shell)
├── git/                     # → ~/.gitconfig, ~/.gitignore_global
├── gh/                      # → ~/.config/gh/config.yml
├── vim/ tmux/ screen/       # → ~/.vimrc, ~/.tmux.conf, ~/.screenrc
├── yazi/ zed/               # → ~/.config/yazi/, ~/.config/zed/
├── editorconfig/            # → ~/.editorconfig
├── dig/ wget/               # → ~/.digrc, ~/.wgetrc
└── docs/TOOLS.md            # what is installed and why, per platform
```

Vim, tmux and yazi share one Flexoki Dark palette, so the terminal looks like a
single environment rather than three unrelated tools. The vim colours are
written inline rather than pulled in as a colorscheme plugin — a bare `vim` on a
fresh server looks right with nothing installed beyond `~/.vimrc`.

Yazi's plugins and flavors are **not** committed. `package.toml` pins each one
by revision and hash, and `install/shell.sh` runs `ya pkg install` to rebuild
them.

### iTerm2 (macOS)

iTerm2 is not a stow package. It keeps everything — profiles, colours, key
bindings and window arrangements — in one binary plist at
`~/Library/Preferences/com.googlecode.iterm2.plist`, and rewrites it on quit,
so a symlink there does not survive. It gets its own script instead:

```bash
./install/iterm2.sh export   # live prefs -> iterm2/com.googlecode.iterm2.plist
./install/iterm2.sh diff     # what an export would change
./install/iterm2.sh import   # that file  -> live prefs (backs up first)
```

Quit iTerm2 before either direction.

**The export is sanitised, and that is not optional.** iTerm2 stores each
session's recorded shell command history *inside* the window arrangement. On
the machine this repo was built from, the `Daily` arrangement contained 273
recorded commands and 434 visited directories — including a live API secret
that had been passed inline as `SOMEVAR=... command`. `install/iterm2-sanitize.py`
drops those keys, drops the 38 per-machine `NoSync*` keys, and rewrites `$HOME`
to `~`. It refuses to write at all if a credential pattern survives, and
`doctor.sh` re-scans the committed file.

What is kept: profiles, colours, fonts, key bindings, and the arrangement's
window and split geometry. What is dropped: command history, directory
history, session environment, and shell-integration host logs.

If you pass secrets inline on the command line, they end up in this plist.
Put them in `~/.zshrc.local` instead.

## Adding a tool

Manifests are the source of truth, so adding a tool means editing data, not code:

1. Add it to `packages/Brewfile` (macOS) **and** the Linux manifest that covers
   it — `packages/linux/apt.txt` if Debian ships it, otherwise
   `packages/brew-linux.txt`.
2. Add the Windows equivalent to `packages/windows/winget.txt` or `scoop.txt`.
3. Add a `check` line in `install/doctor.sh` if it is something you would notice
   missing.
4. Run `./setup.sh packages` to install it locally, then commit.

`./install/export.sh` goes the other direction: it snapshots what a machine
already has into `packages/*.local` files so you can diff them against the
curated manifests and fold in anything that drifted. Those `.local` files are
gitignored — a raw dump always carries one-off installs that do not belong in
the repo.

## Secrets

Nothing in this repo holds a credential, and nothing should.

- `~/.zshrc.local` — API keys, tokens, machine-specific paths.
  Start from `zsh/.zshrc.local.example`. Sourced last, so it overrides
  everything committed here.
- `~/.zshrc.d/<company>.zsh` — one profile per employer: private Go module
  domains, workspace paths, production cluster aliases. Start from
  `zsh/.company.zsh.example` and select one with `COMPANY=acme`.
  A tracked fallback lives at `zsh/profiles/<company>.zsh` for profiles that
  hold nothing private; the `~/.zshrc.d` copy wins when both exist.
- `~/.gitconfig.work` — work identity and internal remote rewriting.
  Start from `git/.gitconfig.work.example`. Pulled in by `includeIf` for repos
  under `~/Workspace/`.

Company profiles previously lived in `zsh/zshrc.d/<company>/` **inside this
repo**, which published a GCP project id, an internal Go module domain and
production cluster names to a public git history. `.gitignore` blocks
`zsh/zshrc.d/*/` and `doctor.sh` fails if that layout is ever tracked again.

```
COMPANY=acme  →  ~/.zshrc.d/acme.zsh          (private, wins)
              →  zsh/profiles/acme.zsh        (tracked fallback)
              →  otherwise: prints both paths it tried
```

Both paths are gitignored. Better still, keep secrets out of the shell entirely
and resolve them at use time with `sops`, `age` or a password manager CLI —
`.zshrc.local.example` shows the pattern.

### One consequence of stowing `.config` packages

Stowing `gh`, `yazi` and `zed` points `~/.config/<tool>` at a directory **inside
this repo**, so those tools write their runtime state here:

| Tool | Writes | Handled by |
| --- | --- | --- |
| gh | `hosts.yml` — your OAuth token | gitignored |
| yazi | `plugins/`, `flavors/` | gitignored, rebuilt by `ya pkg install` |
| zed | re-adds `ssh_connections` as you add remotes | review before committing |

`./install/doctor.sh` has a secret guard that fails if any of these — or a
credential pattern in any tracked file — ever makes it into the index. Run it
before pushing.

Deliberately **not** exported: `~/.ssh/config` (private hosts and key paths),
`~/.docker/config.json` (registry auth), `~/.config/gcloud`, and
`~/.config/psysh/psysh_history`. Those are per-machine and hold credentials or
session data.

## Platform notes

**macOS** — the primary target. Everything in `packages/Brewfile` installs,
including casks and the Apple-platform tools (fastlane, swiftlint, xcodegen).

**Linux** — full parity for the CLI toolchain. The native package manager runs
first, then Homebrew-on-Linux fills in what the distro does not carry, then
vendor repos supply docker, gcloud and terraform. Arch needs the least from
Homebrew; Debian the most. GUI casks have no equivalent and are skipped.

**Windows** — packages only. The zsh configuration does not apply, so
`install/windows.ps1 -Wsl` is the recommended path: it gets you a real Linux
environment where the rest of this repo works unchanged.
