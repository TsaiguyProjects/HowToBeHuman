This directory overlays into the MediaWiki container at
`/var/www/html/extensions-custom` (read-only).

Put each custom extension in its own subdirectory with an
`extension.json`, e.g.:

```
wiki/extensions-custom/MyExtension/extension.json
wiki/extensions-custom/MyExtension/src/Hooks.php
```

Then load it from `wiki/LocalSettings.php` by explicit path:

```php
wfLoadExtension( 'MyExtension', "$IP/extensions-custom/MyExtension/extension.json" );
```

Deploy with the normal flow (`./vps/deploy.sh` / push to `main`);
no image rebuild is needed since the directory is bind-mounted.
