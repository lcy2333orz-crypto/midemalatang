# Legacy Cart Archive

This folder is a cold archive of the old single-player cart-management prototype. It is not part of the current restaurant mainline and is not guaranteed to run inside the current project after being moved here.

## Purpose

Use this archive as the source material for a future standalone cart version. The current maintained project direction is the cooperative restaurant greybox loop in `res://scenes/gameplay/test_restaurant.tscn`.

## Original Entry Points

- Old gameplay entry: `scenes/gameplay/main.tscn`
- Old smoke test: `tools/smoke_test.gd`
- Old project autoloads formerly included:
  - `ProgressData`
  - `RunSetupData`
  - `TextDB`
  - `GlobalRunMenu`
  - `EffectManager`

## Archived Scope

The archive keeps the old cart-specific pieces together:

- `autoload/`: old run setup, text database, progress, run menu, and effect manager autoloads.
- `data/`: old text and card data.
- `gameplay/systems/`: old business day, order, inventory, cooking, supplier, economy, reputation, night, settlement, station, and street-crowd systems.
- `gameplay/models/`: old run/order/settlement model helpers plus a copied `item_ids.gd` dependency.
- `scenes/gameplay/`: old cart scene, old `GameManager`, old customer/passerby scenes, and a player copy for restoration reference.
- `scenes/stations/`: old station interaction area.
- `scenes/ui/`: old cart HUD, supplier, pending order, morning, and day gift UI.
- `scenes/settlement/`: old settlement result and related widgets.
- `tools/smoke_test.gd`: old cart smoke test.

## Restore Notes

For a future single-player cart project:

1. Create a separate Godot project or branch for the cart version.
2. Copy the contents of this archive back to that project root, preserving the relative paths.
3. Re-add the old autoloads listed above in `project.godot`.
4. Set the entry scene to `res://scenes/gameplay/main.tscn` or route menus to that scene.
5. Run and repair `res://tools/smoke_test.gd`.
6. Review shared files such as `player.gd` and `item_ids.gd`; the current restaurant project may continue changing its own copies independently.

## Guarantees

- This archive preserves the old logic instead of deleting it.
- Current restaurant code should not depend on anything in this folder.
- The archive can be copied or moved out as a package.
- Runtime compatibility is intentionally not maintained in the current restaurant project.
