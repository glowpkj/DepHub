# Violence District client findings

## Teams
- `Teams.Killer`
- `Teams.Spectator`
- `Teams.Survivors`

## Generator structure
- Generator container: `workspace.Map.Generators`
- Generator models contain repair points named like `GeneratorPoint1`, `GeneratorPoint2`, etc.
- Current working hypothesis: a live `GeneratorPointN` represents a repairable interaction point; this still needs in-game validation for completed generators.

## Repair interaction
Observed remote:
```lua
game:GetService("ReplicatedStorage").Remotes.Generator.RepairEvent:FireServer(generatorPoint, true)
```

Observed local character state while interacting:
- `workspace.<LocalPlayer.Name>.CheckInterractable`

## Generator skill check
Observed local character object while the generator skill check is active:
- `workspace.<LocalPlayer.Name>["Skillcheck-gen"]`

Observed successful skill-check remote:
```lua
game:GetService("ReplicatedStorage").Remotes.Generator.SkillCheckResultEvent:FireServer(
    "success",
    1,
    generatorModel,
    generatorPoint
)
```

The meaning of the second argument (`1`) is not confirmed yet. The implementation attempts to read an index/stage value from the `Skillcheck-gen` object and falls back to `1` when none is exposed.
