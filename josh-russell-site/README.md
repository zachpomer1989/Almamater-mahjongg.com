# joshrussellrealestate.com

WordPress site for Josh Russell, hosted on SiteGround. This repo tracks the
**custom code only** — not WP core, not plugins, not uploads.

New here? Start with [`SETUP.md`](SETUP.md) — SSH key, GitHub repo, first export.

## Access

```bash
ssh joshrussell
```

Site root: `~/www/joshrussellrealestate.com/public_html`

| | |
|---|---|
| Host | `ssh.joshrussellrealestate.com` (port 18765) |
| User | `TBD` — Site Tools → Devs → SSH Keys Manager |
| Key | `~/.ssh/joshrussell` (ed25519) |
| DB | `TBD` — `wp config get DB_NAME` |

> Fill in the `TBD` rows after Part 2 of `SETUP.md`. Usernames and DB names are
> not secrets — the key is. Never commit the private key.

## Stack

Confirm each of these on the first export and correct this table:

```bash
ssh joshrussell "cd ~/www/joshrussellrealestate.com/public_html && wp core version && wp theme list && wp plugin list --status=active"
```

- WordPress + theme: **TBD** (parent/child?)
- PHP: **TBD**
- IDX / listings: **TBD**
- Forms: **TBD**
- WPCode (`insert-headers-and-footers`): **TBD** — if present, holds most custom code

## Where the custom code actually lives

On these SiteGround/Divi builds there is usually **no child theme**, so almost
nothing custom sits on the filesystem. Check all four places:

| Location | Tracked as |
|---|---|
| WPCode snippets (database) | `db-snippets/` |
| `wp-content/mu-plugins/` | `mu-plugins/` |
| Divi theme options → Integration + Custom CSS (database) | `db-snippets/divi-integration/` |
| Divi page builder per-page layouts (database) | not tracked |

**Editing custom code means editing the database, not files.** Changes made in
WP admin will not appear here until the export script is re-run.

## Syncing DB snippets

```bash
./scripts/export-wpcode.sh
```

Run it *before* making changes, so the diff afterward shows only what you
changed.

## Layout

```
db-snippets/     WPCode snippets exported from the DB
  snippets/      one readable file per snippet
mu-plugins/      must-use plugins (filesystem)
server-config/   .htaccess, robots.txt, php.ini reference copies
scripts/         export/sync tooling
docs/            notes
```

## Security

`.gitignore` blocks `wp-config.php`, database dumps, and key files. Do not
commit database credentials, API keys, or auth salts. If a file you need to
share contains a secret, replace the value with `REDACTED` first — the
structure is what matters for review.
