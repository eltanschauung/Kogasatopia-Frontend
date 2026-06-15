# Legacy Site Fragments

This directory tracks the legacy homepage fragments from the old standalone PHP docroot.

Edit these files in the repo first, then deploy them with:

```bash
scripts/sync_legacy_homepage.sh
```

The script now syncs the tracked fragments in-place by default. Pass another target path as the first argument to test a sync elsewhere.

Phoenix homepage rendering reads these tracked copies directly, while legacy static assets such as images and CSS come from `priv/static`.
