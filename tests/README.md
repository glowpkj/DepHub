# DepHub regression checks

Repository-only validation requires Node.js:

```text
node tests/validate_repo.js
```

Behavioral regression checks require Node.js and the official Luau CLI:

```text
node tests/run_backend_tests.js /path/to/luau
luau-compile --null DepHub.lua <all src/**/*.lua and diagnostics/**/*.lua files>
```

The repository validator checks version parity, tracked manifest files, duplicate paths, required core files, game update markers, per-game feature tracking, removal of the retired library/frontends and that no backend creates UI. The backend runner executes the real modules with a small Roblox API double. It checks loader routing and mode publication, frontend-free startup, game state, updater behavior, reversible Rumble VFX operations and lifecycle cleanup.

These are behavioral and static checks, not a Roblox renderer, physics engine or executor. A real in-game test is still required before claiming rendering or executor compatibility.
