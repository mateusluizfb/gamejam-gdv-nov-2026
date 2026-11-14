# Card game model

This document records the current modeling decisions and startup data format for the game's backend.

The `cards/`, `game/`, `ui/`, and `data/` directories contain the card, match, UI, and startup-data scripts and scenes respectively. The startup CSV remains at the project root.

## Entities

### Player

- Holds a `hand` collection of cards. Membership in this collection is the source of truth for whether a card is in the player's hand.
- The initial hand is a fixed list supplied by game setup.

### Enemy

- Starts with cards already placed on the board; it does not have a hand in the current model.

### Board

- Has a fixed 4-row by 4-column layout, matching the current board setup.
- Rows 0-1 belong to the Enemy; rows 2-3 belong to the Player.
- A cell can contain at most one card. For now, the board is not expected to become full.
- Stores/organizes cards placed on the board and handles successful card plays.
- Card effects resolve after a 0.5-second animation placeholder. A card whose current HP reaches zero or below is removed from the board.

### Card

- Has one `owner` enum value (`PLAYER` or `ENEMY`), not separate nullable Player and Enemy references.
- Has a `type`, current HP, and a nullable board position.
- A card in `Player.hand` has no board position. A card on the board has a board cell position.
- Placement must follow the card's side rules; the Player's Trap is the exception that is placed in an enemy row.
- Each card instance tracks its own mutable current HP, initialized from the starting HP in its CSV row. Elephant instances can have different starting HP values.

## Card types and side rules

| Type | Allowed owner | Side |
| --- | --- | --- |
| Elephant | Enemy | Enemy rows 0-1 |
| Magic | Player | Player rows 2-3 |
| Axe | Player | Player rows 2-3 |
| Spear | Player | Player rows 2-3 |
| Trap | Player | Enemy rows 0-1 |

Cards of the same type share their image and, except for Elephants, their starting HP. The game has no points mechanic; effects modify individual cards' HP.

## Current decisions vs. deferred behavior

- Enemy cards begin on the board; the Player's starting hand comes from a fixed game-setup list.
- A played card remains on the board unless an effect removes or moves it; only the Axe can attack repeatedly after a kill.
- HP can become negative; reaching 0 HP or below removes the card.
- Final Player card HP values and additional turn/draw rules remain unspecified.

## Starting data

The game loads `starting_cards.csv` from the project root. One configuration row defines the board dimensions; each other row describes one card instance. Hand cards appear in CSV order. The included setup has two 10-HP Elephants in the first row, one 13-HP Elephant in the second row, one of each Player card type in hand, and no Player board cards.

| Column | Meaning |
| --- | --- |
| `type` | `elephant`, `magic`, `axe`, `spear`, or `trap`. |
| `owner` | `enemy` for Elephants; `player` for the other types. |
| `zone` | `board` for starting Enemy cards; `hand` for starting Player cards. |
| `row`, `column` | Zero-based board coordinates; both blank for hand cards. Enemy cards use rows 0-1 and columns 0-3. |
| `base_hp` | Positive integer, used to initialize the card's current HP. |
| `image_path` | Godot `res://` path to a loadable `Texture2D`. |
| `board_rows`, `board_columns` | Set both to `4` in the single board configuration row; leave them blank on card rows. These fields do not make the board size configurable. |

The board configuration row leaves all card fields blank. Repeat the same image path for every row of a given type, and the same base HP for all non-Elephant cards of a given type. Elephant base HP may vary by instance. Keep the header and column order unchanged. Standard quoted fields and escaped double quotes are supported; multiline fields are not.

The entire file is validated before a game is created. Invalid data, including duplicate positions, conflicting type data, wrong ownership, and missing images, prevents startup and is reported on screen and in the Godot error log.

`starting_cards.csv.import` tells Godot to keep the CSV as a file rather than importing it as translations. The Linux export preset includes it as a non-resource file. Any additional export preset must include `starting_cards.csv` in its non-resource export filter and include the image resources referenced by the CSV.

## Current interaction

- Press `R` to restart the match from the starting CSV.
- Hover a hand or board card briefly to see its effect and current values in a tooltip. The tooltip stays within the screen, hides while dragging, and includes any active Magic bonus for attacking cards.
- Elephant card artwork has an animated water shader; card labels remain readable and other card types are unaffected.
- Dragged cards emit particles around their edges; releasing a card creates a brief burst and plays the card-placement sound, including on invalid drops. Escape cancels without a release sound. The playback asset is a 16-bit PCM conversion of the supplied `cards_board_02_place_card.wav`. Selecting an enemy creates a damage burst, and a resolved Trap releases particles across its target row.
- Player-facing text is in Brazilian Portuguese; card artwork labels are covered with localized names and categories.
- Dividers separate the board rows. Drag an Axe, Spear, or Magic card to an empty cell in rows 2-3, or a Trap to an empty cell in the targeted enemy row. A valid destination row is highlighted while dragging. Invalid drops return the card to the hand; board cards cannot be manually moved.
- Axe and Spear show a red damage penalty badge on the board when their row reduces their damage; the blue hand badge continues to show Magic bonuses separately.
- Axe and Spear require a click on an enemy card. The cursor changes over valid targets. Escape cancels the pending play, returning the card and restoring any consumed buff. If an Axe chain has already killed enemies, Escape also undoes those attacks and restores those enemies.
- Axe deals 4 damage, or 2 from the bottom row (row 3). Each resolved attack plays `attack3.wav`; canceled attacks make no attack sound. If it kills a target, choose another enemy and repeat at the same damage until an enemy survives or no enemies remain.
- Spear plays `arrow.mp3` when its attack resolves, dealing 1 damage from row 2 or 2 from row 3, then moving a surviving target to the other enemy row. Canceled attacks make no attack sound. It keeps its column if free, otherwise takes the nearest available column (left on a tie); if that row is full, it stays put and a message is shown.
- Trap deals 5 damage to every enemy in the row where it was placed and is removed afterward. A Trap can be played in an empty enemy row.
- Magic plays a 16-bit PCM conversion of `Healing Spell Impact 1.wav` when placed; canceling its pending effect stops the sound. It adds 2 damage to the next attacking card. Bonuses stack through additional Magic cards, are shown on cards in hand, apply to every Trap target or Axe follow-up, and are consumed when the attack resolves. Red particles remain around buffed hand cards and the pending attacking card on the board until their bonus is consumed or restored by cancellation.
- The screen reports targeting, damage, buffs, and movement failures. Effects are delayed by 0.5 seconds; the final cursor asset and animations are not yet supplied.
- Targeted cards cannot be played without an enemy. Escape also cancels a card while its first effect is waiting for the delay.

Run the focused checks with `godot --headless --path . --script res://tests/card_manager_test.gd` and `godot --headless --path . --script res://tests/combat_test.gd`.
