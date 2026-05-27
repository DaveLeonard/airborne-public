# Airborne-inspired Playdate Lua snippets

These snippets are cleaned-up public examples extracted from production patterns used in Airborne.
They are meant to be posted as GitHub snippets or gists and adapted to other Playdate projects.

## Snippets

1. `playdate_object_pool.lua`  
   Bounded sprite/object pooling with reusable numeric IDs. Useful for bullets, explosions, particles, and enemies.

2. `wave_director.lua`  
   Data-driven enemy waves with spawn caps, scheduled late-wave spawns, endless scaling, and approach-audio timing.

3. `per_frame_sprite_counters.lua`  
   Cached per-frame sprite counting to avoid O(n^2) scans when many sprites query global state.

4. `dithered_banner_sprite.lua`  
   A Playdate banner sprite that pre-renders dithered fade frames so update-time drawing stays cheap.

5. `datastore_highscores.lua`  
   Defensive local highscore persistence with datastore migration, coercion, sorting, and top-N insertion.

6. `crank_dual_weapon_aim.lua`  
   Shared crank aiming for two weapon modes with cached angle vectors and spawn-point helpers.

7. `splash_damage_hitboxes.lua`  
   Fair splash damage checks for point targets and rectangular bodies using nearest-point distance.

8. `timed_fx_sequence.lua`  
   Lightweight timeline for chained explosions, camera shake, and looping-audio fade-out.

9. `persistent_achievements.lua`
   Persistent achievement/service-record manager with event rules, cumulative counters, notification queue, and targeted reset.

## Notes

- These are intentionally framework-light and use only Playdate CoreLibs patterns.
- Replace class names, tag constants, image paths, and factories with your own game objects.
- The examples avoid Airborne-specific assets and can be shared publicly.
