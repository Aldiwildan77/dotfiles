# Tool inventory

What this repo installs, why it is there, and how well each platform is covered.

Captured from a macOS 26.3 / arm64 machine. Legend:

- **full** — same tool, same name, installed by the manifests
- **brew** — Linux gets it via Homebrew-on-Linux rather than the distro
- **manual** — needs a vendor installer, wired into `install/linux.sh`
- **wsl** — no native Windows equivalent worth using; run it under WSL2
- **n/a** — platform-specific by nature

## Shell and core userland

| Tool | Purpose | macOS | Linux | Windows |
| --- | --- | --- | --- | --- |
| zsh + oh-my-zsh | login shell | full | full | wsl |
| stow | symlink farm for the configs here | full | full | wsl |
| coreutils | GNU tool behaviour on both platforms | full | native | wsl |
| bat | `cat` with highlighting (`batcat` on Debian) | full | full | full |
| ripgrep | fast recursive search | full | full | full |
| fzf | fuzzy finder, wired into ctrl-r and ctrl-t | full | full | full |
| peco | interactive line filter for pipelines | full | brew | wsl |
| yazi | TUI file manager (`y` cd's to where you left it) | full | brew | wsl |
| jq / yq | JSON and YAML on the command line | full | full | full |
| tree, watch, wget, curl | everyday plumbing | full | full | partial |
| gnupg | commit signing, sops/age keys | full | full | full |

## Version control

| Tool | Purpose | macOS | Linux | Windows |
| --- | --- | --- | --- | --- |
| git | — | full | full | full |
| gh | GitHub CLI; also the git credential helper | full | brew | full |
| git-lfs | large files | full | full | full |
| git-filter-repo | history rewriting | full | brew | wsl |
| mercurial | occasional legacy checkouts | full | full | n/a |

## Languages

| Tool | Purpose | macOS | Linux | Windows |
| --- | --- | --- | --- | --- |
| go | primary backend language | full | brew | full |
| tinygo | embedded / wasm targets | full | brew | manual |
| vfox | keeps older Go lines alongside the default | full | brew | manual |
| node (nvm) | pinned in `packages/runtimes.env` | full | full | full |
| bun, deno | alternate JS runtimes | full | full | manual |
| pnpm, yarn, nx | JS package management and monorepos | full | brew | full |
| python (pyenv) | pinned in `packages/runtimes.env` | full | full | full |
| pipx | Python CLIs, each in its own venv | full | full | full |
| rust (rustup) | rustc, cargo, clippy, rust-analyzer | full | full | full |
| ruby | fastlane and the iOS toolchain | full | full | full |
| php 8.4 + composer | with phpredis and xdebug | full | full | full |
| java (SDKMAN!) | pinned in `packages/runtimes.env` | full | full | manual |
| perl | local::lib under `~/perl5` | full | full | wsl |

### Go tools (`packages/go.txt`)

`gopls`, `goimports`, `dlv`, `golangci-lint`, `gotests`, `impl`, `goplay` —
installed with `go install`, so identical on all three platforms.

## Backend and data

| Tool | Purpose | macOS | Linux | Windows |
| --- | --- | --- | --- | --- |
| mysql-client | `mysql` without the server | full | full | full |
| libpq | `psql`, `pg_dump` without the server | full | full | full |
| redis | server plus `redis-cli` | full | full | full |
| sqlite | — | full | full | full |
| protobuf + protolint | `protoc` and schema linting | full | full | full |
| golang-migrate | SQL schema migrations | full | brew | scoop |
| temporal | workflow engine CLI and dev server | full | brew | manual |
| sonar-scanner | static analysis upload | full | brew | manual |
| actionlint | GitHub Actions workflow linting | full | brew | scoop |

## Infrastructure and DevOps

| Tool | Purpose | macOS | Linux | Windows |
| --- | --- | --- | --- | --- |
| docker | Desktop on macOS, Engine from the upstream repo on Linux | full | manual | full |
| kubectl | — | full | brew | full |
| helm | — | full | brew | full |
| k9s | cluster TUI | full | brew | full |
| stern | multi-pod log tailing | full | brew | scoop |
| kubectx / kubens | context and namespace switching | full | brew | scoop |
| terraform | HashiCorp apt repo on Linux | manual | manual | full |
| ansible | — | full | full | wsl |
| awscli | — | full | brew | full |
| gcloud | cask on macOS, install script on Linux | full | manual | full |
| flyctl | Fly.io deploys | full | brew | manual |
| sops + age | encrypted secrets at rest | full | brew | full |
| mkcert | locally-trusted TLS certs | full | brew | scoop |
| mutagen | fast file sync into containers and remotes | full | brew | manual |
| rclone | cloud storage sync | full | full | full |
| qemu | VMs and cross-arch emulation | full | full | n/a |

## SysAdmin and networking

| Tool | Purpose | macOS | Linux | Windows |
| --- | --- | --- | --- | --- |
| mole | SSH tunnel manager | full | brew | wsl |
| arp-scan | layer-2 host discovery | full | full | wsl |
| nload | live interface throughput | full | full | wsl |
| telnet | port poking | full | full | full |
| htop, ncdu, lsof, strace, tcpdump, nmap | Linux gets these from the distro; on macOS install as needed | partial | full | wsl |

## Media and docs

`ffmpeg`, `ghostscript`, `graphviz`, `vips`, `jpeg`, `yt-dlp` — full on macOS
and Linux, mostly available on Windows via winget.

## macOS-only

`fastlane`, `swiftlint`, `swiftgen`, `xcodegen` and the Xcode Command Line
Tools. Casks: `alt-tab`, `copyq`, `herd`, `postman`, `bloomrpc`, `wave`,
`android-platform-tools`, `mole-app`.

## Deliberately excluded

- **GVM** (Go Version Manager) — its shell scripts are bash-only and print
  `command not found: _encode` on every zsh prompt. `vfox` covers the same need.
- **conda / miniconda** — heavyweight, and `pyenv` + `uv` cover the same ground
  without the shell hook.
- **RVM** — `tools.zsh` still sources it if a machine has it, but new machines
  get the system Ruby or `rbenv`.
- Employer-specific tooling, cluster aliases and workspace paths — those live in
  `~/.zshrc.local`, not in this repo.
