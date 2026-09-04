# Setup: joshrussellrealestate.com

Three things happen here, in order:

1. A key pair on your PC → imported to SiteGround, so `ssh joshrussell` works.
2. A GitHub repo, created by you (see note below).
3. First export from the live site, pushed to that repo.

After step 3, Claude reads and writes the repo. **Claude never SSHes into
SiteGround** — a web session has no SSH client and no egress to port 18765.
The repo is the handoff surface, same as `stephanie-novak-site`.

---

## Part 1 — Key pair on your PC

**Copy one block at a time.** PowerShell fuses multi-line pastes and produces
errors like `Could not resolve hostname hostnamemv`. Every block is one line.

Create `.ssh` if it does not exist:

```
New-Item -ItemType Directory -Force -Path $env:USERPROFILE\.ssh
```

Generate the pair. `-C` is just a label stored inside the key:

```
ssh-keygen -t ed25519 -C "zach-joshrussell" -f $env:USERPROFILE\.ssh\joshrussell
```

It prompts twice for a passphrase. **Press Enter both times** for a blank one.
A passphrase is fine, but it must be typed on every connection unless loaded
with `ssh-add`, and a forgotten one cannot be recovered — the key is replaced.

Print the public half — this is the string SiteGround wants:

```
Get-Content $env:USERPROFILE\.ssh\joshrussell.pub
```

One long line beginning `ssh-ed25519`. Copy all of it, including the trailing
label.

<details>
<summary>macOS / Linux equivalents</summary>

```
ssh-keygen -t ed25519 -C "zach-joshrussell" -f ~/.ssh/joshrussell -N ""
cat ~/.ssh/joshrussell.pub
```
</details>

### Which half goes where

| File | Where it lives | Secret? |
|---|---|---|
| `joshrussell` | Your computer, permanently | **Yes — never share, never commit** |
| `joshrussell.pub` | Pasted into SiteGround | No — safe to paste anywhere |

The private key never crosses the network; the server issues a challenge only
it can answer. So generate the pair on your machine and upload only the public
half — SiteGround's **Import** option. Letting SiteGround generate the pair
also works but reverses the trust direction and is a common source of
passphrase trouble. Use Import.

---

## Part 2 — Import into SiteGround

1. Site Tools for **joshrussellrealestate.com** → **Devs → SSH Keys Manager**
2. Choose **Import** (not Generate)
3. Paste the public key, name it `joshrussell`, save

The connection values for this account are already known:

| | |
|---|---|
| Hostname | `ssh.joshrussellrealestate.com` |
| Username | `u89-zsonvtejlmle` |
| Port | `18765` |

Test the connection:

```
ssh -p 18765 -i $env:USERPROFILE\.ssh\joshrussell u89-zsonvtejlmle@ssh.joshrussellrealestate.com
```

First connection asks about host authenticity — type `yes`. Your machine is
recording the server's fingerprint so it can warn you if the server's identity
ever changes.

---

## Part 3 — The `joshrussell` alias

`scripts/export-wpcode.sh` calls `ssh joshrussell`, so define that alias once.
Add this to `~/.ssh/config` (`$env:USERPROFILE\.ssh\config` on Windows).
The real values are already filled in:

```
Host joshrussell
  HostName ssh.joshrussellrealestate.com
  User u89-zsonvtejlmle
  Port 18765
  IdentityFile ~/.ssh/joshrussell
  IdentitiesOnly yes
```

Verify:

```
ssh joshrussell "pwd && ls ~/www"
```

That prints the account home and the site directories on it. Note the exact
site root — it goes in `README.md` and in the export script's `WP_PATH`.

---

## Part 4 — Create the GitHub repo

Claude cannot create this: the GitHub app on the review session has read/write
on existing repos but no permission to create new ones under your account
(`403 Resource not accessible by integration`). Do it yourself, either way:

**Web:** <https://github.com/new> — name `josh-russell-site`, **Private**, do
not initialize with a README.

**Or with the `gh` CLI:**

```
gh repo create zachpomer1989/josh-russell-site --private --description "joshrussellrealestate.com WordPress custom code (child theme + mu-plugin) and site exports"
```

Then push this scaffold from wherever you have it checked out:

```
cd josh-russell-site && git init -b main && git add -A
```

```
git commit -m "Scaffold joshrussellrealestate.com repo"
```

```
git remote add origin git@github.com:zachpomer1989/josh-russell-site.git && git push -u origin main
```

Finally, tell the review session to attach it — say *"add zachpomer1989/josh-russell-site"* — and Claude can read and write it from then on.

---

## Part 5 — First export

```
./scripts/export-wpcode.sh
```

Read `scripts/export-wpcode.sh` first and set `WP_PATH` to the real site root
from Part 3. The script is read-only against the site: it reads WPCode
snippets, Divi Theme Options integration blocks, and Divi Custom CSS. It never
touches the database password or auth salts.

Then grab the filesystem pieces:

```
scp -r joshrussell:'~/www/joshrussellrealestate.com/public_html/wp-content/mu-plugins/*' mu-plugins/
```

```
scp joshrussell:'~/www/joshrussellrealestate.com/public_html/.htaccess' joshrussell:'~/www/joshrussellrealestate.com/public_html/robots.txt' server-config/
```

Check nothing sensitive slipped in before committing:

```
git add -A && git diff --cached | grep -iE "password|api[_-]?key|secret|token|salt|DB_"
```

Replace any real value with `REDACTED` — the structure is what matters for
review, not the secret. Then commit and push.

---

## Optional — let the server push directly

Only needed if you want to commit from the SiteGround box rather than your PC.
This is a **second, separate** key pair: the server needs its own identity to
authenticate to GitHub. Run these **on the server**, after `ssh joshrussell`:

```
ssh-keygen -t ed25519 -C "siteground-joshrussell" -f ~/.ssh/github_key -N ""
```

```
cat ~/.ssh/github_key.pub
```

Paste that into the repo → **Settings → Deploy keys → Add deploy key**, and
**tick "Allow write access"** — without it the clone works but the push fails.

```
printf 'Host github.com\n  HostName github.com\n  User git\n  IdentityFile ~/.ssh/github_key\n  IdentitiesOnly yes\n' >> ~/.ssh/config && chmod 600 ~/.ssh/config
```

```
ssh -T git@github.com
```

`Hi <name>! You've successfully authenticated, but GitHub does not provide
shell access.` means it worked — that is not an error.

**Clone into your home directory, never into `public_html`.** A repo inside
the web root exposes `.git/` to the internet, handing your full history to
anyone who requests it.

---

## Troubleshooting

| Symptom | Cause |
|---|---|
| `Could not resolve hostname` | Host typo, or `~/.ssh/config` not saved — check `ssh -v joshrussell` |
| Prompt changes to `>>` | PowerShell multi-line paste. Ctrl+C, run one block at a time |
| Connection hangs | Wrong port. SiteGround is 18765, not 22 |
| `Permission denied (publickey)` to SiteGround | Public key not imported, or the private half was imported by mistake |
| `Permission denied (publickey)` to GitHub | Deploy key lacks write access, or `~/.ssh/config` missing |
| `UNPROTECTED PRIVATE KEY FILE` | `icacls $env:USERPROFILE\.ssh\joshrussell /inheritance:r` then `/grant:r "$($env:USERNAME):(R)"` |
| `wp: command not found` | WP-CLI not on PATH — the export script needs it; check with `ssh joshrussell "wp --info"` |
| Forgotten passphrase | Not recoverable. Generate a new pair and re-import |

SiteGround SSH is **key-only** and never accepts password authentication, so
the Site Tools account password entered at a key prompt will always fail.
Three unrelated credentials, easy to confuse: the Site Tools **password** (web
login only), the **key passphrase** (unlocks the private key, locally), and
the **database password** (inside `wp-config.php`).
