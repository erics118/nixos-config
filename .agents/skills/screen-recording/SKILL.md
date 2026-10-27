---
name: screen-recording
description: Use when you need a video of the macOS screen, such as catching a flicker, flash, or other glitch too brief to see, or measuring what changed frame by frame.
---

# screen-recording

Record with ScreenCaptureKit through `record.py` in this skill's folder, then measure the video with ffmpeg filters (`nix shell nixpkgs#ffmpeg --command ffmpeg ...`).

## Record

1. Start the recording in the background, in the task's scratch directory (see the Environment rules). The output path must be absolute. Pass a duration in seconds, or leave it out to record until stopped:

   ```bash
   nohup nix shell nixpkgs#uv --command uv run --no-project \
     --with pyobjc-framework-ScreenCaptureKit --with pyobjc-framework-CoreMedia --with pyobjc-framework-AVFoundation \
     python -I ~/nixos-config/.agents/skills/screen-recording/record.py "$PWD/screen-$(date +%H%M%S).mov" \
     > record.log 2>&1 &
   ```

   It turns the sketchybar apple icon red 3 seconds before capture starts and keeps it red until the file is finished, so the user knows the screen is being recorded. It records the main display at native resolution, up to 120 fps, as HEVC. The terminal app needs Screen Recording permission (System Settings, Privacy & Security). Low Power Mode caps the display at 60Hz, so check `pmset -g | grep powermode` and ask the user to turn it off when it shows `1`.

2. Check that it captures. `record.log` shows `recording started <time>`. Done when that line is there.

3. Stop with `pkill -INT -f screen-recording/record.py`. The file is only readable after `record.log` shows `recording finished`. Stopping also turns the apple icon off. If the task still drives the mouse or keys after the recording, turn it red again right after `recording finished`.

4. Pull a frame and look at it. Done when it shows the screen, not black:

   ```bash
   ffmpeg -hide_banner -loglevel error -y -sseof -1 -i screen.mov -frames:v 1 -vf scale=900:-1 frame.png
   ```

ScreenCaptureKit sends a frame only when the screen changes, at true 120Hz spacing (8.3 ms) while it changes every refresh. A long gap usually means nothing changed, and ProMotion also drops the display below 120Hz when little moves. But against a 120 fps animation, about 8% of frames never reach the video (single frames, now and then two in a row), with or without a cargo build loading the machine. At 60Hz it kept every frame. So a one-frame event at 120Hz has about a 1 in 12 chance of being missed: count hits against the events you expected rather than trusting one miss. HEVC runs about 1.3 MB/s.

Other methods are worse. ffmpeg's avfoundation input caps out near 78 fps (11-12 ms spacing) even in High Power mode. `screencapture -v` paces frames to 60Hz.

Delete the videos when the investigation ends.

## Record a user action

When the user has to do the action (open Mission Control, use a gesture), don't give them a fixed window like "within 5 seconds". They miss the prompt, since it shows only once the command starts. Send the prompt to their phone with `ntfy pub claude` (the ntfy skill) the moment the wait starts, and another when they can let go. Start the recording, then poll for the on-screen state the action creates, with a cap of about 60 seconds, and stop a few polls after it goes away. For Mission Control, poll the window list (see Check window state) for the WindowManager window named `ExposeShieldWindow`. Log the wall-clock time when the state appears and disappears, to find the frames afterwards.

## Align video time with logs

The first frame is at `pts_time` 0, and `record.log` prints the wall-clock time of `recording started`. So log time = that start time + `pts_time`. A visible change lands on the first frame after its log line, so the match is good to one frame with no correction.

Log lines need wall-clock time with microseconds to line up this way.

## Measure

Whole-frame change (`select`/`scene` score) is dominated by text and cursor changes. It misses small glitches. Measure the pixels that matter instead: crop a thin strip where the glitch shows, and log its mean brightness per frame.

```bash
ffmpeg -hide_banner -loglevel error -i screen.mov \
  -vf "crop=W:H:X:Y,signalstats,metadata=print:key=lavfi.signalstats.YAVG:file=yavg.txt" -f null -
awk '/pts_time/{split($0,a,"pts_time:");t=a[2]} /YAVG/{split($0,b,"=");print t, b[2]}' yavg.txt > yavg.dat
```

Crop coordinates are pixels: 2x the points that yabai or SkyLight report on a Retina display. A flicker shows as a jump that reverts one or two frames later. Measure two or three strips (top, left, right edges). Treat a jump as real only when they all move together.

Set a change threshold from the size of the real change, not near zero. Compression noise reached 1.3 brightness units in the first frames of a recording, while a border switching between its two colors moved 52. A threshold of 1 reported flashes that were only noise.

To time a lagging element, measure it against something the app itself draws in the same video, not against the time the command was sent: when the command took effect varied by 15 ms or more from run to run. Window traffic lights work well, since they turn from grey to colored the moment macOS focuses the window and vanish when it closes or minimizes. Log their color with `key=lavfi.signalstats.SATAVG` on a strip through them, in place of `YAVG`.

Put strips where nothing else moves through them. A window animating across a strip changes it too. The minimize animation pulls the window toward the Dock, so its bottom edge moves first and its top edge last, and a strip under the window's path reads the window passing, not the element you are timing.

## Check exact colors

Video is lossy. A recorded frame lands within about 2 per channel of the true color (border `0x7f849c` read back as `7f 84 9a`). That is fine for spotting changes, not for checking a hex value. For an exact color, take a still screenshot and convert it from Display P3 to sRGB, the space config hex values are written in:

```bash
screencapture -x shot.png
sips -s format png --matchTo "/System/Library/ColorSync/Profiles/sRGB Profile.icc" shot.png --out srgb.png
ffmpeg -v error -i srgb.png -vf "crop=1:1:X:Y,format=rgb24" -f rawvideo - | od -An -tx1
```

The unconverted screenshot reads `80 84 9a` for the same pixel, so skipping `sips` gives a near miss that looks like a wrong color.

## See an event

Tile zoomed frames around it. Select frames by video time with `select` and label each with its milliseconds after the event at video time `K`. Seeking with `-ss` before `-i` shifts which frames you get and what the labels say.

```bash
ffmpeg -hide_banner -loglevel error -y -i screen.mov \
  -vf "select='between(t,K-0.1,K+0.5)',crop=240:240:1880:1080,drawtext=text='%{eif\:(t-K)*1000\:d} ms':x=4:y=4:fontsize=20:fontcolor=yellow,tile=8x4:padding=3:color=red" \
  -frames:v 1 tile.png
```

Replace each `K` with the number. Add `*not(mod(n,3))` to the `select` expression to keep every third frame over a longer span. `drawtext` prints `Fontconfig error: Cannot load default config file` and still draws the labels.

## Check window state

To see which windows are on screen, front to back, with owner, name, layer, and alpha:

```bash
osascript -l JavaScript -e 'ObjC.import("CoreGraphics"); const a=ObjC.deepUnwrap(ObjC.castRefToObject($.CGWindowListCopyWindowInfo(1,0))); JSON.stringify(a.map(w=>({id:w.kCGWindowNumber, o:w.kCGWindowOwnerName, n:w.kCGWindowName||"", l:w.kCGWindowLayer, a:w.kCGWindowAlpha, b:w.kCGWindowBounds})))'
```

A sample shows the settled state only, and its order does not prove what is visible: a border listed behind the Mission Control overlay still showed on screen during the zoom animation. Record the screen to see an animation.
