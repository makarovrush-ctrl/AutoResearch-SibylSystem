# Shortcut mirror

Mirror of `~/Desktop/Sibyl Projects/System/`. Those files are what actually
gets clicked to start a session, but they live on the Desktop (and are synced
between the Mac and Windows laptops), so they are **outside git** and can be
lost or silently reverted from a backup.

Kept here so a regression is recoverable and reviewable in diff.

The launchers deliberately contain almost no logic — they delegate to
`scripts/sibyl-launch.sh`, which is version-controlled. That means even a stale
restored shortcut still picks up current fixes. The one dangerous pattern is a
shortcut that calls `claude` **directly**: it bypasses the launcher entirely and
will miss `--plugin-dir`. `sibyl_cost_guards` (scripts/sibyl-cost-guards.sh)
scans for exactly that on every launch.

To re-sync after editing the Desktop copies:

    cp "$HOME/Desktop/Sibyl Projects/System/"*.command \
       "$HOME/Desktop/Sibyl Projects/System/resume-session.sh" shortcuts/System/
