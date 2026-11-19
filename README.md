# SCRIPTLY // 628

Retro-cyber developer console for testing your own Roblox experiences: movement and physics tools, ESP, NPC targeting tests, lighting and camera overrides, plus server-authoritative developer actions.

## Quick start (executor)

With the repository **public**, run this one line while inside your own experience:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/shaboomboom43-creator/Scriptly/main/ScriptlyLoader.lua"))()
```

The loader downloads `ScriptlyClient.lua` (a single file), compiles it and starts it. It works with executors that offer `game:HttpGet` or any of the common `request` functions, and with `loadstring` or `load`. Running it again replaces the previous copy instead of stacking up.

Prefer not to use GitHub at runtime? Paste the contents of `ScriptlyClient.lua` straight into your executor, or drop it into `StarterPlayer > StarterPlayerScripts` as a LocalScript.

## Studio setup (for the server tools and for every player to see effects)

| File | Where it goes | Purpose |
| --- | --- | --- |
| `ScriptlyServer.server.lua` | `ServerScriptService` (Script) | Validates and runs the server-side actions |
| `ScriptlyEffects.client.lua` | `StarterPlayer > StarterPlayerScripts` (LocalScript) | Shows server-wide announcements, jumpscares and confetti to every player |

The hub works without these (client mode); the SERVER tab and server-wide effects need them.

### Who can use it

Access is decided on the server, never trusted from the client:

1. Anyone running inside Roblox Studio.
2. The owner of a user-owned experience.
3. Any UserId listed in `DEVELOPER_IDS` (top of `ScriptlyServer.server.lua`).
4. For studio / group-owned experiences: group members at or above `MIN_GROUP_RANK`. Set `GROUP_ID` if your studio group owns several games, or leave it at `0` to use the group that owns the experience. The default rank is 255 (group owner only); lower it to let your developer ranks in.

## Interface

- Synthwave boot sequence (click or press any key to skip), CRT scanlines, animated gradient border, glitch title
- Draggable window that scales to any screen size, with a launcher button to bring it back (touch friendly)
- Toggles, sliders, toast notifications and a live FPS / ping / player readout
- `RightShift` hides and shows the hub
- Six colour presets (Neon Grid default, Synthwave, Matrix Green, Toxic Lime, Cyber Teal, Amber Terminal) plus a custom hex gradient

## Tools

- **Movement:** flight (keyboard, thumbstick and on-screen buttons) with a speed slider, noclip, bunny hop, spin, walk speed and jump power sliders, anti-cheat simulation presets
- **Visuals:** player ESP, NPC target ESP, NPC aim test, fullbright, FOV slider, flash test
- **Server:** heal, teleport to spawn, respawn, freeze, ghost, ForceField, flop, teleport to player
- **World + fun:** local jumpscare / confetti / announcement; server-wide gravity, day / night, jumpscare, confetti and announcements

## Safety and scope

- For experiences you own or are authorised to test. Use a private Studio server first.
- Server commands are a fixed, validated list and are rate-limited; arbitrary client-supplied Lua is never executed.
- Aim assist only targets parts and models tagged `ScriptlyTarget` (use the CollectionService tag editor on your test dummies), never player characters.
- The repository must be public for anonymous `raw.githubusercontent.com` access. Never put a GitHub token in the loader.
