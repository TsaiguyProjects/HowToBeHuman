This directory overlays into the MediaWiki container at
`/var/www/html/skins-custom` (read-only).

Put each custom skin in its own subdirectory with a
`skin.json`, e.g.:

```
wiki/skins-custom/MySkin/skin.json
```

Then load it from `wiki/LocalSettings.php` by explicit path:

```php
wfLoadSkin( 'MySkin', "$IP/skins-custom/MySkin/skin.json" );
```
