# imperfectleader.com — SiteGround + GitHub setup

Setup notes for bringing `imperfectleader.com` (WordPress on SiteGround)
under the same review/change workflow used for AlmaMater. Move this file
into the `imperfectleader.com` repo once that repo exists.

Written for Windows PowerShell. **Copy one block at a time** — PowerShell
fuses multi-line pastes and produces errors like
`Could not resolve hostname hostnamemv`.

---

## What SSH does and does not buy you

A Claude session running in the **cloud** (claude.ai/code, GitHub Actions)
cannot SSH anywhere. Its egress is HTTPS-only through a proxy, port 22 and
18765 are blocked, and no `ssh` binary is installed. Verified, not assumed.

So there are two working models:

| Model | How Claude reaches the site | Setup |
|---|---|---|
| **Repo relay** (what AlmaMater uses) | You SSH in, run a collect script, push to GitHub. Claude reads the repo and writes fixes back to it. You apply them. | This document |
| **Local session** | Claude Code running on your own PC uses *your* SSH key and edits the site directly. | Same key, plus `npm i -g @anthropic-ai/claude-code` on Windows |

The SSH key below is needed either way. If the goal is "Claude edits the
live site," you want the **local session** model — run Claude Code from
PowerShell on your PC, not from the web app.

Also: **SiteGround SSH requires GrowBig or higher.** StartUp plans have no
SSH access at all.

---

## Part 1 — Generate the key pair (your PC)

Create `.ssh` if it does not exist:

```
New-Item -ItemType Directory -Force -Path $env:USERPROFILE\.ssh
```

Generate the pair. `-C` is just a label stored inside the key:

```
ssh-keygen -t ed25519 -C "zach-imperfectleader" -f $env:USERPROFILE\.ssh\imperfectleader_key
```

It prompts twice for a passphrase. **Press Enter both times** for none. A
forgotten passphrase cannot be recovered — the key has to be replaced.

This writes two files:

| File | Secret? |
|---|---|
| `imperfectleader_key` | **Yes — never share, never commit** |
| `imperfectleader_key.pub` | No — this is what you paste into SiteGround |

Print the public half:

```
Get-Content $env:USERPROFILE\.ssh\imperfectleader_key.pub
```

One long line starting `ssh-ed25519`. Copy all of it.

Generate on your own machine and upload only the public half — that is
SiteGround's **Import** option. Letting SiteGround generate the pair also
works but reverses the trust direction and is a common source of
passphrase problems.

---

## Part 2 — Import into SiteGround

1. Site Tools for **imperfectleader.com** → **Devs → SSH Keys Manager**
2. Choose **Import** (not Generate)
3. Paste the public key, name it `imperfectleader-claude`, save

On the same page note your **username** (form `u1234-abcdefgh`),
**hostname**, and **port** — SiteGround uses **18765**, not 22.

Connect:

```
ssh -p 18765 -i $env:USERPROFILE\.ssh\imperfectleader_key USERNAME@HOSTNAME
```

Substitute the real username and hostname. First connection asks about host
authenticity — type `yes`.

If you see `UNPROTECTED PRIVATE KEY FILE`, run these separately:

```
icacls $env:USERPROFILE\.ssh\imperfectleader_key /inheritance:r
```

```
icacls $env:USERPROFILE\.ssh\imperfectleader_key /grant:r "$($env:USERNAME):(R)"
```

Optional — save the connection so later commands are just `ssh imperfectleader`:

```
Add-Content $env:USERPROFILE\.ssh\config "`nHost imperfectleader`n  HostName HOSTNAME`n  User USERNAME`n  Port 18765`n  IdentityFile $env:USERPROFILE\.ssh\imperfectleader_key"
```

---

## Part 3 — Create the GitHub repo

Claude cannot create repositories from a cloud session — GitHub access is
scoped to the one repo the session was opened against. Create it yourself,
either way below.

**Web:** github.com → **New repository** → name `imperfectleader.com` →
**Private** → tick *Add a README* → Create.

**CLI**, if you have `gh` installed:

```
gh repo create imperfectleader.com --private --add-readme --description "Site code, config and SEO exports for imperfectleader.com (WordPress on SiteGround)"
```

Private matches your other site repos (`zpstudio.co`,
`sunrise.equityunion.com`, etc.). Then paste the URL into the Claude session
so it can be attached.

---

## Part 4 — Let the server push to GitHub

This is a **second, separate** key pair. You are now on the Linux server, so
these are Linux commands.

```
ssh-keygen -t ed25519 -C "siteground-imperfectleader" -f ~/.ssh/github_key -N ""
```

```
cat ~/.ssh/github_key.pub
```

Copy it. In GitHub: the `imperfectleader.com` repo → **Settings → Deploy
keys → Add deploy key** → paste → **tick "Allow write access"**. Without
that tick the clone works but the push fails.

Point SSH at that key for GitHub:

```
printf 'Host github.com\n  HostName github.com\n  User git\n  IdentityFile ~/.ssh/github_key\n  IdentitiesOnly yes\n' >> ~/.ssh/config && chmod 600 ~/.ssh/config
```

Verify:

```
ssh -T git@github.com
```

`Hi ...! You've successfully authenticated, but GitHub does not provide
shell access.` means it worked — that is not an error.

---

## Part 5 — Clone on the server

**Clone into your home directory, never into `public_html`.** A repo inside
the web root exposes `.git/` to the internet, handing your full history to
anyone who requests it.

```
cd ~ && git clone git@github.com:zachpomer1989/imperfectleader.com.git review
```

```
cd ~/review && git config user.name "Zach Pomer" && git config user.email "zach@zachpomer.com"
```

At this point the pipe is open in both directions. The collect script that
snapshots `.htaccess`, the child theme, plugin list, WP-CLI indexability
settings and sitemap headers can be adapted from `collect.sh` in the
AlmaMater repo once the site's specifics are known.

---

## Before every push

```
git diff --cached | grep -iE "password|api[_-]?key|secret|token|salt|DB_"
```

Replace any real value with `REDACTED`. Never commit `wp-config.php`,
database dumps, `.env` files, or private keys.

---

## Troubleshooting

| Symptom | Cause |
|---|---|
| `Could not resolve hostname` | `USERNAME@HOSTNAME` pasted literally |
| Prompt changes to `>>` | Multi-line paste. Ctrl+C, one block at a time |
| Connection hangs | Wrong port. SiteGround is 18765 |
| `Permission denied (publickey)` to SiteGround | Public key not imported, or the private key was imported by mistake |
| `Permission denied (publickey)` to GitHub | Deploy key lacks write access, or `~/.ssh/config` missing |
| SSH Keys Manager absent in Site Tools | Plan is StartUp — SSH needs GrowBig or higher |

**Three different credentials, do not confuse them:** the SiteGround account
password (Site Tools web login only — never valid for SSH), the SSH key
passphrase (unlocks the private key locally), and the database password
(inside `wp-config.php`, unrelated to both). SiteGround SSH is key-only and
never accepts a password.
