# Velocity
A native Mach-O macOS (and soon iOS) port of Sonic Colors: Ultimate

## How does this work ?
Velocity is basically Sonic running on top of [nxhost](https://github.com/c22dev/nxhost), the toolkit [Mush8](https://github.com/c22dev/mush8) grew into. the Switch and Apple Silicon both run arm64, so `nxpatch` rewrites the few instructions that can't run outside a Switch, and `nxhost` pretends to be the Switch's OS (Horizon) : files, saves, controllers, audio, videos...

Colors Ultimate is a Godot 3 game, and on Switch Godot draws through NVN, Nintendo's graphics API. `nxhost` already turns NVN into Metal for Mario Kart, so most of the work here went into making it behave with what Godot throws at it (its shaders, its glow, its save files...). only three of the game's modules get loaded : the game itself, the NVN driver and the movie library. NVIDIA's GL driver and the shader compiler stay out

Every fix made for Velocity goes into nxhost, so Mush8 gets it too, and the other way around

## Game files
SEGA is a lot chiller than Nintendo, but still, you will need your own dump :
- `prod.keys`
- the base game, as `base.nsp`
- update 1.0.9, as `upd.nsp`
- a `Firmware` folder dumped from your Switch
- optionally, DLCs (`--dlc <file>`)

Drop them at the root of the repo (or point to them with `--base`, `--update`, `--keys`, `--firmware`)

## Requirements
- Apple Silicon Mac, macOS 14 or later
- Rust toolchain
- Xcode 26 or later

## Building
Extract and patch the game code (only once, or after an nxhost update) :
```
./prepare.sh
```
Then :
```
cargo build --release
NX_NO_SCHED=1 NX_WINDOWED=1 target/release/velocity
```
nxhost gets fetched by itself (by Cargo, and by `prepare.sh` for its tools). Working on nxhost too ? clone it next to this repo and add a `.cargo/config.toml` with `paths = ["../nxhost/crates/nxhost", "../nxhost/crates/nxfs", "../nxhost/crates/nxabi", "../nxhost/crates/nxshader"]` so your local copy gets used

The first launch compiles the game's shaders as they show up, so expect a few hitches the first time you see something new

## Controls
Any controller works (Switch Pro, Joy-Con, DualSense, Xbox...). The keyboard works too :

| Key | Switch | Sonic |
|---|---|---|
| WASD | left stick | move |
| Space | B | jump |
| E | A | boost |
| Shift / C | Y | wisp |
| F | X | |
| Q / R | L / R | |
| 1 / 3 | ZL / ZR | |
| Enter / Esc | A / B | menus |
| Tab | + | pause |
| Arrows | d-pad | |

You can rebind the rest in the game's Options > Controls

## Limitations
- no iOS build yet
- `NX_NO_SCHED=1` is still needed, the scheduler fix isn't verified yet
- mostly tested up to the menus, levels might still have some surprises

## Credits
- [nxhost](https://github.com/c22dev/nxhost) and [Mush8](https://github.com/c22dev/mush8), which do all the heavy lifting

Contributions are welcome !
