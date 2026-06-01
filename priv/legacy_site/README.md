# Legacy Site Fragments

This directory tracks the legacy homepage fragments that used to exist only under `/var/www/kogasatopia/home/includes`.

Edit these files in the repo first, then deploy them with:

```bash
scripts/sync_legacy_homepage.sh
```

The script copies the tracked fragments to `/var/www/kogasatopia/home/includes` by default. Pass another target path as the first argument to test a sync elsewhere.

Phoenix homepage rendering reads these tracked copies directly, while legacy static assets such as images and CSS still come from `/var/www/kogasatopia`.
