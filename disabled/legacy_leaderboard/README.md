# Disabled Legacy Leaderboard

This directory archives the old PHP `/leaderboard` app that previously ran from
`/var/www/kogasatopia/leaderboard` through `kogasa-legacy-php.service` on
`127.0.0.1:8081`.

The live Phoenix app now redirects `/leaderboard` and legacy leaderboard PHP
entrypoints to `/online`. The service unit is kept here in disabled form for
reference only; it should not be installed or enabled.
