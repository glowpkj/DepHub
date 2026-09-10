# DepHub regression checks

Repository-only validation requires Node.js:

```text
node tests/validate_repo.js
```

Behavioral regression checks require Node.js and the official Luau CLI:

```text
node tests/run_library_tests.js /path/to/luau
node tests/run_backend_tests.js /path/to/luau
luau-compile --null DepHub.lua <all src/**/*.lua and library/**/*.lua files>
```

The repository validator checks version parity, tracked manifest files, duplicate paths, required core files, game update markers, TSB feature tracking and retired frontend cleanup. The library runner executes the real modules with a small Roblox API double. It checks window lifecycle, content adapters, tab navigation, callbacks, responsive reflow, dropdown rebuilding, RGB colors, notifications, duplicate cleanup and connection cleanup. The backend runner checks loader routing, frontend failure cleanup, game state, updater behavior and reversible Rumble VFX operations.

These are behavioral and static checks, not a Roblox renderer, physics engine or executor. A real in-game test is still required before claiming rendering or executor compatibility.
