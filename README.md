# malatang

Godot 4.6 prototype for a cooperative malatang restaurant game.

The active mainline is now the greybox restaurant kitchen loop. The old single-player cart-management prototype has been cold-archived under `legacy_cart_archive/` and is no longer part of the maintained current project path.

## Current Mainline

- Normal menu and stage entry load `res://scenes/gameplay/test_restaurant.tscn`.
- The restaurant scene uses its own manager group, `restaurant_game_manager`.
- Current restaurant code does not depend on the old cart `GameManager`, cooked-stock inventory loop, cards, night events, or story progression.
- Multiplayer is not implemented yet. Current work uses one player to validate order flow, station readability, timing pressure, and movement feel.

## Restaurant Loop

Current playable loop:

1. Customer enters from the door.
2. Customer chooses ingredients at the ingredient display.
3. Customer queues outside the counter.
4. Player interacts with the counter once to create an `OrderBowl`.
5. The order bowl appears in the waiting order area.
6. Player picks up the bowl, places it into a cooker station, and watches the cooker timer.
7. Cooked orders can be taken from the cooker, sauced, then delivered.
8. Dine-in orders are delivered to the assigned table.
9. Takeout orders are packed at the packing area, then handed back at the counter.
10. Overcooked orders stay in the cooker; the player carries the dirty pot to the trash bin to clear that cooker.

Greybox restaurant modules live under `res://scenes/gameplay/restaurant/`:

- `OrderBowl`: order data, visible order clip, cooking state, patience, sauce, packing, and status text.
- `RestaurantCustomer`: entrance, ingredient selection, queueing, waiting, patience bar, and leaving.
- `RestaurantGameManager`: restaurant-only flow orchestration, station interactions, held bowl / dirty pot state, UI refresh, and smoke helper.
- `WaitingOrderArea`: holds waiting order bowls.
- `CookerStation`: one active order per cooker, empty-bowl holder display, cooker countdown, cooked / overcooked state, dirty-pot clearing.
- `RestaurantStationArea`: interaction routing and greybox highlight behavior.
- `RestaurantUI`: top horizontal order cards, status text, hand state, and bottom station prompt.

## Current Tuning

- Customer spawn pressure is intentionally low for loop testing: `max_customers = 3`, `spawn_interval_seconds = 6.0`, and the scene starts with one customer.
- Customer movement is `140.0`, about `0.7x` of the default player movement speed.
- Queue patience drains over about 50 seconds.
- Order patience drains over about 80 seconds.
- Cooker timing is 8 seconds to cooked, then a 6 second cooked window, then overcooked.
- Overcooked orders cannot be served. They must be cleared by carrying the dirty pot to the trash bin.

## Legacy Cart Archive

The old cart-management prototype has moved to `legacy_cart_archive/` as a cold archive. It is kept for future extraction into a separate single-player cart project, not for current restaurant development.

The archive includes the former cart entry scene, old `GameManager`, cooked stock / inventory systems, supplier and emergency purchase code, settlement, night, card, text-data, UI, and old smoke test. It is not guaranteed to run from inside the current restaurant project. See `legacy_cart_archive/README.md` before moving or restoring it.

## Project Layout

- `project.godot`: project config. Main scene is `res://scenes/menus/title_menu.tscn`.
- `scenes/menus/`: title, home, and stage-select entry points. Current entry paths route to `test_restaurant.tscn`.
- `scenes/gameplay/test_restaurant.tscn`: active greybox restaurant map.
- `scenes/gameplay/restaurant/`: restaurant-specific runtime scripts and scenes.
- `scenes/gameplay/player.gd`: shared player movement and restaurant interaction handling.
- `gameplay/models/item_ids.gd`: shared item identifiers still used by the restaurant loop.
- `tools/run_static_checks.ps1`: lightweight static checks.
- `tools/run_godot_checks.ps1`: headless Godot parse plus restaurant smoke when `GODOT_BIN` is configured.
- `tools/restaurant_smoke_test.gd`: restaurant loop smoke.
- `legacy_cart_archive/`: cold archive of the old cart prototype.

## Checks

Run static checks:

```powershell
tools/run_static_checks.ps1
```

Run Godot checks if a Godot executable is available:

```powershell
$env:GODOT_BIN="C:\Path\To\Godot.exe"
tools/run_godot_checks.ps1
```

`run_godot_checks.ps1` runs the current restaurant smoke only. If Godot CLI is not installed or `GODOT_BIN` is not set, the script reports that clearly.

Useful quick checks:

```powershell
rg "PackedVector2Array\([^\[]" --glob "*.gd"
git diff --check
```

## Manual Restaurant Test

1. Start from the title/menu flow and enter the restaurant.
2. Let a customer choose ingredients and queue at the counter.
3. Press `E` at the counter once to create an order.
4. Pick up the order from the waiting area.
5. Put it into a cooker.
6. Take it out while cooked, before it overcooks.
7. Add sauce.
8. For dine-in, deliver to the matching table.
9. For takeout, pack at the packing area, then hand it back at the counter.
10. Let a separate order overcook, pick up the dirty pot from that cooker, and clear it at the trash bin.

## Current Development Rule

For the current phase, prioritize the restaurant kitchen loop and feel:

- order clarity
- station readability
- timing pressure
- cooking / overcooking feedback
- short, continuous interactions
- greybox movement flow

Do not expand drinks, storage, delivery apps, cards, story, economy, multiplayer sync, or formal art until the core restaurant loop feels good.
