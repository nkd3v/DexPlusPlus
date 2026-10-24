# Dex++
![Preview](./preview.png)

Dex++ is an extended version of Moon's Dex, made to fulfill some Moon's Dex prophecy.

## This Fork: Tags and Quality of Life

- Search for an exact, case-sensitive CollectionService tag with `/tag Enemy` or `/tag "Quest Item"`.
- Combine tag filters with existing searches: `/tag Enemy && /isa Model`, `/tag Enemy || /tag Boss`, or `!(/tag Enemy || /remotes)`.
- Select objects to see their tags in **Properties → Tags**. A checked box means the tag is present; a mixed box means only some selected objects have it. Check a box to add the tag to every selected object, or uncheck it to remove the tag from the selection.
- Use **Add Tag** to add a new tag, including to objects with no tags. The menu beside each tag can find matching objects, add/remove the tag across the selection, and copy a tag name or the first selected object's sorted tag list when clipboard support is available.
- Tag lists update as tags change. Tag searches update when **AutoUpdateSearch** is enabled. CollectionService signals track objects in the DataModel; reselect an unparented object to refresh external tag changes on it.
- The search reset buttons and Escape now clear searches. Invalid expressions turn the Explorer search text red and retain the previous results.
- Fixed search escaping and boolean precedence, false attribute values when renaming, and the `cloneref` fallback. Tag event bursts are coalesced, unused subscriptions are disconnected, and the build uses sorted modules and buffered output.

Tag edits apply in the running client. Server updates and streaming can overwrite client-side tags, as described in the [CollectionService documentation](https://create.roblox.com/docs/reference/engine/classes/CollectionService).

Build this fork locally using the instructions below to use these changes. The upstream release loader is preserved here for reference and does not include this fork's changes.

## Upstream Latest Version Script
```lua
loadstring(game:HttpGet("https://github.com/AZYsGithub/DexPlusPlus/releases/latest/download/out.lua"))()
```
For specific versions, go to [releases](https://github.com/AZYsGithub/DexPlusPlus/releases).

## What's the difference between Dex and Dex++?
Since the original Dex is the last release and Moon have discontinued it, it still has some missing features.
Here are the features that were added/fixed in Dex++
- Using New Roblox Studio Icons
- Updated API
- Uses Konstant, [Advanced Decompiler](https://github.com/w-a-e/Advanced-Decompiler-V3) and [Shiny](https://github.com/AZYsGithub/shiny)/[Medal](https://github.com/shrimp-nz/medal) as fallback decompilers (for shitsploits who doesn't have it)
    > 'getscriptbytecode' is required
- Uses [USSI](https://github.com/luau/UniversalSynSaveInstance/tree/main) as fallback saveinstance
- Mobile Input Support (Window drag, resizing works fully on touch)
- Console Output
- Model Viewer (basically 3D Preview)
- Revived Save Instance (original Dex doesnt have it, but does in Dex 2.0)
- Click part to select (thx Toon :3)
- CodeFrame cursor offset (where cursor on textbox were not aligned properly)

## To Build
1. Clone or download this fork.
2. Install Python 3.9+ (or [uv](https://docs.astral.sh/uv/)).
3. Run `uv run --system-certs --no-project build.py` (or `python build.py`). The command also works from another directory when given the full path to `build.py`.
4. The executable script is created as `out.lua` beside `build.py`. Run that script in your Roblox environment. The generated file is excluded from Git.

## Regression Tests

Install the official [Luau CLI tools](https://github.com/luau-lang/luau/releases) so `luau` and `luau-compile` are on your PATH, then run:

```sh
uv run --system-certs --no-project tests/run.py
```

This builds twice to check reproducibility, compiles all modules and `out.lua`, and runs regression tests against the actual Lua modules with a mocked Roblox API. Live Roblox rendering and executor compatibility still require an in-game smoke test. Basic `/tag` searches also work without an elevated environment; compound filters use the existing elevated search compiler.

## About Dex Roadmap
The concept of the Dex roadmap is amazing, however neither me nor Moon have the ability to fulfil the full roadmap. I did have added few stuffs in my fork but mostly of them are beyond my limit and i did this project for fun.

## Our Discord Server
https://discord.gg/ndhGeSGkWn

## Donation
Every donation is highly apreciated, this is compeletely optional.
- 113mGk11Hz7KoHmVhffMhFRGGt4xyofsn6 (BTC)
- 0xf66604a05c5a5372b1480a0b79f86865dccbd7db (BNB)
- 0xf66604a05c5a5372b1480a0b79f86865dccbd7db (ETH)

## Third Party Components
- Konstant Decompiler (Let me know)
- [UniversalSynapseSaveInstance (USSI)](https://github.com/luau/UniversalSynSaveInstance)
- [Advanced Decompiler](https://github.com/w-a-e/Advanced-Decompiler-V3)
- [Shiny](https://github.com/rocult/shiny)/[Medal](https://github.com/shrimp-nz/medal)

## License
[![Dex++ License](https://img.shields.io/badge/Dex++-License-green)](https://github.com/AZYsGithub/DexPlusPlus/blob/main/LICENSE)

[![USSI License](https://img.shields.io/badge/USSI-License-green)](https://github.com/luau/UniversalSynSaveInstance/blob/main/LICENSE)

## Credits
- [Chillz](https://github.com/AZYsGithub) – Dex++ Maintainer  
- [Cazan](https://github.com/Cazzanos) – Helped me develop the Model Viewer  
- [Moon](https://github.com/LorekeeperZinnia/Dex) – Original Dex Explorer  
- [Toon](https://github.com/Toon-arch) – Contributor and IY's Dex parts and components
