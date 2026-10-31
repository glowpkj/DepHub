# DepHub — project rules for agents

These are standing rules for any agent working in this repository. Apply them to
every change, without being asked.

> **Read `DEPHUB-CONVENCOES.txt` first** (root). It is the working contract for
> this repo: how to organize tabs by *category* (never by game name), the shell
> UI API, per-feature config rules, the known traps that already caused bugs, and
> the exact checklist before calling anything done. The short rules below still
> apply; that file is the "how".

## 1. Build the minimum that works — nothing that does not need to exist

The default failure mode here is **doing more than the task needs**: extra
toggles, extra sliders, extra sections, extra helpers, code paths that duplicate
each other. Do not do that.

- **One control per real decision.** If two controls change the same behaviour,
  they are one control. Ship one.
- **Merge what is the same thing.** If two features are the same operation in
  different clothes (e.g. a "boost" and a "bypass" that both just set jump power
  and keep the jump usable), they are a single feature with a single control.
  Merge them — do not keep both "because they were there".
- **Do not create UI, config, state, debug entries, commands or helpers that
  nothing needs.** Every toggle, slider, dropdown, Feature, Watch and Command
  must map to a behaviour the user can observe and cares about. If it does not,
  delete it.
- **Removing is preferred over adding.** When two options exist and one is a
  strict subset/duplicate of the other, delete the weaker one rather than
  keeping both behind a flag.
- **No speculative generality.** Do not add a knob "in case", a mode that is not
  wired up, or an abstraction for a single caller.

A panel with fewer, clearer controls is the goal — not a long list of options.

## 2. Change behaviour, not just labels

A control must actually drive live state. If a toggle or slider does not change
what the code does at runtime, it is decoration and does not belong. When you
consolidate controls, make sure the merged control drives all the behaviour the
old ones did.

## 3. Keep cleanup real

Whatever a feature turns on, it must turn fully off on disable and on unload:
restore original values, disconnect connections, destroy parts, clear published
state. A feature that leaves residue behind is incomplete.

## 4. Keep the architecture

Follow the existing module layout (`src/core`, `src/games`, loader `DepHub.lua`,
`tools/`, `tests/`). Do not duplicate logic across files; extend or reuse the
existing piece. Do not touch other games when the task names one game.

## 5. Version in place

Version bumps touch **both** `src/version.txt` and the `VERSION` line in
`DepHub.lua`; `tests/validate_repo.js` fails if they diverge. Regenerate
`src/update-manifest.json` and add a changelog line in
`src/games/updates/<gameId>.txt` on every bump.

## 6. Verify before claiming done

Run the full gate and only report success if it passes:

```
node tests/run_backend_tests.js "$env:USERPROFILE\tools\luau-win\luau.exe"
node tests/validate_repo.js
node tools/bundle.js "$PWD" "$PWD\dist\DepHub.lua"
node tests/verify_bundle.js "$PWD\dist\DepHub.lua" "$env:USERPROFILE\tools\luau-win\luau.exe" <placeId> <gameId> <route>
```

Keep the tests in `tests/` in step with the code: when a control is removed or
merged, update the tests to assert the new, smaller control set — do not leave
tests pointing at controls that no longer exist.
