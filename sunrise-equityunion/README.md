# sunrise.equityunion.com — SiteGround SSH + GitHub setup

Goal: a Claude Code session can SSH into the SiteGround server that hosts
`sunrise.equityunion.com` and make changes directly, with all scripts and
site code tracked in a dedicated GitHub repository.

Current state (checked 2026-09-02):

| Item | Status |
|---|---|
| DNS | `sunrise.equityunion.com` A record → `35.215.68.146` (GoDaddy → SiteGround). Resolves correctly. |
| GitHub repo | **Not created yet.** The Claude GitHub integration cannot create repositories (403). Create it by hand — Part 2. |
| Network from Claude sessions | **Blocked.** The environment's egress policy denies `c1102614.sgvps.net` on port 18765. SSH will fail until that host is allowed — Part 4. |
| SSH client in Claude sessions | **Missing.** The container image has no `ssh` binary. `ssh-setup.sh` installs `openssh-client` itself; add it to the environment setup script to avoid the delay — Part 4. |
| SSH key | Generated and imported to SiteGround as `sunrise-claude`. Host `c1102614.sgvps.net`, user `u147-ugiaoph0ddm3`, port 18765. |

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
Never commit it, never paste it into chat. It goes only into the Claude
environment secret in Part 4.

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

## Part 4 — Let Claude sessions SSH in

A Claude Code web session runs in a fresh container each time, so the key
and connection details must come from the **environment configuration**,
not from anything saved inside a session.

At claude.ai/code → **Environments** → the environment you use for this
repo → **Edit**:

### 4a. Environment variables

| Name | Value |
|---|---|
| `SITEGROUND_SSH_HOST` | `c1102614.sgvps.net` |
| `SITEGROUND_SSH_USER` | `u147-ugiaoph0ddm3` |
| `SITEGROUND_SSH_PORT` | `18765` |
| `SITEGROUND_SSH_KEY_B64` | the private key, base64-encoded (below) |

Base64 avoids newline handling problems when pasting a multi-line key.
Produce it on your PC and copy the output:

```
[Convert]::ToBase64String([IO.File]::ReadAllBytes("$env:USERPROFILE\.ssh\sunrise_key"))
```

### 4b. Setup script

Under the environment's **Setup script** (runs when a session starts), add:

```
apt-get install -y -q openssh-client
```

`ssh-setup.sh` does this itself if the binary is missing, but a setup script
makes every session start ready.

### 4c. Network access

The default policy blocked `sunrise.equityunion.com` from this session.
Add `c1102614.sgvps.net` to the environment's allowed domains, or switch the
environment to a policy that permits it. Port 18765 must be reachable, not
only 443. A test from this session confirmed 18765 is currently refused.
Docs: https://code.claude.com/docs/en/claude-code-on-the-web

### 4d. Verify

Start a new session in that environment and run:

```
bash sunrise-equityunion/ssh-setup.sh
```

It writes the key to `~/.ssh`, creates a `sunrise` host alias, and runs
`hostname` and `wp --info` on the server. From then on any session can use
`ssh sunrise` and Claude can make changes on the live site.

---

## Troubleshooting

**`Permission denied (publickey)`** — the `.pub` file was not imported, or
the private key in the environment does not match it. SiteGround never
accepts passwords over SSH.

**Connection hangs or times out from a Claude session** — the network
policy still blocks the host, or port 18765 is not allowed. From your PC the
same command works, which confirms it is the policy, not the key.

**`CONNECT tunnel failed, response 403`** — same cause: egress policy.

**`wp: command not found`** — WP-CLI is missing from the PATH on that
server; SiteGround normally provides it. Check with `ls /usr/local/bin/wp`.
