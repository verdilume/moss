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
to set colors. Enable attributes with `bold`, `faint`, `italic`, `underline`,
`reverse`, or `strikethrough`.

Each property has a matching `unset_*` function. For example, piping a style
through `moss.unset_bold` removes bold and preserves its colors and other
attributes. Use `moss.unset_foreground` or `moss.unset_background` to clear a
color. Clearing every property gives a style equal to `moss.new()`.

`Color` includes the eight basic ANSI colors from `Black` through `White` and
their bright variants from `BrightBlack` through `BrightWhite`. All 16 follow
the terminal's palette. Use `moss.Indexed(201)` for an ANSI-256 palette entry
or `moss.Color(red: 136, green: 192, blue: 112)` for true color. Indices and RGB
channels are clamped to 0–255 when rendered. `moss.hex` parses six hex digits
with an optional leading `#` and returns `Result(Color, ColorError)`.
Malformed input returns `Error(moss.InvalidHex)`.

## Standalone blocks

Use `moss/block` to render a rectangular block of plain text. Padding specifies
top and bottom rows and left and right columns. Negative padding becomes zero.

```gleam
import moss
import moss/block

pub fn panel() -> String {
  block.new()
  |> block.padding(top: 1, right: 2, bottom: 1, left: 2)
  |> block.style(moss.new() |> moss.foreground(moss.Cyan))
  |> block.rounded_border(moss.new() |> moss.foreground(moss.Blue))
  |> block.render("Hello!\n界")
}
```

Shorter lines are filled on the right based on their terminal cell width.
A trailing newline contributes an empty row. Tabs expand to eight-column
stops relative to the content. The interior style applies to the content
and its padding, one row at a time. The rounded border has its own style.
Pass `moss.new()` for a plain border. Box glyphs occupy one column in the
default width convention.

## Rendering at redraw time

Store text and `moss.Style` separately in each cell. At redraw time, compare
frames and group adjacent changed cells on the same row whose styles compare
equal with `==`. Concatenate each run's text and call `moss.render` once per run.
Start drawing in a known default terminal style so plain runs inherit those
defaults.

`render` returns plain text unchanged for an empty style. For a styled run it
adds one opening ANSI SGR sequence and a trailing `ESC[0m` reset. Pass plain
text spans. Embedded ANSI is passed through, so an embedded reset clears the
active terminal style for the rest of the span. In a cell-based redraw, the
caller owns terminal I/O, cursor movement, screen state, input, and layout.

## Development

```sh
gleam format --check src test
gleam check
gleam test
```
