# Dotfiles: Architecture and Network Engineering Guide

This guide has two halves:

1. **Architecture.** How `./setup.sh` turns a fresh macOS, Linux or Windows
   machine into this environment, and how the repo is organised.
2. **Network engineering.** The networking tools this repo installs and
   configures, plus troubleshooting playbooks that use them.

It is written to read well as a PDF too. See
[Rendering this guide as a PDF](#rendering-this-guide-as-a-pdf) at the end.

## Contents

- Part 1: Architecture
  - The big picture
  - Repository layout
  - Stages
  - Platform support
  - Shell configuration
  - Re-running safely
  - Secrets and per-machine files
- Part 2: Network engineering
  - The toolkit, per platform
  - Shell shortcuts
  - Troubleshooting ladder
  - Playbooks: interfaces, DNS, reachability, ports, TLS, HTTP,
    packet capture, LAN discovery, bandwidth, SSH, containers
  - Windows equivalents
  - Reference: private ranges, CIDR, common ports
  - Known gaps
- Rendering this guide as a PDF

# Part 1: Architecture

## The big picture

The repo separates **what** gets installed (data in `packages/`) from **how**
it gets installed (scripts in `install/`) and from **configuration** (one
directory per tool, symlinked into `$HOME` by GNU stow).

```
                        ./setup.sh [stage ...]
                               |
                               v
                     install/bootstrap.sh
           detects OS + arch, runs stages in order
                               |
     +------------+------------+------------+-------------+
     |            |                         |             |
     v            v                         v             v
 packages       langs                      stow         shell
     |            |                         |             |
     |   nvm, pyenv, gvm, rustup,     symlink tool    oh-my-zsh,
     |   SDKMAN!, gem, pipx, go,      dirs into       plugins, fzf,
     |   cargo, npm                   $HOME           yazi, chsh
     |
     +-- macOS  -> install/macos.sh -> Xcode CLT, Homebrew, Brewfile
     +-- Linux  -> install/linux.sh -> apt/dnf/pacman, Linuxbrew,
     |                                 docker/gcloud/terraform repos
     +-- Windows -> stop; run install\windows.ps1 (winget + scoop)
                    or WSL2 and run ./setup.sh inside it
```

Every stage reads its package list from `packages/` and shares helpers from
`install/lib.sh`: logging, OS detection, `DRY_RUN`, manifest parsing and
Homebrew loading.

## Repository layout

```
dotfiles/
  setup.sh               wrapper -> install/bootstrap.sh
  install/
    bootstrap.sh         entry point, stage dispatch
    lib.sh               shared helpers
    macos.sh             Xcode CLT + Homebrew + Brewfile
    linux.sh             native pkgs -> Linuxbrew -> vendor repos
    windows.ps1          winget + scoop, or WSL2
    langs.sh             node, python, go, rust, ruby, java
    stow.sh              symlinks, backing up displaced files
    shell.sh             oh-my-zsh, plugins, fzf, default shell
    doctor.sh            declared vs installed health check
    export.sh            machine -> packages/*.local snapshot
    iterm2.sh            iTerm2 prefs import/export (macOS)
  packages/              the toolchain, as data
    Brewfile             macOS formulae, casks, taps
    brew-linux.txt       Linuxbrew parity set
    linux/               apt.txt, dnf.txt, pacman.txt
    windows/             winget.txt, scoop.txt
    go.txt cargo.txt npm.txt gem.txt pipx.txt
    runtimes.env         pinned node/python/go/java versions
  zsh/ bash/            shell configs (stow packages)
  git/ gh/ vim/ tmux/   tool configs (stow packages)
  screen/ yazi/ zed/
  editorconfig/
  dig/ wget/            ~/.digrc, ~/.wgetrc
  iterm2/               iTerm2 plist (not stowed)
  docs/                 TOOLS.md, this guide
```

A **stow package** is a top-level directory whose contents mirror `$HOME`.
For example, `dig/.digrc` becomes `~/.digrc`, and
`yazi/.config/yazi/` becomes `~/.config/yazi/`.

## Stages

| Stage      | What it does                                         |
|------------|------------------------------------------------------|
| `packages` | OS package manager pass (Brewfile / apt / dnf / ...) |
| `langs`    | Runtimes and the tools installed through them        |
| `stow`     | Symlinks config packages into `$HOME`                |
| `shell`    | oh-my-zsh, plugins, fzf bindings, default shell      |

Run them all, or any subset in the order given:

```
./setup.sh                    # all four stages
./setup.sh langs stow         # just these two
DRY_RUN=1 ./setup.sh          # print the plan, change nothing
SKIP_BREW=1 ./setup.sh        # Linux: skip the Linuxbrew set
SKIP_CHSH=1 ./setup.sh shell  # keep your current login shell
bash install/doctor.sh        # what is missing or drifted
```

### What `langs` manages

| Language | Manager        | Pinned in / list            |
|----------|----------------|-----------------------------|
| Node     | nvm            | `NODE_VERSIONS`, `npm.txt`  |
| JS extra | install script | bun, deno                   |
| Python   | pyenv + pipx   | `PYTHON_VERSIONS`, `pipx.txt` |
| Go       | system go      | `go.txt` (tools)            |
| Go (old) | GVM            | `GO_VERSIONS`               |
| Rust     | rustup         | `cargo.txt`                 |
| Ruby     | system/brew    | `gem.txt`                   |
| Java     | SDKMAN!        | `JAVA_VERSION`              |

Versions live in `packages/runtimes.env`. Bump a line and re-run
`./setup.sh langs` to move every machine together.

## Platform support

| Area              | macOS       | Linux             | Windows        |
|-------------------|-------------|-------------------|----------------|
| Package stage     | Homebrew    | apt/dnf/pacman    | winget + scoop |
| Extra CLI tools   | Brewfile    | Linuxbrew         | scoop          |
| Docker            | colima + CLI| docker-ce repo    | Docker Desktop |
| Language stage    | full        | full              | Go tools only  |
| Stow + shell      | full        | full              | via WSL2       |
| Root user         | n/a         | brew skipped      | n/a            |

Linux notes:

- Docker and Terraform repos are added on apt-based distros. Ubuntu, Debian
  and derivatives such as Mint and Pop!_OS are detected from
  `/etc/os-release`.
- Homebrew refuses to run as root, so a root shell (containers, a fresh VPS)
  gets the native and vendor passes only.

Windows notes:

- `./setup.sh` from Git Bash stops early and points to `install\windows.ps1`.
- Scoop refuses an Administrator shell. Run `windows.ps1` from a normal
  PowerShell, or pass `-SkipScoop`.
- `.\install\windows.ps1 -Wsl` installs WSL2 with Ubuntu. Inside it, the
  Linux path gives you the full environment.

## Shell configuration

zsh is the primary shell; bash is a complete fallback.

```
~/.zshrc  ->  zsh/.zshrc
               sources zsh/zshrc.d/ in this order:
                 base.zsh         Homebrew, core options
                 exports.zsh      PATH, env vars, keg-only formulae
                 plugins.zsh      oh-my-zsh plugin list
                 aliases.zsh      aliases (incl. networking)
                 functions.zsh    helpers (whoisonport, killport...)
                 completions.zsh  completion styles
                 tools.zsh        nvm, pyenv, gvm, cargo, SDKMAN!...
               then ~/.zshrc.local (untracked, per machine)

~/.bashrc ->  bash/.bashrc
               PATH, nvm, pyenv, gem bin, gvm, SDKMAN!,
               a subset of aliases, then ~/.bashrc.local
```

SDKMAN! needs bash 4 or newer. macOS ships bash 3.2, so the Brewfile installs
bash 5 and `.bashrc` only loads SDKMAN! under bash 4+.

## Re-running safely

Every stage can be re-run, and each one skips work that is already done:

- Packages already installed are skipped, and one failing package does not
  stop the rest.
- `stow` backs up real files that sit where a symlink must go
  (`~/.dotfiles-backup/<timestamp>/`). It never moves files that already
  live in the repo through a linked directory.
- Installers are told not to edit `~/.zshrc` or `~/.bashrc`, which are
  symlinks into this repo: SDKMAN! (`rcupdate=false`), GVM
  (`GVM_NO_UPDATE_PROFILE`), bun, and deno (`--no-modify-path`).
- Third-party Homebrew taps must be approved per machine with
  `brew trust --tap <tap>`. The script lists the commands to run and never
  trusts a tap on its own.
- `doctor.sh` compares what the repo declares with what the machine has.

## Secrets and per-machine files

Never committed, by design:

- `~/.ssh/config` and keys: private hostnames and credentials.
- `~/.docker/config.json`: registry auth. The packages stage only merges the
  `cliPluginsExtraDirs` key into it.
- `~/.config/gcloud`, `~/.config/gh/hosts.yml`: tokens.
- `~/.zshrc.local`, `~/.bashrc.local`: employer paths, cluster aliases.
- iTerm2 window arrangements: they store command history.

# Part 2: Network engineering

## The toolkit, per platform

"built-in" means the OS ships it; package names are what this repo installs.

| Tool        | Purpose                      | macOS      | Linux              |
|-------------|------------------------------|------------|--------------------|
| curl        | HTTP(S) client, timing       | Brewfile   | apt/dnf/pacman     |
| wget        | downloads, mirroring         | Brewfile   | apt/dnf/pacman     |
| dig         | DNS queries                  | built-in   | dnsutils/bind-utils|
| ping        | ICMP reachability            | built-in   | iputils            |
| traceroute  | path discovery               | built-in   | traceroute         |
| telnet      | raw TCP check                | Brewfile   | telnet/inetutils   |
| nc          | TCP/UDP port checks          | built-in   | not in lists       |
| nmap        | port and host scanning       | not listed | apt/dnf/pacman     |
| tcpdump     | packet capture               | built-in   | apt/dnf/pacman     |
| arp-scan    | LAN host discovery           | Brewfile   | apt/dnf/pacman     |
| nload       | live interface bandwidth     | Brewfile   | apt/dnf/pacman     |
| lsof / ss   | who owns a socket            | built-in   | lsof; ss is base   |
| net-tools   | ifconfig, netstat, route     | built-in   | apt/dnf/pacman     |
| openssh     | ssh, scp, tunnels            | built-in   | openssh(-client)   |
| rsync       | file sync over SSH           | built-in   | apt/dnf/pacman     |
| openssl     | TLS inspection               | built-in   | dependency         |
| mkcert      | trusted local TLS certs      | Brewfile   | Linuxbrew          |
| mutagen     | file sync + port forwarding  | Brewfile   | Linuxbrew          |
| kubectl     | `port-forward`, cluster net  | Brewfile   | Linuxbrew          |
| colima      | Docker VM, port forwarding   | Brewfile   | n/a                |

On Windows, `cURL.cURL` comes from winget and `grpcurl` and `mkcert` come
from scoop. Everything else uses the PowerShell commands listed under
[Windows equivalents](#windows-equivalents).

### Tool configuration in this repo

`~/.digrc` (from `dig/`):

```
+nocmd        # hide the version banner and echoed query
```

`~/.wgetrc` (from `wget/`), the settings that matter for networking:

```
timeout = 60              # default is 900 s
tries = 3                 # default is 20
server_response = on      # print response headers
timestamping = on         # only fetch if newer
trust_server_names = on   # name file after final redirect
```

## Shell shortcuts

| Command             | Shell     | What it does                          |
|---------------------|-----------|---------------------------------------|
| `myip`              | zsh, bash | public IP via ipecho.net              |
| `localip`           | zsh       | LAN IP (`en0` on macOS, else first)   |
| `ports`             | zsh       | all listening TCP ports               |
| `whoisonport 8080`  | zsh       | process listening on a port           |
| `killport 8080`     | zsh       | `kill -9` whatever holds the port     |
| `dps`               | zsh       | containers with their published ports |
| `dsh <container>`   | zsh       | shell into a container                |
| `kexec <pod>`       | zsh       | shell into a Kubernetes pod           |
| `rkgit`             | zsh       | re-add `~/.ssh/id_rsa` to the agent   |

`killport` uses `kill -9`, so the process gets no chance to clean up. Prefer
`whoisonport` first, then stop the service normally.

## Troubleshooting ladder

Work bottom-up. Each rung assumes the one below it works, so the first
failing rung is where the problem is.

```
  7  Application   curl -v https://host/path      status, headers, body
  6  TLS           openssl s_client -connect h:443  cert, chain, SNI
  5  TCP port      nc -vz host 443                is anything listening?
  4  DNS           dig host +short                does the name resolve?
  3  Routing       traceroute host                where does it stop?
  2  IP / gateway  ping <gateway>, ping 1.1.1.1   can I leave the LAN?
  1  Link          ifconfig / ip -br link         is the interface up?
```

Quick split: `ping 1.1.1.1` works but `ping example.com` does not, so the
problem is DNS, not connectivity.

## Playbooks

Commands are shown for macOS first, then Linux where they differ.

### Interfaces, addresses and routes

```
# macOS
networksetup -listallhardwareports    # interface names (en0 = Wi-Fi?)
ifconfig en0                          # address, status
route -n get default                  # default gateway and interface
scutil --dns | head -30               # resolvers actually in use

# Linux
ip -br addr                           # every interface, one line each
ip route                              # routing table, default gateway
resolvectl status                     # systemd-resolved DNS servers
```

### DNS

```
dig example.com +short                # just the answers
dig example.com A AAAA +noall +answer # specific record types
dig @1.1.1.1 example.com              # ask a specific resolver
dig example.com +trace                # walk from the root servers down
dig -x 93.184.215.14 +short           # reverse lookup (PTR)
dig example.com NS +short             # authoritative servers
dig example.com MX +short             # mail servers
dig _sip._tcp.example.com SRV         # service records
```

Compare your resolver with a public one. If `dig @1.1.1.1` is correct and
plain `dig` is wrong, the local resolver or cache is stale.

Flush caches:

```
# macOS
sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder
# Linux (systemd-resolved)
resolvectl flush-caches
```

Remember `/etc/hosts`: it overrides DNS, and `dig` does not read it.
`ping` and `curl` do, so they can disagree with `dig`.

### Reachability and path

```
ping -c 4 host                        # loss and latency
traceroute host                       # hop-by-hop path (UDP)
traceroute -I host                    # ICMP probes, if UDP is filtered
traceroute -T -p 443 host             # Linux: TCP probes to a port
```

A row of `* * *` hops in `traceroute` is usually a firewall dropping probes,
not a broken path. If the destination answers, the path works.

### Ports and services

```
nc -vz host 443                       # is TCP 443 open?
nc -vzu host 53                       # UDP (unreliable: no reply != closed)
telnet host 25                        # talk to a text protocol by hand
nmap -Pn -p 22,80,443 host            # several ports, skip ping check
nmap -sV -p 443 host                  # identify the service version
sudo nmap -sn 192.168.1.0/24          # host discovery only, no ports
```

Only scan networks and hosts you own or are authorised to test.

Locally, find out what is listening:

```
ports                                 # alias: all listening TCP ports
whoisonport 5432                      # who holds 5432
lsof -nP -iTCP -sTCP:ESTABLISHED      # macOS: open connections
ss -tunap                             # Linux: every socket, with PIDs
```

### TLS and certificates

```
openssl s_client -connect host:443 -servername host </dev/null
openssl s_client -connect host:443 -servername host </dev/null \
  | openssl x509 -noout -subject -issuer -dates -ext subjectAltName
curl -vI https://host                 # handshake summary + headers
```

Always pass `-servername` (SNI). Without it, shared hosts and CDNs return a
default certificate that looks wrong.

Local HTTPS with a certificate your browser trusts:

```
mkcert -install                       # once: add the local CA
mkcert localhost 127.0.0.1 ::1        # writes cert + key files
```

### HTTP and timing

```
curl -sS -o /dev/null -w \
  'dns %{time_namelookup}s  tcp %{time_connect}s  tls %{time_appconnect}s
ttfb %{time_starttransfer}s  total %{time_total}s  code %{http_code}\n' \
  https://example.com

curl -v --resolve example.com:443:203.0.113.10 https://example.com
                                      # test one backend, bypass DNS
curl -x http://proxy:3128 https://example.com   # through a proxy
```

The timing breakdown shows which phase is slow. A large `dns` time points
to the resolver, `tcp` to the network path, `tls` to the handshake, and
`ttfb` to the server.

### Packet capture

```
sudo tcpdump -i en0 -nn host 10.0.0.5          # macOS: Wi-Fi is often en0
sudo tcpdump -i any -nn port 53                # Linux: all interfaces, DNS
sudo tcpdump -i en0 -nn 'tcp port 443 and tcp[tcpflags] & tcp-syn != 0'
sudo tcpdump -i en0 -w capture.pcap port 443   # save for Wireshark
```

Use `-nn` to skip name and port lookups (faster, and no extra DNS traffic).
Open `.pcap` files in Wireshark for deeper analysis.

### LAN discovery

```
arp -a                                # hosts this machine has talked to
sudo arp-scan --localnet              # every responding host on the LAN
sudo arp-scan -I en0 192.168.1.0/24   # pick the interface explicitly
```

`arp-scan` also prints each device's vendor (from its MAC address), which
helps identify unknown devices.

### Bandwidth

```
nload                                 # live in/out per interface
nload -m                              # all interfaces at once
```

For throughput between two hosts, use `iperf3`. It is not in the package
lists; see [Known gaps](#known-gaps).

```
iperf3 -s                             # on the server
iperf3 -c server -t 10                # on the client
iperf3 -c server -R                   # reverse: server -> client
```

### SSH: keys, jump hosts, tunnels

`~/.ssh/config` is deliberately not in this repo. A typical entry:

```
Host bastion
  HostName bastion.example.com
  User deploy
  IdentityFile ~/.ssh/id_ed25519

Host db-internal
  HostName 10.0.3.12
  User deploy
  ProxyJump bastion
```

Tunnels:

```
ssh -L 5432:10.0.3.12:5432 bastion    # local port 5432 -> remote DB
ssh -R 8080:localhost:3000 server     # expose local :3000 on server:8080
ssh -D 1080 bastion                   # SOCKS proxy on localhost:1080
ssh -N -f -L 6379:redis:6379 bastion  # background, no remote shell
ssh -J bastion user@10.0.3.12         # one-off jump without config
```

Keys and the agent:

```
ssh-keygen -t ed25519 -C "you@example.com"
ssh-add --apple-use-keychain ~/.ssh/id_ed25519   # macOS (rkgit alias)
ssh-add -l                            # what the agent holds
ssh -T git@github.com                 # test GitHub auth
ssh -vvv host                         # debug a failing login
```

If `git push` fails with `Permission denied (publickey)`, the agent usually
holds no key. Check with `ssh-add -l`, then `ssh-add` your key.

### Containers and Kubernetes

colima runs Docker in a lightweight VM and forwards published container ports
to `localhost` on the Mac.

```
colima start                          # boot the Docker VM
colima status                         # VM address, runtime, arch
dps                                   # alias: containers + ports
docker network ls                     # bridge/host/custom networks
docker network inspect bridge         # subnets, attached containers
docker run --rm -it --network container:<name> nicolaka/netshoot
                                      # debug inside a container's netns
```

Kubernetes:

```
kubectl port-forward svc/api 8080:80  # local 8080 -> service port 80
kubectl get svc,endpoints -n <ns>     # does the service have endpoints?
kubectl run tmp --rm -it --image=nicolaka/netshoot -- bash
                                      # dig/curl/tcpdump from inside
```

A Service with no endpoints means its selector matches no ready pods: a
label problem, not a network problem.

mutagen can also forward ports to a remote machine over SSH:

```
mutagen forward create --name=db tcp:localhost:5432 \
  bastion:tcp:10.0.3.12:5432
```

## Windows equivalents

PowerShell, no extra installs needed:

| Task                 | Command                                       |
|----------------------|-----------------------------------------------|
| Addresses            | `ipconfig /all`                               |
| Routes               | `route print`                                 |
| DNS lookup           | `Resolve-DnsName example.com -Server 1.1.1.1` |
| Flush DNS            | `ipconfig /flushdns`                          |
| Path                 | `tracert host` or `pathping host`             |
| TCP port check       | `Test-NetConnection host -Port 443`           |
| Listening ports      | `Get-NetTCPConnection -State Listen`          |
| Port -> process      | `netstat -ano` then `Get-Process -Id <pid>`   |
| HTTP                 | `curl.exe -v https://host`                    |

Inside WSL2, the Linux commands in this guide apply as written.

## Reference

### Private and special ranges

| Range            | Use                                  |
|------------------|--------------------------------------|
| 10.0.0.0/8       | private (RFC 1918)                   |
| 172.16.0.0/12    | private (RFC 1918)                   |
| 192.168.0.0/16   | private (RFC 1918)                   |
| 100.64.0.0/10    | carrier-grade NAT, Tailscale         |
| 169.254.0.0/16   | link-local (no DHCP answer)          |
| 127.0.0.0/8      | loopback                             |
| fc00::/7         | IPv6 unique local                    |
| fe80::/10        | IPv6 link-local                      |

A `169.254.x.x` address means the interface asked for DHCP and nobody
answered.

### CIDR quick table

| Prefix | Netmask         | Addresses | Usable hosts |
|--------|-----------------|-----------|--------------|
| /32    | 255.255.255.255 | 1         | 1 (host)     |
| /31    | 255.255.255.254 | 2         | 2 (p2p link) |
| /30    | 255.255.255.252 | 4         | 2            |
| /29    | 255.255.255.248 | 8         | 6            |
| /28    | 255.255.255.240 | 16        | 14           |
| /27    | 255.255.255.224 | 32        | 30           |
| /26    | 255.255.255.192 | 64        | 62           |
| /25    | 255.255.255.128 | 128       | 126          |
| /24    | 255.255.255.0   | 256       | 254          |
| /23    | 255.255.254.0   | 512       | 510          |
| /22    | 255.255.252.0   | 1,024     | 1,022        |
| /20    | 255.255.240.0   | 4,096     | 4,094        |
| /16    | 255.255.0.0     | 65,536    | 65,534       |

Usable hosts is the address count minus 2 (network and broadcast), except for
/31 and /32. In AWS VPCs, subtract 5 per subnet instead of 2.

### Common ports

| Port      | Service            | Port      | Service            |
|-----------|--------------------|-----------|--------------------|
| 22/tcp    | SSH                | 3306/tcp  | MySQL              |
| 25/tcp    | SMTP               | 5432/tcp  | PostgreSQL         |
| 53/udp+tcp| DNS                | 6379/tcp  | Redis              |
| 80/tcp    | HTTP               | 6443/tcp  | Kubernetes API     |
| 123/udp   | NTP                | 7233/tcp  | Temporal           |
| 443/tcp   | HTTPS              | 8080/tcp  | HTTP alt / proxies |
| 443/udp   | HTTP/3 (QUIC)      | 9090/tcp  | Prometheus         |
| 587/tcp   | SMTP submission    | 27017/tcp | MongoDB            |

## Known gaps

These differences exist in the repo today; they are noted here rather than
silently papered over.

- **nmap, mtr and iperf3 are not in the macOS Brewfile.** Linux installs
  nmap. To add them on macOS, append to `packages/Brewfile`:
  `brew "nmap"`, `brew "mtr"`, `brew "iperf3"`.
- **netcat is not in the Linux lists.** macOS ships `nc`; on Linux, install
  `netcat-openbsd` (apt) or `nmap-ncat` (dnf).
- **`mole` in the Brewfile is a Mac disk cleaner** (mole.fit), not an SSH
  tunnel manager as its Brewfile comment says. Use `ssh -L` or mutagen for
  tunnels.
- **`localip` assumes `en0`** on macOS. On Macs where Wi-Fi is `en1`, check
  `networksetup -listallhardwareports`.
- **Networking shortcuts are zsh-only**, apart from `myip`.
- **`grpcurl`** is installed on Windows only (scoop).

# Rendering this guide as a PDF

Diagrams are plain text and code lines are kept under 80 characters, so the
guide renders the same on GitHub, in an editor preview and in a PDF.

With pandoc and Typst (no LaTeX needed):

```
brew install pandoc typst
pandoc docs/NETWORKING.md -o NETWORKING.pdf --pdf-engine=typst \
  -V papersize=a4 -V margin=2cm
```

Without installing anything: open the file on GitHub, then print the page
from the browser and choose **Save as PDF**.
