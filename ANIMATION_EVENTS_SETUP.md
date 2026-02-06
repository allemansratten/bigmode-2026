# Animation Events Setup Guide

This guide shows how to set up animation events (like hit frames) in your character animations.

## Adding Animation Events via Call Method Tracks

### 1. Open Your Character's AnimationPlayer Scene
- Navigate to your character scene (e.g., `resources/models/wizard/player_character.tscn`)
- Select the **AnimationPlayer** node
- Open the **Animation** panel (bottom of screen)

### 2. Add Call Method Track
1. Select the animation you want to add events to (e.g., "MeleeAttackKick")
2. Click the **"Add Track"** button in the timeline
3. Choose **"Call Method Track"**
4. Set the target to the **AnimationController** node (../../AnimationController from the AnimationPlayer)

### 3. Add Event Keyframes
Click on the timeline where you want the event to trigger and add these calls:

#### Hit Frame Event (for weapon attacks)
- **Method**: `_anim_hit_frame`
- **Timing**: Place at the moment the weapon should deal damage (usually mid-swing)

#### Attack Window Events (for timing systems)
- **Method**: `_anim_attack_window_open` - When attack can begin
- **Method**: `_anim_attack_window_close` - When attack vulnerability ends

#### Footstep Events (for movement sounds)
- **Method**: `_anim_footstep`
- **Timing**: When foot touches ground in walk/run animations

### 4. Example Timeline for MeleeAttack Animation (2.0 seconds)
```
0.0s: Animation starts
0.2s: _anim_attack_window_open    # Attack becomes active
0.8s: _anim_hit_frame             # Weapon hits (damage applied here)
1.2s: _anim_attack_window_close   # Attack ends
2.0s: Animation complete (auto-return to locomotion)
```

### 5. Example Timeline for Running Animation (1.0 seconds, looped)
```
0.3s: _anim_footstep  # Left foot down
0.8s: _anim_footstep  # Right foot down
```

## Testing Animation Events

### Console Commands (press `/`)
- `/anim_info` - Show current animation state and event status
- `/anim_event hit_frame` - Manually trigger hit frame
- `/anim_travel Attack` - Force play attack animation
- `/anim_speed 0.5` - Slow animation to 50% speed for debugging

### Code Integration
Your weapons will automatically connect to hit frame events:
```gdscript
# In MeleeWeaponBehaviour._ready()
anim_controller.hit_frame.connect(_on_animation_hit_frame)

# This method gets called when _anim_hit_frame() is triggered
func _on_animation_hit_frame():
    # Apply weapon damage here
    print("Hit frame triggered - applying damage!")
```

## Expected Console Output
```
AnimationController: Setup complete for Player
MeleeWeaponBehaviour: Connected to animation hit frames
AnimationController: Requested action: attack -> Attack
MeleeWeaponBehaviour: Animation hit frame triggered!
MeleeWeaponBehaviour: hit 1 targets
```

## Benefits of Animation Events
- ✅ **Frame-perfect timing**: Damage happens exactly when animation shows impact
- ✅ **Visual feedback sync**: Sound and effects perfectly aligned with visuals  
- ✅ **Non-programmer friendly**: Animators can time events without code changes
- ✅ **Flexible timing**: Easy to adjust timing by moving keyframes
- ✅ **Multiple events**: Support for complex sequences (windup, hit, recovery)

## Troubleshooting
- **No events firing**: Check AnimationPlayer target path points to AnimationController
- **Multiple hits**: Ensure hit frame only triggers once per animation
- **Wrong timing**: Adjust event keyframe position in timeline
- **Missing methods**: Verify method names match exactly (case sensitive)

## Next Steps
1. Add hit frame events to all attack animations
2. Add footstep events to locomotion animations  
3. Create complex attack sequences with multiple timing windows
4. Add visual/audio cues that sync with animation events