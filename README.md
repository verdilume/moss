# Moss

Moss renders ANSI-styled text and boxes for Gleam. A style is an immutable value.
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

Set padding or a border on a style to render a rectangular box. Padding
specifies top and bottom rows and left and right columns. Negative padding
becomes zero.

Run `gleam run -m example` to preview the padding and rounded border in a terminal.

```gleam
import moss

pub fn panel() -> String {
  moss.new()
  |> moss.padding(top: 1, right: 2, bottom: 1, left: 2)
  |> moss.foreground(moss.Cyan)
  |> moss.border_foreground(moss.Blue)
  |> moss.render("Hello!\n界")
}
```

Shorter lines are filled on the right based on their terminal cell width.
A trailing newline contributes an empty row. Tabs expand to eight-column
stops relative to the content. The interior style applies to the content
and its padding, one row at a time. Use `border_foreground` to add a colored
border, or pass a style to `rounded_border` for more control. Pass
`moss.new()` for a plain border. Box glyphs occupy one column in the default
width convention.

## Moss layout demo

Run `gleam run -m moss_layout` in a terminal at least 100 columns wide to
see the full [Moss layout demo](src/moss_layout.gleam), including
the gradient dialog, color grid, and floating overlay.

Moss handles span styles, padding, and the rounded dialog border. The demo uses
`string_width` for terminal-cell measurement, wrapping, alignment, joins,
terminal size, and stripping ANSI when output is redirected. The custom tab
and list borders, margins, patterned fill, and overlay are assembled in the
example. The executable uses the dark palette. `moss_layout.render(False, 0)`
returns the full light-palette render. The gradients blend RGB channels, and
interactive output uses true color.

## Rendering at redraw time

Use `moss.span_style` to clear padding and borders before storing a style in a
cell. At redraw time, compare frames and group adjacent changed cells on the
same row whose styles compare equal with `==`. Concatenate each run's text and
call `moss.render` once per run.
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
