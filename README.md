# PlayGround

<!-- omgithub:readme:start -->
## 🚀 Build, play, and remix with OMGithub

**Created using [OMGithub.com](https://go.ondev.store/).**

[![OMGithub](https://img.shields.io/badge/OMGithub-Open%20project-orange?style=for-the-badge)](https://go.ondev.store/fakore601-collab/PlayGround)
[![GitHub](https://img.shields.io/badge/GitHub-Source-181717?logo=github&style=for-the-badge)](https://github.com/fakore601-collab/PlayGround)

- 🎮 [Open the project](https://go.ondev.store/fakore601-collab/PlayGround).
- ✨ [Remix this project](https://go.ondev.store/fakore601-collab/PlayGround?remix=1).
- 💻 [Explore the source](https://github.com/fakore601-collab/PlayGround).
- 🛠️ [Check build runs](https://github.com/fakore601-collab/PlayGround/actions).
- 🐛 [Report an issue](https://github.com/fakore601-collab/PlayGround/issues).
- 👤 [Explore the creator's projects](https://go.ondev.store/fakore601-collab).
- 🌍 [Create with OMGithub](https://go.ondev.store/).
<!-- omgithub:readme:end -->

## Survival Island

This repository includes two playable versions of **Survival Island**:

- A browser prototype at the repository root (`index.html`, `game.js`, and `style.css`).
- A Roblox Studio project under `roblox/`, organized for [Rojo](https://rojo.space/).

Both versions include gathering, crafting, building, survival stats, inventory, a shell currency/shop, missions, XP/level progression, and saving. The browser build saves locally in the current browser. Roblox gameplay actions and profile data are handled by server scripts.

### Play the browser prototype

Open `index.html` in a modern browser, or serve the project directory locally (recommended):

```sh
python3 -m http.server 8000
```

Then visit <http://localhost:8000>. Move with **WASD** or the arrow keys, or use the on-screen directional pad on a touch device. Click nearby resources to gather; use the Craft, Build, Missions, and Island Shop panels to progress. Browser progress is stored in this browser's local storage. **New Run** clears that save and reloads the game.

### Install the Roblox project

1. Install [Roblox Studio](https://create.roblox.com/) and [Rojo](https://rojo.space/docs/).
2. From the repository root, start the Rojo server:

   ```sh
   rojo serve roblox/default.project.json
   ```

3. In Roblox Studio, create or open a place, install the Rojo Studio plugin, and connect it to the running Rojo server. The project maps `roblox/src/ReplicatedStorage`, `ServerScriptService`, and `StarterGui` into the corresponding Roblox services.
4. Press **Play** in Studio. The island, resources, remotes, and client HUD are created by the project scripts.

To export a place file instead of syncing through Studio, run `rojo build roblox/default.project.json -o /tmp/SurvivalIsland.rbxlx` and open the generated file in Studio.

### Roblox persistence and multiplayer notes

The Roblox server uses the DataStore named `SurvivalIsland_PlayerData_v1`. To test persistence against Roblox services, publish the experience and enable **Game Settings → Security → Enable Studio Access to API Services** for Studio testing. DataStores are unavailable in an unpublished local place; if loading fails, this project keeps gameplay locked rather than starting with a fresh profile that could overwrite saved progress. Test service access in a separate published test experience before using production data.

Saves are periodically written and saved when a player leaves or the server closes. **Session locking is not implemented**: if the same account joins multiple servers at once, concurrent saves may overwrite one another. Do not treat this prototype's persistence as conflict-safe production storage. Roblox resources are shared within a server; player inventories, needs, currency, missions, and buildings are stored per player.

### Testing checklist

- **Browser:** gather each resource, consume food/water, craft and build, complete missions, trade in the shop, reload to check local save restoration, and use New Run to verify reset behavior. Test movement and panel controls at desktop and mobile viewport sizes.
- **Roblox Studio:** use **Test → Start** with one or more players; gather with resource prompts, verify the axe's faster wood gathering, craft/build, consume supplies, complete missions, trade, and confirm the HUD updates. Stop and rejoin to check DataStore persistence in a published test place with API access enabled.
- In Roblox, the stone axe effect is implemented. The spear is recorded as crafted but combat is not implemented; the campfire is a crafted record only, without placement or cooking. The browser prototype displays its spear/campfire descriptions similarly.

The repository currently has no automated Roblox runtime test suite. Rojo/Studio checks require the corresponding Roblox tools and services; verify changes in Studio before publishing.
