import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import gleam_community/colour
import string_width

/// Named ANSI colors, indexed ANSI-256 colors, or true-color RGB.
/// Indices and RGB channels are clamped to 0–255 when rendered.
pub type Color {
  Black
  Red
  Green
  Yellow
  Blue
  Magenta
  Cyan
  White
  BrightBlack
  BrightRed
  BrightGreen
  BrightYellow
  BrightBlue
  BrightMagenta
  BrightCyan
  BrightWhite
  Indexed(index: Int)
  Color(red: Int, green: Int, blue: Int)
}

pub type ColorError {
  InvalidHex
}

/// An immutable style value that can be compared with `==`.
pub opaque type Style {
  Style(
    foreground: Option(Color),
    background: Option(Color),
    bold: Bool,
    faint: Bool,
    italic: Bool,
    underline: Bool,
    reverse: Bool,
    strikethrough: Bool,
    hyperlink: Option(String),
    padding: Option(Padding),
    border: Option(Style),
  )
}

type Padding {
  Padding(top: Int, right: Int, bottom: Int, left: Int)
}

/// Create an empty style for a text span.
pub fn new() -> Style {
  Style(
    foreground: None,
    background: None,
    bold: False,
    faint: False,
    italic: False,
    underline: False,
    reverse: False,
    strikethrough: False,
    hyperlink: None,
    padding: None,
    border: None,
  )
}

/// Set the text color.
pub fn foreground(style: Style, color: Color) -> Style {
  Style(..style, foreground: Some(color))
}

/// Clear the text color.
pub fn unset_foreground(style: Style) -> Style {
  Style(..style, foreground: None)
}

/// Set the background color.
pub fn background(style: Style, color: Color) -> Style {
  Style(..style, background: Some(color))
}

/// Clear the background color.
pub fn unset_background(style: Style) -> Style {
  Style(..style, background: None)
}

/// Enable bold text.
pub fn bold(style: Style) -> Style {
  Style(..style, bold: True)
}

/// Disable bold text.
pub fn unset_bold(style: Style) -> Style {
  Style(..style, bold: False)
}

/// Enable faint text.
pub fn faint(style: Style) -> Style {
  Style(..style, faint: True)
}

/// Disable faint text.
pub fn unset_faint(style: Style) -> Style {
  Style(..style, faint: False)
}

/// Enable italic text.
pub fn italic(style: Style) -> Style {
  Style(..style, italic: True)
}

/// Disable italic text.
pub fn unset_italic(style: Style) -> Style {
  Style(..style, italic: False)
}

/// Enable underlined text.
pub fn underline(style: Style) -> Style {
  Style(..style, underline: True)
}

/// Disable underlined text.
pub fn unset_underline(style: Style) -> Style {
  Style(..style, underline: False)
}

/// Enable reverse video, swapping the displayed foreground and background.
pub fn reverse(style: Style) -> Style {
  Style(..style, reverse: True)
}

/// Disable reverse video.
pub fn unset_reverse(style: Style) -> Style {
  Style(..style, reverse: False)
}

/// Enable strikethrough text.
pub fn strikethrough(style: Style) -> Style {
  Style(..style, strikethrough: True)
}

/// Disable strikethrough text.
pub fn unset_strikethrough(style: Style) -> Style {
  Style(..style, strikethrough: False)
}

/// Set the URL for a terminal hyperlink. Empty URLs and URLs containing
/// control characters clear the link.
pub fn hyperlink(style: Style, url: String) -> Style {
  let has_control =
    string.to_utf_codepoints(url)
    |> list.any(fn(point) {
      let code = string.utf_codepoint_to_int(point)
      code < 0x20 || { code >= 0x7f && code <= 0x9f }
    })

  case url == "" || has_control {
    True -> unset_hyperlink(style)
    False -> Style(..style, hyperlink: Some(url))
  }
}

/// Clear the terminal hyperlink.
pub fn unset_hyperlink(style: Style) -> Style {
  Style(..style, hyperlink: None)
}

/// Set box padding in terminal rows and columns. Negative values become zero.
pub fn padding(
  style: Style,
  top top: Int,
  right right: Int,
  bottom bottom: Int,
  left left: Int,
) -> Style {
  let padding =
    Padding(
      top: int.max(top, 0),
      right: int.max(right, 0),
      bottom: int.max(bottom, 0),
      left: int.max(left, 0),
    )
  Style(..style, padding: Some(padding))
}

/// Clear the box padding.
pub fn unset_padding(style: Style) -> Style {
  Style(..style, padding: None)
}

/// Add a rounded border using the given text style for its glyphs.
/// Pass `moss.new()` for a plain border.
pub fn rounded_border(style: Style, border: Style) -> Style {
  Style(..style, border: Some(span_style(border)))
}

/// Set the border's foreground color, adding a rounded border if needed.
pub fn border_foreground(style: Style, color: Color) -> Style {
  let border = option.unwrap(style.border, new())
  rounded_border(style, foreground(border, color))
}

/// Remove the border.
pub fn unset_border(style: Style) -> Style {
  Style(..style, border: None)
}

/// Keep the colors, attributes, and hyperlink for a text span or cell.
pub fn span_style(style: Style) -> Style {
  Style(..style, padding: None, border: None)
}

/// Render text as a span or as a box when padding or a border is set.
pub fn render(style: Style, text: String) -> String {
  case style.padding, style.border {
    None, None -> render_span(style, text)
    _, _ -> render_box(style, text)
  }
}

fn render_box(style: Style, text: String) -> String {
  let padding = option.unwrap(style.padding, Padding(0, 0, 0, 0))
  let lines =
    text
    |> string.replace("\r\n", "\n")
    |> string_width.tabs_to_spaces
    |> string.split("\n")
    |> list.map(fn(line) { #(line, string_width.line(line)) })

  let content_width =
    list.fold(lines, 0, fn(widest, line) { int.max(widest, line.1) })
  let width = content_width + padding.left + padding.right
  let left = string.repeat(" ", padding.left)
  let blank = string.repeat(" ", width)
  let content =
    list.map(lines, fn(line) {
      let #(text, columns) = line
      left
      <> text
      <> string.repeat(" ", content_width - columns + padding.right)
    })

  let rows =
    [
      list.repeat(blank, padding.top),
      content,
      list.repeat(blank, padding.bottom),
    ]
    |> list.flatten
    |> list.map(render_span(style, _))

  let framed = case style.border {
    None -> rows
    Some(border) -> {
      // shortcut: assumes one-column box glyphs, add an ASCII preset for wide glyphs.
      let edge = string.repeat("─", width)
      let top = render_span(border, "╭" <> edge <> "╮")
      let bottom = render_span(border, "╰" <> edge <> "╯")
      let side = render_span(border, "│")
      let middle = list.map(rows, fn(row) { side <> row <> side })
      list.flatten([[top], middle, [bottom]])
    }
  }

  string.join(framed, "\n")
}

fn render_span(style: Style, text: String) -> String {
  let codes = build_codes(style)
  let styled = case codes {
    [] -> text
    _ -> "\u{001b}[" <> string.join(codes, ";") <> "m" <> text <> "\u{001b}[0m"
  }

  case style.hyperlink {
    Some(url) ->
      "\u{001b}]8;;"
      <> url
      <> "\u{001b}\\"
      <> styled
      <> "\u{001b}]8;;\u{001b}\\"
    None -> styled
  }
}

fn build_codes(style: Style) -> List(String) {
  let attrs =
    [
      #(style.bold, "1"),
      #(style.faint, "2"),
      #(style.italic, "3"),
      #(style.underline, "4"),
      #(style.reverse, "7"),
      #(style.strikethrough, "9"),
    ]
    |> list.filter_map(fn(item) {
      case item.0 {
        True -> Ok(item.1)
        False -> Error(Nil)
      }
    })

  let fg = case style.foreground {
    Some(color) -> [color_to_code(color, True)]
    None -> []
  }

  let bg = case style.background {
    Some(color) -> [color_to_code(color, False)]
    None -> []
  }

  list.flatten([attrs, fg, bg])
}

fn color_to_code(color: Color, is_fg: Bool) -> String {
  let offset = case is_fg {
    True -> 0
    False -> 10
  }

  case color {
    Black -> int.to_string(30 + offset)
    Red -> int.to_string(31 + offset)
    Green -> int.to_string(32 + offset)
    Yellow -> int.to_string(33 + offset)
    Blue -> int.to_string(34 + offset)
    Magenta -> int.to_string(35 + offset)
    Cyan -> int.to_string(36 + offset)
    White -> int.to_string(37 + offset)
    BrightBlack -> int.to_string(90 + offset)
    BrightRed -> int.to_string(91 + offset)
    BrightGreen -> int.to_string(92 + offset)
    BrightYellow -> int.to_string(93 + offset)
    BrightBlue -> int.to_string(94 + offset)
    BrightMagenta -> int.to_string(95 + offset)
    BrightCyan -> int.to_string(96 + offset)
    BrightWhite -> int.to_string(97 + offset)
    Indexed(index) ->
      int.to_string(38 + offset)
      <> ";5;"
      <> int.to_string(int.clamp(index, 0, 255))
    Color(red, green, blue) ->
      string.join(
        [
          int.to_string(38 + offset),
          "2",
          int.to_string(int.clamp(red, 0, 255)),
          int.to_string(int.clamp(green, 0, 255)),
          int.to_string(int.clamp(blue, 0, 255)),
        ],
        ";",
      )
  }
}

/// Parse six hex digits, with an optional leading `#`.
pub fn hex(value: String) -> Result(Color, ColorError) {
  let digits = string.remove_prefix(value, "#")

  case string.byte_size(digits) == 6 {
    False -> Error(InvalidHex)
    True ->
      case colour.from_rgb_hex_string("#" <> digits) {
        Ok(c) -> {
          let #(r, g, b, _) = colour.to_rgba(c)

          let r_int = float.round(r *. 255.0)
          let g_int = float.round(g *. 255.0)
          let b_int = float.round(b *. 255.0)

          Ok(Color(r_int, g_int, b_int))
        }
        Error(Nil) -> Error(InvalidHex)
      }
  }
}
