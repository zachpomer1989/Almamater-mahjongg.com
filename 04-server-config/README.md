# Server Configuration

- `htaccess.txt` — contents of the root `.htaccess` (enable "show hidden
  files" in SiteGround File Manager to see it)
- `wp-config-constants.txt` — the listed constants only

**Do not commit `wp-config.php`.** It contains your database password and
auth salts, and `.gitignore` blocks it. Only the constants listed in
EXTRACTION-GUIDE.md Step 4 are needed, without secret values.

- PHP version (Site Tools → Devs → PHP Manager):
