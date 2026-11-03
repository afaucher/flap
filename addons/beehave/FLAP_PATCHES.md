# Beehave 2.9.2 in Flap

Vendored from `project_deep_space/addons/beehave` (MIT, bitbrain; see LICENSE) for the combat AI's decision layer
(`docs/design/combat_ai.md`, 3.2). Registered as two autoloads in `project.godot` (`BeehaveGlobalMetrics`,
`BeehaveGlobalDebugger`); the editor plugin is not enabled. Changes from upstream:

- `nodes/beehave_tree.gd`, `_physics_process`: back to upstream's plain `tick()` (deep space had added its own
  profiler calls there).
- `debug/debugger_messages.gd`, `can_send_message()`: also requires `EngineDebugger.is_active()`, so a headless or
  editor-less run doesn't print "Can't send message. No active debugger" for every tree (Flap's test runner fails
  on any engine ERROR line).
- `debug/global_debugger.gd`, `_enter_tree`: registers its message capture only when `EngineDebugger.is_active()`
  (without a debugger the engine prints "Capture not registered: 'beehave'" at shutdown).
