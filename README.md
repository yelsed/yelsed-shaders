# yelsed-shaders

GLSL shaders for the [Ghostty](https://ghostty.org) terminal — ASCII-art logos and retro post-processing FX.

## Shaders

| File | Effect |
|------|--------|
| `kobalt-logo*.glsl` | Kobalt logo (ASCII / border variants) |
| `fivespark-star-ascii-border-blue.glsl` | Fivespark star, blue ASCII border |
| `omarchy-logo-ascii.glsl` | Omarchy logo in ASCII |
| `nokia-lcd.glsl` | Nokia 3310 green LCD grade + barrel distortion |
| `retro-fx.glsl` | Chromatic aberration + film grain |

## Usage

Add to Ghostty config (`~/.config/ghostty/config`):

```
custom-shader = /path/to/nokia-lcd.glsl
```

Post-processing shaders (`nokia-lcd`, `retro-fx`) stack *after* logo shaders.
