# HowToBeHuman on OVHcloud VPS-2 (MediaWiki)

Single-VM production setup: `wiki` (MediaWiki 1.43 LTS) + `db` (MariaDB 11.4) + `caddy` (automatic HTTPS).
VPS-2 2027 specs — 4 vCores / 8 GB RAM / 75 GB NVMe, ~**$8.50/mo** (12-mo upfront),
unlimited traffic, daily 24h backup included.

All functionality ships as MediaWiki extensions — bundled ones via
`LocalSettings.php`, custom ones from `wiki/extensions-custom/`.

## 1. Order the VPS (once)

1. us.ovhcloud.com → VPS → **VPS-2 2027**, OS **Ubuntu 24.04**, region closest to users.
2. Note the IPv4 (e.g. `51.68.12.34`). Add your SSH key during order if offered.
3. Cost: ~$8.50/mo + domain ~$10-15/yr (free SSL via Let's Encrypt/Caddy).

## 2. DNS (once)

| Type | Host | Value |
|---|---|---|
| A | `@` | `<VPS_IP>` |
| A | `www` | `<VPS_IP>` (optional) |

Wait for propagation: `dig +short example.com`.

## 3. Provision (once, as root)

```bash
VPS_HOST=51.68.12.34
scp vps/provision.sh root@$VPS_HOST:/tmp/provision.sh
ssh root@$VPS_HOST 'APP_DIR=/opt/how-to-be-human DEPLOY_USER=deploy bash /tmp/provision.sh'
ssh-copy-id deploy@$VPS_HOST   # if key not already installed
```

## 4. First deploy + installer

```bash
VPS_HOST=51.68.12.34
ssh deploy@$VPS_HOST "git clone <your-repo-url> /opt/how-to-be-human"
ssh deploy@$VPS_HOST "cd /opt/how-to-be-human && cp .env.example .env && nano .env"
# In .env set: DOMAIN=example.com, MW_DB_PASSWORD=<long random string>
#   Generate one: openssl rand -base64 32
ssh deploy@$VPS_HOST "cd /opt/how-to-be-human && ./vps/deploy.sh"
```

Then finish the install in the browser:

1. Visit `https://example.com` — the MediaWiki installer appears.
2. DB settings: host `db`, name/user/password from `.env` (`MW_DB_NAME/MW_DB_USER/MW_DB_PASSWORD`).
3. Download the generated `LocalSettings.php`, place it at `./wiki/LocalSettings.php` on the VPS (gitignored — never commit it; it holds secrets).
4. Copy it into the persisted volume and restart:
   ```bash
   WIKI=$(docker compose -f docker-compose.prod.yml ps -q wiki)
   docker cp ./wiki/LocalSettings.php $WIKI:/var/www/html/LocalSettings.php
   docker compose -f docker-compose.prod.yml restart wiki
   ```

## 5. Auto-deploy on push (GitHub Actions)

`.github/workflows/deploy-vps.yml` SSHes in and runs `vps/deploy.sh` on every push to `main`.
Set repo secrets: `VPS_HOST`, `VPS_USER` (`deploy`), `VPS_SSH_KEY`, `APP_DIR` (`/opt/how-to-be-human`).

Manual deploy: `VPS_HOST=... VPS_USER=deploy APP_DIR=/opt/how-to-be-human make vps-deploy`

## 6. Extensions (all future features)

* Bundled: enable in `wiki/LocalSettings.php`, e.g. `wfLoadExtension( 'Cite' );`, then restart the wiki container.
* Custom (yours): develop under `wiki/extensions-custom/MyExtension/` (with `extension.json`),
  load by path in `LocalSettings.php`:
  ```php
  wfLoadExtension( 'MyExtension', "$IP/extensions-custom/MyExtension/extension.json" );
  ```
  No rebuild needed — the directory is bind-mounted. Same pattern for skins in `wiki/skins-custom/`.
* After enabling/disabling anything: `docker compose -f docker-compose.prod.yml exec wiki php maintenance/update.php --quick`

## 7. Operate

```bash
make vps-status   # container status
make vps-logs     # follow logs
```

* Backups: VPS daily backup included. Additionally: `docker compose -f docker-compose.prod.yml exec db mariadb-dump -u root -p"$MARIADB_ROOT_PASSWORD" --all-databases > backup.sql`
  (root password is random — read it with `docker compose exec db printenv MARIADB_ROOT_PASSWORD`),
  plus the `wiki_html` volume holds uploads + `LocalSettings.php`.
* Updates: monthly `apt update && apt upgrade`; bump `mediawiki:`/`mariadb:` tags, then `update.php`. Caddy renews TLS automatically.
