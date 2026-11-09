---
name: grok-imagine
description: Generate images and short videos with the local Grok agent (xAI / Grok Imagine). Use for still image assets (mascots, illustrations, backgrounds, hero art, product shots) and for short clips — animating an existing image, a hero loop, a Telegram story. Prefer over gpt-image-2 / fal / Reve when the user asks for Grok. Triggers on "grok image", "grok video", "grok imagine", "generate with grok", "animate with grok".
---

# grok-imagine

The local `grok` binary (Grok Build agent) has built-in image- and video-generation skills. Drive it single-turn from the shell — no interactive UI.

Shared flags for every call:

- `-p / --single` — single-turn: runs the task, prints to stdout, exits.
- `--always-approve` — auto-approve grok's tool calls (required for unattended use).
- `--cwd <assets_dir>` — optional; keeps grok's working files beside your assets.
- Always end the prompt with an explicit **absolute** save path plus *"reply with only the absolute path of the saved file"* — grok honors it and it makes the output easy to verify.

---

## Images

```bash
grok -p "Generate an image: <PROMPT>. Save the generated image to this exact path: <ABS_OUT_PATH> then reply with only the absolute path of the saved file." --always-approve
```

- `<PROMPT>` — detailed: subject, style, composition, palette, background.
- `<ABS_OUT_PATH>` — absolute, ending in `.png`.
- Bash timeout: generous, **up to ~280000 ms**; image gen runs ~15–40 s.

### Tips

- **Style continuity:** grok reads local files, so reference existing assets by absolute path in the prompt — `"...match the mascot in /abs/path/assets/hero-mascot.png"`.
- **No transparency:** Grok can't output an alpha background. Generate on a plain flat background, then cut out with fal `birefnet` or Higgsfield `remove_background`.
- **Aspect:** ask explicitly ("square 1:1", "portrait 3:4", "wide 16:9").
- **Verify:** `ls -la <ABS_OUT_PATH>` and Read the file to inspect quality before using it.

### Example

```bash
grok -p "Generate an image: a friendly orange industrial-robot-arm mascot waving, glossy 3D render, big friendly screen-face, plain flat off-white background, centered full body. Save the generated image to this exact path: /abs/path/assets/mascot.png then reply with only the absolute path of the saved file." --always-approve
```

---

## Videos

Two modes:

1. **Image → video** — animate one source image (gentle motion, camera moves).
2. **Reference → video** — 2–7 images as style/content refs + a prompt describing how they combine.

Options: duration **6s** or **10s**; resolution **480p** (default) or **720p**; aspect ratio e.g. `1:1`, `16:9`, `9:16`.

```bash
grok -p "Animate the image at <ABS_SRC_PATH>: <MOTION DESCRIPTION>. Duration 6s, 720p, aspect <AR>. Save the resulting video to <ABS_OUT_PATH> and reply with only the absolute path of the saved file." --always-approve
```

Bash timeout: **long, up to 600000 ms** — video gen takes ~1–4 min.

### Finding the output

Grok also saves generated videos under a `videos/` folder with incrementing names (e.g. `videos/1.mp4`). If the file isn't at `<ABS_OUT_PATH>`, grab the newest clip:

```bash
ls -t <cwd>/videos/*.mp4 2>/dev/null | head -1
```

### If grok "fails on image input"

The plain `-p` prompt sometimes reports the CLI can't take the image directly; grok then self-recovers by calling its **`image_to_video` tool with model `grok-4.5`** and still produces the clip (it may say "couldn't copy" but the file is saved — check `<ABS_OUT_PATH>` and the `videos/` folder). To steer it directly, add to the prompt: *"use your image_to_video tool (grok-4.5) with this file as the start image."* Verified working: 6s / 720p / 1:1, ~2–3 min, h264 720x720 24fps.

### Tips

- **UI loops:** keep motion subtle — `"gentle bob, subtle wave, background stays completely static, no camera move, no zoom"`. Grok does **not** guarantee a seamless loop; loop or yoyo it in the player (`<video loop>`, or JS crossfade / reverse-alternate).
- **Blend:** mp4 has no alpha. To blend into a page, animate the subject on a background matching the destination (composite the cutout onto the target's exact color/gradient first), then edge-mask the `<video>` in CSS.
- **Verify:** Read/preview a frame (`ffmpeg -i clip.mp4 -vframes 1 frame.png`) or open the mp4 to check motion and identity before shipping.

### Example

```bash
grok -p "Animate the image at /abs/path/assets/mascot-3d-sky.png: the friendly robot looks at the viewer and waves its left hand with a gentle warm bob; the light-blue sky background stays completely static; no camera movement. Duration 6s, 720p, aspect 1:1. Save the resulting video to /abs/path/assets/mascot-wave.mp4 and reply with only the absolute path of the saved file." --always-approve
```

---

## Image → video in one pass

Generate the still first, verify it, then feed its absolute path to the video command. Don't ask grok to do both in a single prompt — the two skills are separate tools and a combined prompt tends to drop one.
