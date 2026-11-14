# Card game model

This document records the current modeling decisions for the game's backend. It describes intended domain behavior, not an implementation plan or a claim that the runtime already follows these rules.

## Entities

### Player

- Holds a `hand` collection of cards. Membership in this collection is the source of truth for whether a card is in the player's hand.
- The initial hand is a fixed list supplied by game setup.
- `points` is derived from the current HP of Player-owned cards currently on the board. It is not an independently mutable counter.

### Enemy

- Starts with cards already placed on the board; it does not have a hand in the current model.
- `points` is derived from the current HP of Enemy-owned cards currently on the board.

### Board

- Has a fixed 4-row by 4-column layout, matching the current board setup.
- Rows 0-1 belong to the Enemy; rows 2-3 belong to the Player.
- A cell can contain at most one card. For now, the board is not expected to become full.
- Stores/organizes cards placed on the board and handles successful card plays.
- After a card is placed, `on_card_played` runs the card's type-dependent checks. The initial implementation may be a mock that prints the cards in the four orthogonally adjacent cells: above, below, left, and right. Neighbors across the Player/Enemy row boundary are included.
- Card effects may later move or remove cards. A card whose current HP reaches zero is removed from the board and deleted.

### Card

- Has one `owner` enum value (`PLAYER` or `ENEMY`), not separate nullable Player and Enemy references.
- Has a `type`, current HP, and a nullable board position.
- A card in `Player.hand` has no board position. A card on the board has a board cell position.
- The owner and board row must agree with the card's type and side rules; invalid placements are rejected.
- Each card instance tracks its own mutable current HP. Its starting HP comes from its type's stats.

## Card types and side rules

| Type | Allowed owner | Side |
| --- | --- | --- |
| Elephant | Enemy | Enemy rows 0-1 |
| Magic | Player | Player rows 2-3 |
| Axe | Player | Player rows 2-3 |
| Spear | Player | Player rows 2-3 |
| Trap | Player | Player rows 2-3 |

Each type supplies matching starting stats and effect behavior. Specific type stats and gameplay effects are not defined yet; for now, type-dependent play behavior is mocked.

## Derived points

For each side, points equal the sum of current HP for that side's cards on the board. Cards in the Player's hand do not contribute. This means damage, card removal, and deletion affect the derived total without a separate points-update operation.

## Current decisions vs. deferred behavior

- Enemy cards begin on the board; the Player's starting hand comes from a fixed game-setup list.
- A played card remains on the board unless an effect removes or moves it.
- Reaching 0 HP removes and deletes a card.
- Type-specific effects, exact starting HP values, and any additional turn/draw rules remain unspecified.
