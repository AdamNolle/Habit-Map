# Habit Map motion preview

Editable source for a 34-second, 1080p/30fps product *preview*. Blender is used for the framing study and editable sequence project; the final motion frames are painted deterministically by `motion.js` and encoded with FFmpeg. The reel uses original calendar motion graphics and two native component test snapshots with sample data. It does not show recorded app interaction, and every example-data shot is labeled. A later feature demo still needs an approved iOS or iPadOS capture.

The source-owned snapshots are read from `Packages/HabitMapCore/Tests/HabitMapCoreTests/__Snapshots__`; no third-party image or audio is used. `score.wav` is synthesized by `make_score.mjs` using original tones and noise. `habit-map-preview.blend` is an editable Blender framing study; `habit-map-edit.blend` is an editable VSE project for the exported sequence. The final video is `../assets/habit-map-preview.mp4`.

To rebuild on Windows, serve `motion.html` through an Edge CDP page on port 9222, then run:

```text
node make_score.mjs
node render_frames.mjs
blender -b --python encode.py
ffmpeg -framerate 30 -i frames/frame-%04d.jpg -i score.wav -c:v libx264 -preset medium -crf 19 -pix_fmt yuv420p -r 30 -c:a aac -b:a 192k -ar 48000 -ac 2 -shortest -movflags +faststart habit-map-preview.mp4
```

The VSE project includes the image sequence and original score. The current Windows Blender build exposes FFmpeg but rejects its video output enum, so the final encoding command uses the already installed digiKam FFmpeg 8.1.1. The rendered frame directory is ignored; the editable canvas and score sources are committed.

## Storyboard

| Time | Visual | Message | Evidence |
|---|---|---|---|
| 0–4s | Four-cell mark resolves into an atlas | Habit Map | Native design tokens |
| 4–9s | Camera travels along a row of cells | Make room for return | Product positioning |
| 9–18s | Distinct cells illuminate across a 28-day field | See your days add up | Native calendar concept, clearly illustrative |
| 18–26s | Real component snapshots settle into an editorial evidence panel | Notice your patterns | Source test snapshots with sample data |
| 26–34s | Green final field, full brand lockup | The next day is yours | Development preview; GitHub project CTA |

No footage, images, logo, font files, music samples, or sound effects from a third party are embedded. The renderer uses local Windows system fonts, which are not distributed with the project.
