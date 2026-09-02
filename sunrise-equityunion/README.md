# sunrise.equityunion.com — SiteGround SSH + GitHub setup

> **Moved.** The maintained copy of this guide now lives in its own
> repository: https://github.com/zachpomer1989/sunrise.equityunion.com
> This copy is kept only as a record of the setup session.

Goal: a Claude Code session can SSH into the SiteGround server that hosts
`sunrise.equityunion.com` and make changes directly, with all scripts and
site code tracked in a dedicated GitHub repository.

Current state (checked 2026-09-02):

| Item | Status |
|---|---|
| DNS | `sunrise.equityunion.com` A record → `35.215.68.146` (GoDaddy → SiteGround). Resolves correctly. |
| SSH key | **Done.** Generated on the PC, imported to SiteGround as `sunrise`. Login from the PC works; WP-CLI 2.12 and PHP 8.2 confirmed on the server. |
| Server | `c1102614.sgvps.net`, user `u147-ugiaoph0ddm3`, port 18765. |
| GitHub repo | **Done.** `zachpomer1989/sunrise.equityunion.com`, private, seeded with this guide. |
| SSH from Claude web sessions | **Not possible.** Cloud sessions sit behind an HTTP-only proxy that cannot carry SSH, to any host. Run Claude Code on the PC instead — Part 4. |
| Claude Code on the PC | **Done.** Installed, `ssh sunrise` alias in place, and a local session ran `wp --info` on the server. Remote control enabled. |
| WordPress root on the server | `~/www/sunrise.equityunion.com/public_html` (SiteGround layout; confirm with `ls ~/www`). |

Written for Windows PowerShell. **Copy one command block at a time.**
Every block is a single line so PowerShell cannot fuse two commands.

---

## Part 1 — Generate the key pair (on your PC)

Create the `.ssh` folder if it does not exist:

```
New-Item -ItemType Directory -Force -Path $env:USERPROFILE\.ssh
```

Generate a dedicated key for this site. Press Enter twice for a blank
passphrase (a passphrase would block unattended use by Claude sessions):

```
ssh-keygen -t ed25519 -C "sunrise-equityunion" -f $env:USERPROFILE\.ssh\sunrise_key
```

Print the **public** key. This is the half you paste into SiteGround:

```
Get-Content $env:USERPROFILE\.ssh\sunrise_key.pub
```

One long line beginning `ssh-ed25519`. Copy all of it.

The other file, `sunrise_key` with no extension, is the private key.
Never commit it, never paste it into chat or into SiteGround. It stays on
the PC and is used there by Claude Code (Part 4).

---

## Part 2 — Import the key into SiteGround

1. Site Tools for `sunrise.equityunion.com` → **Devs → SSH Keys Manager**
2. Choose **Import** (not Generate)
3. Paste the public key, name it `sunrise-claude`, save
4. On the same page open **Manage → SSH credentials** and copy the
   **username** (form `u1234-abcdefgh`), **hostname**, and **port** (18765)

Test from your PC, substituting your real values:

```
ssh -p 18765 -i $env:USERPROFILE\.ssh\sunrise_key u147-ugiaoph0ddm3@c1102614.sgvps.net
```

Type `yes` at the host-authenticity prompt on the first connection.
Success is a Linux shell prompt. Confirm WP-CLI is available:

```
wp --info
```

Then `exit`.

If `sunrise.equityunion.com` does not exist yet in Site Tools, add it first
(Site Tools → **Domain → Subdomains**, or create it as its own site), and
issue a Let's Encrypt certificate under **Security → SSL Manager** once the
GoDaddy A record has propagated.

---

## Part 3 — Create the GitHub repository

The Claude GitHub integration is not permitted to create repositories, so:

1. github.com → **New repository**
2. Name: `sunrise.equityunion.com` (same convention as
   `Almamater-mahjongg.com`), **Private**, no README, no .gitignore
3. Create it

Then let Claude reach it. Either:

- **GitHub side:** github.com → Settings → Applications → **Claude** →
  Configure → Repository access → add `sunrise.equityunion.com`, or
- **Claude side:** claude.ai → Settings → Connectors → GitHub → reconnect and
  tick the new repository.

Finally, move this folder into the new repo. From a Claude session, once the
repo is in scope:

```
git clone https://github.com/zachpomer1989/sunrise.equityunion.com.git
```

and copy `sunrise-equityunion/*` plus the `.gitignore` from this repo into it.

---

## Part 4 — Let Claude make changes over SSH

### Why not from the web session

Claude Code on the web runs each session in a cloud container behind an
HTTP/HTTPS proxy. SSH is not HTTP. A test from a session opened a tunnel to
the SiteGround host on port 18765 and one to `github.com` on port 22, and
neither carried a single byte of SSH data. The proxy's own documentation
lists raw TCP protocols as unsupported. **No environment setting (allowed
domains, environment variables, setup script) changes this**, so the private
key must never be uploaded anywhere. It stays on the PC.

### The working path: Claude Code on your PC

The PC already has the key and already reaches the server, so Claude Code
running there can SSH with nothing more to configure. PowerShell, one line
at a time.

**1. Install Claude Code** (no administrator needed):

```
irm https://claude.ai/install.ps1 | iex
```

Close and reopen PowerShell, then confirm:

```
claude --version
```

**2. Install Git for Windows** from https://git-scm.com/downloads/win with
the default options. Optional, but it gives Claude a Bash tool and lets it
clone the GitHub repo. Reopen PowerShell afterwards.

**3. Create an `ssh sunrise` shortcut** so nobody has to type the key path
and port again:

```
Add-Content -Path $env:USERPROFILE\.ssh\config -Value "Host sunrise`n  HostName c1102614.sgvps.net`n  User u147-ugiaoph0ddm3`n  Port 18765`n  IdentityFile ~/.ssh/sunrise_key`n  IdentitiesOnly yes"
```

Test it. A server prompt means it works; type `exit` to leave:

```
ssh sunrise
```

**4. Make a project folder and start Claude Code in it:**

```
New-Item -ItemType Directory -Force -Path $env:USERPROFILE\sunrise; Set-Location $env:USERPROFILE\sunrise; claude
```

Once the GitHub repo exists (Part 3) and Git for Windows is installed, use
the repo as the folder instead:

```
Set-Location $env:USERPROFILE; git clone https://github.com/zachpomer1989/sunrise.equityunion.com.git sunrise; Set-Location sunrise; claude
```

**5. First message to Claude in that session:**

> Run `ssh sunrise "wp --info"` to confirm you can reach the SiteGround
> server, then list the WordPress site path and active plugins.

From then on Claude can read and change files, run WP-CLI, and back up and
restore, all over `ssh sunrise`.

**6. Steer from your phone or the web (optional).** Inside the local
session type `/remote-control`. The session keeps running on the PC and
becomes visible at claude.ai/code and in the mobile app.

### Alternative: GitHub Actions runner

Once the repo exists, a workflow can SSH into SiteGround from a GitHub
runner, with the private key stored as a repository secret. Claude web
sessions then push a commit and the action executes it on the server. It is
slower and less interactive than the PC path but needs no PC switched on.
Ask for it when wanted.

### `ssh-setup.sh`

The script in this folder is for **Linux shells only**: WSL, a GitHub
Actions runner, or a self-hosted Claude environment. It reads the host,
user, port and base64-encoded key from `SITEGROUND_SSH_*` environment
variables, writes `~/.ssh/config`, and tests the connection. Not for
PowerShell and not for Claude web sessions.

---

## Troubleshooting

**`Permission denied (publickey)`** — the `.pub` file was not imported, or
the private key in the environment does not match it. SiteGround never
accepts passwords over SSH.

**Connection hangs or times out from a Claude web session** — expected;
web sessions cannot carry SSH. Use Claude Code on the PC (Part 4).

**`ssh: Could not resolve hostname`** — a placeholder such as
`your-hostname` was pasted literally, or the `~/.ssh/config` line has a typo.
Open `$env:USERPROFILE\.ssh\config` in Notepad and check the `Host sunrise` block.

**Ran a Linux command in PowerShell** (`bash`, `apt-get` "not recognized") —
those lines belong on the SiteGround server or in a Linux shell, not on the PC.

**`wp: command not found`** — WP-CLI is missing from the PATH on that
server; SiteGround normally provides it. Check with `ls /usr/local/bin/wp`.
