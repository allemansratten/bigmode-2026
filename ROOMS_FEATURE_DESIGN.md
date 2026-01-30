# Rooms feature — design doc

*Feature design for room-based progression. Iterate here as we implement.*

---

## Goals

- Handmade room **shapes** with fixed layout (walls, floor, bounds).
- Each shape defines **entrances/exits** and **spawn points**.
- At room **creation time**: spawn enemies at enemy spawn points; spawn random furniture or weapons at other spawn points.
- Rooms plug into the existing “room selection → enter room” loop from [GAME_DESIGN_CONTEXT.md](GAME_DESIGN_CONTEXT.md).

---

## Room shape (template)

- A **room shape** is a single, reusable definition: “this layout, these connectors, these spawn slots.”
- **Handmade**: we author a small set of shapes (e.g. rectangle, L-shape, corridor, arena). No procedural geometry for v1.
- Each shape has:
  - **Geometry**: floor, walls, collision (scene or prefab).
  - **Connectors**: one shared node type for both entrance and exit; **bidirectional** (same node used to enter or leave).
  - **Spawn points**: list of positions (+ optional rotation) with a **spawn family** (enum). Which actual items spawn per family is resolved in **room creation behaviour** (implemented later).

---

## Spawn families (enum)

- Spawner nodes define which **family** of items they spawn via an **enum** (e.g. `Enemy`, `Furniture`, `Weapon`).
- Spawn points are **slots**: position + optional rotation + **spawn_family** (enum).
- **Which actual items** populate each family (scenes, weights, etc.) is **not** on the spawner — it is resolved in **room creation behaviour** (to be implemented later). The room creator will read the family and pick from the appropriate pool.
- Families for v1: **Enemy**, **Furniture**, **Weapon**. More can be added later (e.g. Chest, Hazard).

---

## Item category system (tags)

- Each spawnable item (weapon, powerup, etc.) has **multiple tags** from an **`ItemCategory` enum**.
- **Tag types**:
  - **Rarity**: `COMMON`, `UNCOMMON`, `RARE` (add more as needed).
  - **Type**: `WEAPON`, `MOVEMENT`, `SPELL` (broad categories).
  - **Specific**: `MELEE`, `RANGED`, `PROJECTILE` (detailed classification).
- Items can have **multiple tags** (e.g. a weapon could be `[WEAPON, RARE, RANGED]`).
- The **room spawn behaviour** uses these tags to decide which items can spawn in a given room.
- Example use cases:
  - Room wants to spawn a weapon → filters for items with `WEAPON` tag.
  - Room wants rare loot → filters for `RARE` tag.
  - Room wants only melee options → filters for `MELEE` tag.

---

## Item spawn mechanic (throwing)

- Items do **not** spawn instantly at spawn points.
- Instead, items are **thrown into the room** from the side of the level.
- **Spawn flow**:
  1. Room creation behaviour picks an item to spawn based on tags.
  2. Item is instantiated **off-screen** or at the edge of the room.
  3. Item is **thrown** (physics impulse) towards a **target node** (the spawn point marker).
  4. Item lands near the target and becomes interactable.
- **Target nodes**: Spawn point markers act as targets for the throw trajectory.
- **Visual polish**: Adds dynamic feel; player sees items "arrive" in the room.
- Implementation: Apply force/impulse to RigidBody3D items towards target position.

---

## Connectors (entrance / exit)

- **One shared node type** handles both entrance and exit behaviour; connectors are **bidirectional**.
- Same node: player can **enter** the room through it (e.g. from previous room) or **leave** through it (to next room). Position + direction for player placement/facing.
- At runtime we may link a connector to “next room” or “previous room” for transitions. Connector IDs for map generation (e.g. north/south door) deferred until we do layout.

---

## Room lifecycle (high level)

1. **Author** a room shape (scene + data): geometry, **connector** nodes (bidirectional), **spawner** nodes with spawn family enum.
2. **At run time**, when a room is chosen (e.g. from room selection):
   - Instantiate the room shape.
   - **Room creation behaviour** (later): for each spawner, read its family (Enemy / Furniture / Weapon) and spawn the appropriate item from that family’s pool.
3. **Player** is placed at a connector (or designated spawn) when entering the room.
4. When the player uses a connector to leave, we handle transition (next room, cleanup, etc.).

---

## Data / scene structure (to implement)

- **Room shape scene**: root node (e.g. `Node3D` or “RoomShape”) with children:
  - Floor / walls / collision (existing or new).
  - **Connector** nodes (one type, bidirectional): position + direction; used for both entering and leaving the room.
  - **Spawner** nodes: position + optional rotation + **spawn_family** enum (e.g. Enemy, Furniture, Weapon). Room creation behaviour (later) will resolve each family to actual scenes and spawn there.
- v1: marker nodes with exported enum for spawn family; no separate resource for spawn types.

---

## Resolved

- **Connectors**: one shared node type for entrance and exit; **bidirectional**. Implemented as `RoomConnector` with collision-based player detection.
- **Spawners**: define **spawn family** (enum: Enemy, Furniture, Weapon). Actual item population per family is done in **room creation behaviour** (later).
- **Item categories**: multi-tag system for filtering spawnable items (rarity, type, specific).
- **Spawn mechanic**: items thrown into room from edges towards target spawn points.

## Open decisions

- [ ] `RoomSpawner` node implementation (marker nodes with target positions).
- [ ] How room shapes are selected for a run (random, weighted, per-biome, etc.).
- [ ] How room selection gameplay works (choose next door, walk to door, etc.).
- [ ] Exact `ItemCategory` enum values (needs full list for all tags).
- [ ] How room spawn behaviour decides which tags to filter for (per-room config, random, progression-based).
- [ ] Throw trajectory calculation (arc, speed, accuracy).

---

## Iteration log

*Use this section when we change scope or make implementation choices.*

- *Initial version: handmade shapes, entrances/exits, spawn types (enemy, furniture, weapon).*
- *Connectors: one shared bidirectional node. Spawners: spawn_family enum; population in room creation behaviour (later).*
- **2026-01-30**: Added item category system (multi-tag filtering: rarity, type, specific). Items spawn via throw mechanic from room edges towards target nodes.
