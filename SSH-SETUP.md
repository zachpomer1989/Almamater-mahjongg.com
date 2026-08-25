# SSH Setup: Windows → SiteGround → GitHub

Written for Windows PowerShell, which is the client in use here.

**Copy one command block at a time.** PowerShell joins multi-line pastes and
can fuse a command with the line after it, producing errors like
`Could not resolve hostname hostnamemv`. Every block below is a single line
with no inline comments so this cannot happen.

---

## How SSH keys work

A key pair is two matched files:

| File | Where it lives | Secret? |
|---|---|---|
| `siteground_key` | Your computer, permanently | **Yes — never share** |
| `siteground_key.pub` | Uploaded to the server | No — safe to paste anywhere |

On connection the server issues a challenge only the private key can answer.
Your computer answers it locally, so **the private key never crosses the
network**. That is what makes keys stronger than passwords: there is no
secret in transit to intercept.

The consequence: **generate the pair on your own machine and upload only the
public half.** That is SiteGround's *Import* option.

Letting SiteGround generate the pair and downloading the private key also
works, but it reverses the trust direction — the secret is created elsewhere
and travels to you — and it is a common source of passphrase problems. Use
Import.

Three separate key relationships exist in this project. Keeping them
straight avoids most confusion:

| # | Connection | Key generated on |
|---|---|---|
| 1 | Windows PC → SiteGround | Your PC, imported to SiteGround |
| 2 | SiteGround → GitHub | The SiteGround server |
| 3 | Review session → GitHub | Already configured; nothing to do |

---

## Part 1 — Key pair on Windows

Create the `.ssh` folder if it does not exist:

```
New-Item -ItemType Directory -Force -Path $env:USERPROFILE\.ssh
```

Generate the pair. The `-C` value is just a label stored inside the key:

```
ssh-keygen -t ed25519 -C "zach-almamater" -f $env:USERPROFILE\.ssh\siteground_key
```

It prompts twice for a passphrase. **Press Enter both times** for a blank
passphrase. A passphrase is fine if you want one, but it must be typed on
every connection unless you load it with `ssh-add`, and a forgotten one
cannot be recovered — the key has to be replaced.

Print the public key:

```
Get-Content $env:USERPROFILE\.ssh\siteground_key.pub
```

One long line beginning `ssh-ed25519`. Copy all of it.

---

## Part 2 — Import into SiteGround

1. Site Tools → **Devs → SSH Keys Manager**
2. Choose **Import** (not Generate)
3. Paste the public key, name it `almamater-review`, save

On the same page note your **username** (of the form `u1234-abcdefgh`),
**hostname**, and **port** (normally 18765).

Connect, substituting your real values:

```
ssh -p 18765 -i $env:USERPROFILE\.ssh\siteground_key u1234-abcdefgh@your-hostname
```

On the first connection it asks about host authenticity — type `yes`. Your
machine is recording the server's fingerprint so it can warn you if the
server's identity ever changes.

If you see `UNPROTECTED PRIVATE KEY FILE`, run these separately. `icacls` is
the Windows equivalent of `chmod`:

```
icacls $env:USERPROFILE\.ssh\siteground_key /inheritance:r
```

```
icacls $env:USERPROFILE\.ssh\siteground_key /grant:r "$($env:USERNAME):(R)"
```

This is usually unnecessary — a key created by `ssh-keygen` inside your own
profile normally inherits correct permissions.

---

## Part 3 — Let the server push to GitHub

You are now on a Linux server, so these are Linux commands. This is a
**second, separate** key pair: the SiteGround server needs its own identity
to authenticate to GitHub.

```
ssh-keygen -t ed25519 -C "siteground-almamater" -f ~/.ssh/github_key -N ""
```

`-N ""` sets an empty passphrase without prompting.

```
cat ~/.ssh/github_key.pub
```

Copy the output. In GitHub, go to the repo → **Settings → Deploy keys → Add
deploy key**, paste it, and **tick "Allow write access"**. Without that tick
the clone works but the push fails.

Tell SSH to use that key for GitHub:

```
printf 'Host github.com\n  HostName github.com\n  User git\n  IdentityFile ~/.ssh/github_key\n  IdentitiesOnly yes\n' >> ~/.ssh/config && chmod 600 ~/.ssh/config
```

Verify:

```
ssh -T git@github.com
```

Success looks like: `Hi <name>! You've successfully authenticated, but
GitHub does not provide shell access.` That message means it worked — it is
not an error.

---

## Part 4 — Clone and collect

**Clone into your home directory, never into `public_html`.** A repo inside
the web root exposes `.git/` to the internet, handing your full history to
anyone who requests it.

```
cd ~ && git clone git@github.com:zachpomer1989/Almamater-mahjongg.com.git review
```

```
cd ~/review && git checkout claude/almamater-sitemap-indexing-m1plnj
```

```
bash collect.sh
```

`collect.sh` copies `.htaccess` and child theme files, extracts non-secret
wp-config constants, captures the plugin list and indexability settings via
WP-CLI, fetches every candidate sitemap URL with full response headers, and
reports whether each sitemap actually begins with `<?xml`.

It is read-only against your site and never reads database passwords or auth
salts.

**Read the console output.** If `blog_public` is 0, or a sitemap does not
start with `<?xml`, it says so directly — you may have the answer already.

---

## Part 5 — Add the two manual exports

`collect.sh` cannot reach these; they are admin-only downloads.

1. **WPCode:** WP admin → Code Snippets → Tools → Export → `.json`
2. **Divi:** Visual Builder → `⋯` → Portability → Export → `.json`

Move them from Windows to the server (run in PowerShell, not on the server):

```
scp -P 18765 -i $env:USERPROFILE\.ssh\siteground_key $env:USERPROFILE\Downloads\wpcode-export.json u1234-abcdefgh@your-hostname:~/review/01-wpcode-snippets/
```

Or upload them through the GitHub web UI afterward — either is fine.

---

## Part 6 — Push

```
cd ~/review && git add -A
```

Check nothing sensitive slipped in:

```
git diff --cached | grep -iE "password|api[_-]?key|secret|token|salt|DB_"
```

Redact any real value, replacing it with `REDACTED`. Then:

```
git config user.name "Zach Pomer" && git config user.email "zach@zachpomer.com"
```

```
git commit -m "Add site export and diagnostics"
```

```
git push -u origin claude/almamater-sitemap-indexing-m1plnj
```

---

## Troubleshooting

**`Could not resolve hostname`** — `USERNAME@HOSTNAME` was pasted literally.
Substitute the real values from SSH Keys Manager.

**Prompt changes to `>>`** — PowerShell thinks the command is unfinished,
usually from a multi-line paste. Press **Ctrl+C** and run one block at a time.

**`Permission denied (publickey)` to SiteGround** — the public key was not
imported, or the wrong file was imported. Import the `.pub` file only.

**`Permission denied (publickey)` to GitHub** — the deploy key lacks write
access, or `~/.ssh/config` is missing. Test with `ssh -T git@github.com`.

**Connection hangs** — wrong port. SiteGround uses 18765, not 22.

**Forgotten passphrase** — not recoverable. Passphrases encrypt the private
key file; there is no reset. Generate a new pair and re-import. If you know
the passphrase and just want it gone: `ssh-keygen -p -f <keyfile>`, enter the
old one, then press Enter twice.

**Don't confuse three different credentials:**

| Credential | Used for |
|---|---|
| SiteGround account password | Site Tools web login. **Never valid for SSH.** |
| SSH key passphrase | Unlocking the private key file, locally |
| Database password | Inside wp-config.php, unrelated to both |

SiteGround SSH is key-only and does not accept password authentication, so
an account password entered at a key prompt will always fail.

**`wp: command not found`** — WP-CLI is not on the PATH. `collect.sh` skips
those steps and continues; capture the plugin list manually.

---

## If you would rather skip SSH

The browser path needs no credentials: download the WPCode and Divi exports
from WP admin, save browser View Source of the sitemap and homepage, then use
github.com → switch to the branch → **Add file → Upload files**.

You lose only `collect.sh`'s header capture and WP-CLI checks.
