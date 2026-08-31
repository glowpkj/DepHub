# DepHub regression checks

Requires Node.js and the official Luau CLI.

```text
node tests/run_library_tests.js /path/to/luau
node tests/run_backend_tests.js /path/to/luau
luau-compile --null DepHub.lua <all src/**/*.lua and library/**/*.lua files>
```

The library runner executes the real modules with a small Roblox API double. It checks
window lifecycle, all three content adapters, tab navigation, callbacks, responsive
reflow, dropdown rebuilding, RGB colors, notifications, duplicate cleanup and connection
cleanup. The backend runner checks loader routing, the five requested log lines, frontend
failure cleanup, game state, updater behavior and reversible Rumble VFX operations.

These are behavioral checks, not a Roblox renderer, physics engine or executor. A real
in-game test is still required before claiming pixel-perfect rendering or executor
compatibility.
