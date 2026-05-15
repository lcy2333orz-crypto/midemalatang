# TODO

This file only tracks unfinished work. Current project status belongs in `README.md`.

## Current Priority: Restaurant Greybox

- Tune the restaurant map after the current timing pass: counter access, waiting area distance, cooker spacing, sauce / packing path, trash-bin reach, and dining-table delivery paths.
- Improve top order cards for fast scanning: clearer cooked / overcooked / packed states, stronger patience readability, and better card sizing when several orders are active.
- Add clearer greybox feedback for successful delivery, wrong station, wrong table, and blocked dirty-pot actions without adding audio or animation systems yet.
- Review station interaction priorities after the next map pass so nearby counter/table/packing interactions choose the expected target.
- Keep restaurant smoke coverage current as the delivery rules and station flow change.

## Restaurant Systems To Add Later

- Add a real local multiplayer input model after the single-player greybox loop feels good.
- Add an external delivery / pickup-order system later. Current takeout is counter handoff; pickup area is reserved for a future delivery flow.
- Add drinks only after the core food order loop is stable.
- Add storage / restocking only after the kitchen layout and order pressure feel right.
- Add washing / cleanup only if dirty-pot handling remains fun and needs more depth.
- Add economy, scoring, tips, or penalties after delivery and failure rules are stable.

## Legacy Cart Prototype

- Keep the old cart scene and systems loadable for reference and smoke tests.
- Do not extend cooked-stock cart gameplay while restaurant flow is the active mainline.
- If old systems are touched, keep changes compatibility-focused and avoid deleting preserved prototype code.

## Data And Architecture

- Move restaurant tuning values toward explicit configuration once the feel is less volatile.
- Keep restaurant-specific code modular: `OrderBowl`, `RestaurantCustomer`, `RestaurantGameManager`, `WaitingOrderArea`, `CookerStation`, and `RestaurantStationArea`.
- Avoid wiring new restaurant gameplay into the legacy `GameManager` systems.
- Continue replacing accidental hardcoded debug text with intentional UI text only when the text is no longer temporary greybox feedback.

## Checks To Maintain

- `tools/run_static_checks.ps1`
- `tools/run_godot_checks.ps1` when `GODOT_BIN` is configured
- `tools/restaurant_smoke_test.gd`
- `tools/smoke_test.gd` for the preserved legacy prototype
