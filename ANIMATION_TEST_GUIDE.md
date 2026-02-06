# Animation System Test Guide

## Test Cases

### Player (BlendSpace1D locomotion, 4 actions)
1. Run `scenes/Game.tscn`
2. Locomotion: idle when still, blended run when moving
3. Actions: attack, dash (immediate even during run), hit reaction, death (terminal)
4. Hit frames: attack triggers `hit_frame` signal if Call Method tracks are set up

### Enemy — FishDwarf (condition-based locomotion, 3 actions)
1. Run `scenes/Game.tscn` or `scenes/RoomTest.tscn`
2. Locomotion: idle/running based on `to_idle`/`to_running` conditions
3. Actions: attack in melee range, hit reaction on damage, death (terminal)

### Weapon Integration
1. Pick up melee weapon → connects to `hit_frame`
2. Attack → damage aligns with animation impact frame
3. Drop → disconnects. Pick up again → reconnects.

## Verifying a New Character

Enable `debug_logging` on AnimationController and check console for:
- `Setup complete for <Name>` — found AnimationTree
- `Character missing signal: <name>` — signal in AnimSet doesn't exist on character
- `No state mapped for action: <name>` — action not in `action_states`
- `StateMachine not available` — wrong `state_machine_path`
