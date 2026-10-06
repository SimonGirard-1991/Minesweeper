# Minesweeper

A native remake of the Windows XP Minesweeper for macOS and Apple TV, written in Swift
with AppKit and UIKit. Every sprite — tiles, smiley, LED counters — is drawn from pixel
maps in code, and the app icons are rendered by the same code.

> Unofficial fan project, not affiliated with or endorsed by Microsoft.

## Features

- Beginner (9×9, 10 mines), Intermediate (16×16, 40) and Expert (30×16, 99), plus custom
  fields from 9×9 to 30×24, clamped the way the XP dialog does.
- The first click never hits a mine.
- Flags, optional `?` marks, and chording.
- Best times per level, with the player's name, kept between launches.
- XP behaviour down to the details: a cell opens on release, so a press can be dragged
  off and cancelled, and the smiley gasps while you hold the button.
- macOS: zoom 1× or 2×.

## Controls

### Mac

| Action | Input |
|---|---|
| Open a cell | Click |
| Flag → `?` → clear | Right-click or Control-click |
| Chord: open a number's neighbours once its flags are all placed | Left and right buttons together, middle-click, or Option-click |
| New game | Click the smiley, F2 or ⌘N |
| Zoom | ⌘1, ⌘2 |

### Apple TV (Siri Remote)

| Action | Input |
|---|---|
| Move the cursor | Swipe or press the clickpad edges; hold to repeat |
| Open a cell | Click |
| Chord | Click an opened number |
| Flag → `?` → clear | Play/Pause |
| New game | Move up onto the smiley and click |
| Game menu: level, marks, best times | Menu / Back |

## Building

Requires macOS 14 or later, Xcode 16 or later (Swift 6) and
[XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`). The Xcode
project is generated from `project.yml` and is not checked in; the build and test
targets regenerate it.

```sh
make run       # build the Mac app and open it
make install   # build it and copy it to ~/Applications
make test      # run the unit tests
```

Apple TV:

```sh
make tv-run                              # build, install and launch in the Simulator
make tv-test                             # run the tvOS unit tests
make tv-build-device TV_TEAM=<team id>   # signed build for a real Apple TV
```

The Simulator targets default to "Apple TV 4K (3rd generation)"; pass
`TV_SIMULATOR=<name>` to use another. `make help` lists every target.

## Layout

| Path | Contents |
|---|---|
| `Sources/Core` | Game rules, board, settings and best times — a UI-free framework shared by both apps |
| `Sources/Graphics` | Palette and pixel-art sprites, rendered to `CGImage`s |
| `Sources/App` | Mac app (AppKit) |
| `Sources/TV` | Apple TV app (UIKit) |
| `Tests`, `TestsTV` | Swift Testing suites |
| `Tools` | Icon exporters behind `make icon` and `make tv-icon` |

The icon PNGs and their `Contents.json` files are generated: change the sprites, then
run `make icon` or `make tv-icon` rather than editing the asset catalogs by hand.
