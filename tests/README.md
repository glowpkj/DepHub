# Backend/headless regression checks

The old frontend has been removed. The loader runs without windows, tabs, controls,
loading screens or update popups. No replacement UI is included. Earlier UI versions
remain recoverable in Git history.

Requires Node.js and the official Luau CLI (https://github.com/luau-lang/luau/releases).

```text
node tests/run_backend_tests.js /path/to/luau
luau-compile --null DepHub.lua <all src/**/*.lua files>
```

The runner checks for removed UI dependencies, then executes the real loader and game
entry points using isolated Roblox/service/feature doubles. Tests cover routing by place
and game ID, universal fallback, five loader log lines, failure handling, migration from
an old UI session, fresh updater loading, respawn, cleanup, feature access and pending
updates without automatic teleport. The VFX tests execute the actual cosmetic backend.
No real network, gameplay or Roblox renderer is used; these checks do not prove executor
compatibility or in-game behavior.

## Preserved backend interfaces

- `getgenv().__DEPHUB.BloxFruits`: existing toggles, configuration and `Features`.
- `getgenv().__DEPHUB.Universal`: existing methods, `Values` and `Toggles`; actions formerly
  embedded in UI callbacks are available as `Rejoin()`, `SetInfiniteZoom(enabled)` and
  `RunDex()`. Operation feedback is stored in `LastNotification` without a popup.
- `getgenv().__DEPHUB.Runtime.Features`: RT3 `AutoFarm`, `InstantCook`, `AutoDrop` and
  `AutoFarmFriends` modules with their existing `Toggle`/`Set` methods.
- `getgenv().__DEPHUB.Updater.PendingUpdate`: detected update data. `Cancel()` dismisses it;
  `ApplyPending()` explicitly requests the existing update/server-switch action. There is
  no hidden countdown while the cancellation interface is absent.

ESP markers and local fruit VFX are gameplay features, not the removed frontend. The
fruit ESP's interactive spectate button was removed; its spectate methods are retained.
Blox Fruits still loads saved feature settings; RT3 and Universal activation defaults
are unchanged. No new feature is automatically enabled by removing the UI.

## Fruit VFX behavior

The former fruit selector is gone; its registry and reversible operations remain in
`BloxFruits.Features.FruitVFX`: `GetFruits()`, `GetColors(fruit)`,
`Apply(fruit, color, form)` and `Restore(fruit, form)`.

- Rumble supports Red, Orange, Yellow, Green, Cyan, Blue, Purple, Pink, White and Black.
- `Default` discovers existing numbered `Default_ColorN` attributes; `Shifted` uses seven
  `Shifted_ColorN` slots. `Both` targets both folders.
- `Original` restores the actual values captured before this module's first edit, including
  an equipped skin, rather than a hardcoded palette. Newly added color attributes are removed.
- Unrelated attributes and later external color changes are preserved. Missing/malformed
  data aborts without guessing. Failed transactions roll back; replaced instances use a
  fresh snapshot. No polling, remote calls or automatic palette application is added.

This changes local VFX, not ownership of skins, and provides no anti-cheat guarantee.
