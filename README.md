# Moss

Moss renders ANSI-styled text spans for Gleam. A style is an immutable value.
Each setter returns a new style, so setters compose in a pipeline.

```gleam
import moss

pub fn warning_label() -> String {
  moss.new()
  |> moss.foreground(moss.Yellow)
  |> moss.bold
  |> moss.render("WARN")
}
```

`new()` starts with no colors or attributes. Use `foreground` and `background`
to set colors, and `bold`, `italic`, and `underline` to enable attributes.
`Color` includes the eight basic ANSI colors from `Black` through `White` and
their bright variants from `BrightBlack` through `BrightWhite`. All 16 follow
the terminal's palette. Use `moss.Indexed(201)` for an ANSI-256 palette entry
or `moss.Color(red: 136, green: 192, blue: 112)` for true color. Indices and RGB
channels are clamped to 0–255 when rendered. `moss.hex` parses six hex digits
with an optional leading `#` and returns `Result(Color, ColorError)`.
Malformed input returns `Error(moss.InvalidHex)`.

## Rendering at redraw time

Store text and `moss.Style` separately in each cell. At redraw time, compare
frames and group adjacent changed cells on the same row whose styles compare
equal with `==`. Concatenate each run's text and call `moss.render` once per run.
Start drawing in a known default terminal style so plain runs inherit those
defaults.

`render` returns plain text unchanged for an empty style. For a styled run it
adds one opening ANSI SGR sequence and a trailing `ESC[0m` reset. Pass plain
text spans. Embedded ANSI is passed through, so an embedded reset clears the
active terminal style for the rest of the span. The caller owns terminal I/O,
cursor movement, screen state, input, layout, and Unicode display widths.

## Development

```sh
gleam format --check src test
gleam check
gleam test
```
