# SSH Setup: SiteGround → GitHub

Two separate key relationships are involved. Confusing them is where most
people get stuck:

| # | Connection | Purpose | Where the key is made |
|---|---|---|---|
| 1 | Your laptop → SiteGround | Log in to the server | SiteGround Site Tools |
| 2 | SiteGround → GitHub | `git push` from the server | On the server, with `ssh-keygen` |

Neither key has anything to do with the review session's GitHub access,
which already works.

---

## Part 1 — Get into SiteGround

1. SiteGround **Site Tools → Devs → SSH Keys Manager**
2. **Generate New Key** — name it, leave the passphrase blank for simplicity
3. **Download** the private key (or copy it)
4. Note the **hostname, username, and port** shown in the SSH Credentials
   section — SiteGround uses a non-standard port, typically 18765

Save the private key locally and lock down its permissions:

```bash
mv ~/Downloads/your_key ~/.ssh/siteground_key
chmod 600 ~/.ssh/siteground_key
```

Connect:

```bash
ssh -p 18765 -i ~/.ssh/siteground_key USERNAME@HOSTNAME
```

Substitute the values from Site Tools. If it hangs, confirm the port —
SiteGround does not use 22.

---

## Part 2 — Let the server push to GitHub

Everything below runs **on the SiteGround server**, in the session you just
opened.

Generate a key for GitHub:

```bash
ssh-keygen -t ed25519 -C "siteground-almamater" -f ~/.ssh/github_key -N ""
cat ~/.ssh/github_key.pub
```

Copy the printed public key. In GitHub:

- **Settings → SSH and GPG keys → New SSH key**, paste, save.
- Or, to scope it to just this repo: repo **Settings → Deploy keys → Add
  deploy key**, paste, and **tick "Allow write access"**. Without that tick
  the push will fail.

Tell SSH to use that key for GitHub:

```bash
cat >> ~/.ssh/config <<'CFG'
Host github.com
  HostName github.com
  User git
  IdentityFile ~/.ssh/github_key
  IdentitiesOnly yes
CFG
chmod 600 ~/.ssh/config
```

Verify:

```bash
ssh -T git@github.com
```

Expect: `Hi <name>! You've successfully authenticated, but GitHub does not
provide shell access.` That message is success — it is not an error.

---

## Part 3 — Clone and collect

**Clone into your home directory, never into `public_html`.** A repo inside
the web root exposes `.git/` to the internet, which leaks your entire
history to anyone who asks for it.

```bash
cd ~
git clone git@github.com:zachpomer1989/Almamater-mahjongg.com.git review
cd review
git checkout claude/almamater-sitemap-indexing-m1plnj
```

Run the collector:

```bash
bash collect.sh
```

It copies `.htaccess` and child theme files, extracts non-secret wp-config
constants, captures the plugin list and key WordPress settings via WP-CLI,
fetches every candidate sitemap URL with full response headers, and checks
whether the sitemap actually begins with `<?xml`.

It is read-only against your site and never touches database passwords or
auth salts.

Read the console output — if `blog_public` is 0, or a sitemap doesn't start
with `<?xml`, it says so directly and you may have your answer already.

---

## Part 4 — Add the two manual exports

The collector cannot reach these; they're admin-only downloads.

1. **WPCode:** WP admin → Code Snippets → Tools → Export → upload the
   `.json` to `01-wpcode-snippets/`
2. **Divi:** Visual Builder → `⋯` → Portability → Export → upload the
   `.json` to `02-divi-code-modules/`

Move them onto the server with `scp` from your laptop:

```bash
scp -P 18765 -i ~/.ssh/siteground_key \
    ~/Downloads/wpcode-export.json \
    USERNAME@HOSTNAME:~/review/01-wpcode-snippets/
```

Or just upload them through the GitHub web UI afterward — either works.

---

## Part 5 — Push

```bash
cd ~/review
git status
git add -A
git commit -m "Add site export and diagnostics"
git push -u origin claude/almamater-sitemap-indexing-m1plnj
```

Before pushing, check nothing sensitive slipped in:

```bash
git diff --cached | grep -iE "password|api[_-]?key|secret|token|salt|DB_"
```

Redact anything real, replacing the value with `REDACTED`.

If git asks for your name and email on the first commit:

```bash
git config user.name "Zach Pomer"
git config user.email "zach@zachpomer.com"
```

---

---

---

## Windows (PowerShell)

The commands elsewhere in this guide are macOS/Linux. On Windows, `chmod`
does not exist and permissions are set with `icacls` instead. Windows
OpenSSH still enforces key permissions, so this step is not optional.

**Run these one at a time.** Pasting multiple lines at once can concatenate
them (producing errors like `Could not resolve hostname hostnamemv`).

First get your real credentials from Site Tools → **Devs → SSH Keys
Manager** (click the manage icon beside the key if the panel is hidden):

- Username — of the form `u1234-abcdefgh`
- Hostname — a server hostname or IP
- Port — normally 18765

`USERNAME@HOSTNAME` in this guide is a placeholder. Substitute your values.

```powershell
# 1. Check what downloaded, and its exact filename
Get-ChildItem ~\Downloads
```

```powershell
# 2. Create .ssh if it does not exist
New-Item -ItemType Directory -Force -Path ~\.ssh
```

```powershell
# 3. Move and rename - substitute the real filename from step 1
Move-Item ~\Downloads\<actual-filename> ~\.ssh\siteground_key
```

```powershell
# 4. Restrict permissions (the chmod 600 equivalent)
$key = "$env:USERPROFILE\.ssh\siteground_key"
icacls $key /inheritance:r
icacls $key /grant:r "$($env:USERNAME):(R)"
```

`icacls` does not expand `~`, which is why the full path is built into
`$key` first. PowerShell and `ssh` both handle `~` fine.

```powershell
# 5. Connect, with your real username and hostname
ssh -p 18765 -i ~\.ssh\siteground_key u1234-abcdefgh@your-hostname
```

If you see `UNPROTECTED PRIVATE KEY FILE`, step 4 did not apply. Re-run it
and confirm it reports `Successfully processed 1 files`.

Once connected you are on a Linux server, so every command in Parts 2-5
works as written.


## Passphrase problems

An SSH key passphrase **cannot be recovered or reset**. It encrypts the
private key file itself, so a forgotten passphrase means the key is
unusable. Generate a new one — that is the only fix, not a workaround.

### Don't confuse the three credentials

| Credential | Used for |
|---|---|
| SiteGround account password | Logging into Site Tools in a browser. **Not valid for SSH.** |
| SSH key passphrase | Unlocking the private key file, locally |
| Database password | Inside wp-config.php, unrelated to both |

**SiteGround does not accept password authentication for SSH.** It is
key-only. Entering your account password at an `Enter passphrase for key`
prompt will always fail — it is not the credential being requested.

### Replace the key

1. Site Tools → **Devs → SSH Keys Manager**
2. Delete the old key; an unusable key is worth nothing
3. **Create New Key**, new name, **leave the passphrase field empty**
4. Download the private key

```bash
mv ~/Downloads/almamater-review ~/.ssh/siteground_key
chmod 600 ~/.ssh/siteground_key
ssh -p 18765 -i ~/.ssh/siteground_key USERNAME@HOSTNAME
```

### If a blank passphrase is rejected

Set a simple one, then strip it locally:

```bash
ssh-keygen -p -f ~/.ssh/siteground_key
```

Enter the old passphrase, then press Enter twice for the new one. The key
stays valid and stops prompting.

### To keep a passphrase

Load it once per session rather than typing it repeatedly:

```bash
ssh-add ~/.ssh/siteground_key
```

A blank passphrase is acceptable here: the key lives on your own machine and
grants access only to your hosting account.

---

## If SSH keeps fighting you

The browser path reaches the same result in roughly ten minutes with no
credentials at all:

- WPCode export JSON and Divi Portability JSON are admin download buttons
- `.htaccess` and `functions.php` come from Site Tools → File Manager
  (enable "show hidden files")
- Sitemap, robots.txt, and homepage are browser View Source saves
- Upload at github.com → switch to the branch → **Add file → Upload files**

You lose only `collect.sh`'s automated header capture and WP-CLI checks.
Useful, not essential.

## Troubleshooting

**`Permission denied (publickey)` on GitHub** — the deploy key lacks write
access, or `~/.ssh/config` wasn't picked up. Test with `ssh -T git@github.com`.

**`Permission denied` connecting to SiteGround** — wrong port (use 18765),
or the private key isn't `chmod 600`.

**`wp: command not found`** — WP-CLI isn't on the PATH. The script skips
those steps and continues; capture the plugin list manually.

**`git: command not found`** — rare on SiteGround, but if so, fall back to
downloading files and uploading through the GitHub web UI.
