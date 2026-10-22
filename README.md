# 🎭 FaceController

Play games on your Mac with your face. FaceController is a small menu bar app that turns face tracking from your iPhone's Face ID camera into keyboard and mouse input: turn your head to look around, open your mouth to jump, smile to attack.

The default controls are made for **Genshin Impact** (running through [Yaagl](https://github.com/yaagl/yet-another-anime-game-launcher)), but every gesture and key can be changed, and it works with any game.

## How it works

```
iPhone (Live Link Face app) ──Wi-Fi/UDP──▶ FaceController (menu bar) ──keys & mouse──▶ game
```

The iPhone does the face tracking with the free **Live Link Face** app by Epic Games, which streams 52 face values (ARKit blendshapes) plus head rotation about 60 times a second. FaceController reads them and presses keys when a gesture passes its threshold. Nothing is sent anywhere else.

## Default controls

| Face | Input | In Genshin |
|---|---|---|
| Turn head | mouse movement | look around |
| Tilt head right / left (ear to shoulder) | `1`–`4` | next / previous character |
| Open mouth | `Space` | jump |
| Raise eyebrows | `F` | interact / talk |
| Smile | left click (repeated) | attack |
| Angry eyebrows | hold left click | charged attack |
| Kissy face | toggle `W` | walk forward on / off |
| Puff cheeks | hold `Shift` | sprint |
| Wink left | hold `E` | skill (hold the wink for hold skills) |
| Wink right | `Q` | burst |
| **Stick tongue out ~1 s** | | **pause / resume everything** |

FaceController starts **paused** and only sends input while the game is the frontmost app. When it resumes it takes your current head position as "straight ahead" and assumes you're on character 1.

## Setup

1. **Get the app** (macOS 13 or later):
   - **Download** `FaceController-x.y.zip` from [Releases](https://github.com/fayiz-jr/FaceController/releases/latest), unzip it and move FaceController to Applications. macOS blocks the first launch because the app isn't notarized: close the message (don't move it to the Trash), open **System Settings › Privacy & Security**, scroll down and click **Open Anyway** next to FaceController.
   - **Or build it yourself** with the Xcode Command Line Tools (full Xcode isn't required): `./build.sh --install` builds the app, puts it in `/Applications` and opens it.

   The 🎭 appears in the menu bar.
2. **Allow Accessibility** when asked (System Settings → Privacy & Security → Accessibility). That's what lets it press keys.
3. **On your iPhone**, install **Live Link Face** from the App Store, then:
   - choose **Live Link (ARKit)** mode
   - Settings → Live Link → **Add Target**: your Mac's IP (shown in the menu under *iPhone Setup*), port `11111`
   - turn on **Stream Head Rotation**
   - make sure both devices are on the same Wi-Fi, then tap **LIVE**
4. Switch to your game, stick your tongue out for a second, and play. 😛

## Menu

- **Start / Pause** and **Recenter Head**
- **Live face preview**: a bar for every gesture, which turns green when it would trigger
- **Controls** cheat sheet and **iPhone Setup** details
- **Edit Settings…**: opens `~/Library/Application Support/FaceController/config.json`, where you can change gestures, keys, thresholds, camera speed, the party size and which apps it works in. Delete the file to go back to the defaults.
- **Open at Login**

## Settings

Each action in `config.json` looks like this:

```json
{ "trigger": "jawOpen", "on": 0.45, "off": 0.25, "key": "space", "mode": "tap", "unless": ["tongueOut"] }
```

- `trigger`: any ARKit blendshape name (`jawOpen`, `browInnerUp`, `cheekPuff`, …) or `smile`, `browDown`, `frown`, `winkLeft`, `winkRight`
- `on` / `off`: the gesture starts above `on` and ends below `off`, so it doesn't flicker
- `mode`: `tap`, `hold` (held while the gesture lasts), `toggle` or `repeat` (with `repeatMs`)
- `unless`: gestures that drag this one along (puffing your cheeks purses your lips, for example); while any of them is active, this action won't start

Other settings: `lookGainX` / `lookGainY` (camera speed), `lookDeadZone`, `invertX` / `invertY`, `partySize`, `tiltOn` / `tiltOff`, `invertTilt`, `pauseTrigger`, `targetApps`, `port`.

Every face is different. Open the live preview, make each face a few times, and nudge the thresholds until each one triggers reliably without false alarms.

## Command-line modes

The same binary also runs in Terminal:

```sh
FaceController monitor   # live bars for every gesture
FaceController run       # send input without the menu bar app
FaceController raw       # print one raw packet as hex
```

## Notes

- Some online games' terms of service don't allow third-party input tools. FaceController only turns *your own* face gestures into key presses, much like a controller remapper, but it's your account and your call. Try it on a spare account first.
- Not affiliated with Epic Games, Apple, HoYoverse or Yaagl.
- Built with [Claude Code](https://claude.com/claude-code).

## License

[GPL-3.0](LICENSE)
