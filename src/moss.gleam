import gleam/dict
import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import gleam_community/colour
import moss/internal/ansi_style
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

/// Underline shapes supported by terminals that implement extended SGR.
pub type Underline {
  SingleUnderline
  DoubleUnderline
  CurlyUnderline
  DottedUnderline
  DashedUnderline
}

/// An immutable style value that can be compared with `==`.
pub opaque type Style {
  Style(
    foreground: Option(Color),
    background: Option(Color),
    bold: Bool,
    faint: Bool,
    italic: Bool,
    underline: Option(Underline),
    underline_color: Option(Color),
    blink: Bool,
    reverse: Bool,
    strikethrough: Bool,
    hyperlink: Option(String),
    box: Box,
  )
}

type Box {
  Box(
    padding: Option(Insets),
    margin: Insets,
    width: Int,
    height: Int,
    max_width: Int,
    max_height: Int,
    horizontal: Option(string_width.Alignment),
    vertical: Option(string_width.Placement),
    padding_fill: String,
    margin_fill: String,
    margin_style: Option(Style),
    fill: Option(String),
    border: Option(BorderConfig),
  )
}

type Insets {
  Insets(top: Int, right: Int, bottom: Int, left: Int)
}

/// Glyphs or patterns for a border. Each field describes one row of text.
pub type Border {
  Border(
    top: String,
    right: String,
    bottom: String,
    left: String,
    top_left: String,
    top_right: String,
    bottom_left: String,
    bottom_right: String,
  )
}

/// Which sides to draw. Corners are drawn where two enabled sides meet.
pub type BorderSides {
  BorderSides(top: Bool, right: Bool, bottom: Bool, left: Bool)
}

pub type Side {
  Top
  Right
  Bottom
  Left
}

type BorderConfig {
  BorderConfig(
    glyphs: Border,
    sides: BorderSides,
    base: Style,
    side_styles: List(#(Side, Style)),
    colors: List(Color),
  )
}

fn default_box() -> Box {
  Box(
    padding: None,
    margin: Insets(0, 0, 0, 0),
    width: 0,
    height: 0,
    max_width: 0,
    max_height: 0,
    horizontal: None,
    vertical: None,
    padding_fill: " ",
    margin_fill: " ",
    margin_style: None,
    fill: None,
    border: None,
  )
}

/// Create an empty style for a text span.
pub fn new() -> Style {
  Style(
    foreground: None,
    background: None,
    bold: False,
    faint: False,
    italic: False,
    underline: None,
    underline_color: None,
    blink: False,
    reverse: False,
    strikethrough: False,
    hyperlink: None,
    box: default_box(),
  )
}

/// Fill unset span and box properties from a fallback style. Padding and
/// margins stay local to the receiving style.
pub fn inherit(style: Style, fallback: Style) -> Style {
  Style(
    foreground: option.or(style.foreground, fallback.foreground),
    background: option.or(style.background, fallback.background),
    bold: style.bold || fallback.bold,
    faint: style.faint || fallback.faint,
    italic: style.italic || fallback.italic,
    underline: option.or(style.underline, fallback.underline),
    underline_color: option.or(style.underline_color, fallback.underline_color),
    blink: style.blink || fallback.blink,
    reverse: style.reverse || fallback.reverse,
    strikethrough: style.strikethrough || fallback.strikethrough,
    hyperlink: option.or(style.hyperlink, fallback.hyperlink),
    box: inherit_box(style.box, fallback.box),
  )
}

fn inherit_box(box: Box, fallback: Box) -> Box {
  Box(
    ..box,
    width: inherit_dimension(box.width, fallback.width),
    height: inherit_dimension(box.height, fallback.height),
    max_width: inherit_dimension(box.max_width, fallback.max_width),
    max_height: inherit_dimension(box.max_height, fallback.max_height),
    horizontal: option.or(box.horizontal, fallback.horizontal),
    vertical: option.or(box.vertical, fallback.vertical),
    fill: option.or(box.fill, fallback.fill),
    border: option.or(box.border, fallback.border),
  )
}

fn inherit_dimension(value: Int, fallback: Int) -> Int {
  case value {
    0 -> fallback
    _ -> value
  }
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

/// Enable a single underline.
pub fn underline(style: Style) -> Style {
  underline_style(style, SingleUnderline)
}

/// Set the underline shape. Terminal support varies for extended underlines.
pub fn underline_style(style: Style, shape: Underline) -> Style {
  Style(..style, underline: Some(shape))
}

/// Disable underlined text.
pub fn unset_underline(style: Style) -> Style {
  Style(..style, underline: None)
}

/// Set the underline color. This can be combined with any underline shape.
pub fn underline_color(style: Style, color: Color) -> Style {
  Style(..style, underline_color: Some(color))
}

/// Clear the underline color.
pub fn unset_underline_color(style: Style) -> Style {
  Style(..style, underline_color: None)
}

/// Enable blinking text in terminals that support it.
pub fn blink(style: Style) -> Style {
  Style(..style, blink: True)
}

/// Disable blinking text.
pub fn unset_blink(style: Style) -> Style {
  Style(..style, blink: False)
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
  case url == "" || contains_control(url) {
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
  Style(
    ..style,
    box: Box(..style.box, padding: Some(insets(top, right, bottom, left))),
  )
}

/// Clear the box padding.
pub fn unset_padding(style: Style) -> Style {
  Style(..style, box: Box(..style.box, padding: None))
}

/// Set the minimum box width, including padding and borders. Text wraps to
/// the available space, expanding for any glyph wider than that space.
/// Margins are added afterward. Zero clears the width.
pub fn width(style: Style, columns: Int) -> Style {
  Style(..style, box: Box(..style.box, width: int.max(0, columns)))
}

/// Set the minimum box height, including padding and borders. Margins are
/// added afterward. Zero clears the height.
pub fn height(style: Style, rows: Int) -> Style {
  Style(..style, box: Box(..style.box, height: int.max(0, rows)))
}

/// Clip the finished box to this many terminal columns. Zero disables clipping.
pub fn max_width(style: Style, columns: Int) -> Style {
  Style(..style, box: Box(..style.box, max_width: int.max(0, columns)))
}

/// Clip the finished box to this many rows. Zero disables clipping.
pub fn max_height(style: Style, rows: Int) -> Style {
  Style(..style, box: Box(..style.box, max_height: int.max(0, rows)))
}

/// Align each line inside the content area.
pub fn align_horizontal(
  style: Style,
  alignment: string_width.Alignment,
) -> Style {
  Style(..style, box: Box(..style.box, horizontal: Some(alignment)))
}

/// Place the content and its padding within the requested box height.
pub fn align_vertical(
  style: Style,
  alignment: string_width.Placement,
) -> Style {
  Style(..style, box: Box(..style.box, vertical: Some(alignment)))
}

/// Set unstyled space outside the border. Negative values become zero.
pub fn margin(
  style: Style,
  top top: Int,
  right right: Int,
  bottom bottom: Int,
  left left: Int,
) -> Style {
  Style(
    ..style,
    box: Box(..style.box, margin: insets(top, right, bottom, left)),
  )
}

/// Repeat a pattern in the padding. Invalid or empty patterns use spaces.
pub fn padding_fill(style: Style, pattern: String) -> Style {
  Style(..style, box: Box(..style.box, padding_fill: box_pattern(pattern)))
}

/// Repeat a pattern in the margin. Invalid or empty patterns use spaces.
pub fn margin_fill(style: Style, pattern: String) -> Style {
  Style(..style, box: Box(..style.box, margin_fill: box_pattern(pattern)))
}

/// Style the space outside the border independently of the content.
pub fn margin_style(style: Style, margin_style: Style) -> Style {
  Style(
    ..style,
    box: Box(..style.box, margin_style: Some(span_style(margin_style))),
  )
}

/// Repeat a pattern in the space created when sizing or aligning content.
pub fn fill(style: Style, pattern: String) -> Style {
  Style(..style, box: Box(..style.box, fill: Some(box_pattern(pattern))))
}

fn insets(top: Int, right: Int, bottom: Int, left: Int) -> Insets {
  Insets(
    int.max(0, top),
    int.max(0, right),
    int.max(0, bottom),
    int.max(0, left),
  )
}

/// A rounded single-line border.
pub fn rounded_border_glyphs() -> Border {
  Border("─", "│", "─", "│", "╭", "╮", "╰", "╯")
}

/// A square single-line border.
pub fn normal_border_glyphs() -> Border {
  Border("─", "│", "─", "│", "┌", "┐", "└", "┘")
}

/// A square double-line border.
pub fn double_border_glyphs() -> Border {
  Border("═", "║", "═", "║", "╔", "╗", "╚", "╝")
}

/// A heavy single-line border.
pub fn thick_border_glyphs() -> Border {
  Border("━", "┃", "━", "┃", "┏", "┓", "┗", "┛")
}

/// An ASCII border.
pub fn ascii_border_glyphs() -> Border {
  Border("-", "|", "-", "|", "+", "+", "+", "+")
}

/// Use custom border glyphs and a default style for all sides.
/// An empty glyph reserves a space. Patterns must contain printable text.
pub fn border(style: Style, glyphs: Border, border_style: Style) -> Style {
  let glyphs =
    Border(
      box_pattern(glyphs.top),
      box_pattern(glyphs.right),
      box_pattern(glyphs.bottom),
      box_pattern(glyphs.left),
      box_pattern(glyphs.top_left),
      box_pattern(glyphs.top_right),
      box_pattern(glyphs.bottom_left),
      box_pattern(glyphs.bottom_right),
    )
  let config = current_border(style)
  set_border(
    style,
    BorderConfig(..config, glyphs:, base: span_style(border_style)),
  )
}

/// Add a rounded border using the given text style for its glyphs.
/// Pass `moss.new()` for a plain border.
pub fn rounded_border(style: Style, border_style: Style) -> Style {
  border(style, rounded_border_glyphs(), border_style)
}

/// Choose enabled sides. A new border defaults to rounded glyphs.
pub fn border_sides(style: Style, sides: BorderSides) -> Style {
  let config = current_border(style)
  set_border(style, BorderConfig(..config, sides:))
}

/// Set the foreground color of all border sides, adding a rounded border if needed.
pub fn border_foreground(style: Style, color: Color) -> Style {
  let config = current_border(style)
  let side_styles =
    list.map(config.side_styles, fn(pair) {
      #(pair.0, foreground(pair.1, color))
    })
  set_border(
    style,
    BorderConfig(..config, base: foreground(config.base, color), side_styles:),
  )
}

/// Set the background color of all border sides, adding a rounded border if needed.
pub fn border_background(style: Style, color: Color) -> Style {
  let config = current_border(style)
  let side_styles =
    list.map(config.side_styles, fn(pair) {
      #(pair.0, background(pair.1, color))
    })
  set_border(
    style,
    BorderConfig(..config, base: background(config.base, color), side_styles:),
  )
}

/// Override a side's border style. The top and bottom sides style their corners.
pub fn border_side_style(
  style: Style,
  side: Side,
  border_style: Style,
) -> Style {
  let config = current_border(style)
  let side_styles =
    list.key_set(config.side_styles, side, span_style(border_style))
  set_border(style, BorderConfig(..config, side_styles:))
}

/// Set a side's foreground color.
pub fn border_side_foreground(style: Style, side: Side, color: Color) -> Style {
  let side_style = edge_style(current_border(style), side)
  border_side_style(style, side, foreground(side_style, color))
}

/// Set a side's background color.
pub fn border_side_background(style: Style, side: Side, color: Color) -> Style {
  let side_style = edge_style(current_border(style), side)
  border_side_style(style, side, background(side_style, color))
}

/// Apply a color ramp clockwise around the enabled border. This overrides
/// border foreground colors. An empty ramp clears the gradient.
pub fn border_gradient(style: Style, colors: List(Color)) -> Style {
  let config = current_border(style)
  set_border(style, BorderConfig(..config, colors:))
}

/// Remove the border.
pub fn unset_border(style: Style) -> Style {
  Style(..style, box: Box(..style.box, border: None))
}

/// Keep the colors, attributes, and hyperlink for a text span or cell.
pub fn span_style(style: Style) -> Style {
  Style(..style, box: default_box())
}

fn current_border(style: Style) -> BorderConfig {
  case style.box.border {
    Some(config) -> config
    None ->
      BorderConfig(
        glyphs: rounded_border_glyphs(),
        sides: BorderSides(True, True, True, True),
        base: new(),
        side_styles: [],
        colors: [],
      )
  }
}

fn set_border(style: Style, config: BorderConfig) -> Style {
  Style(..style, box: Box(..style.box, border: Some(config)))
}

fn edge_style(config: BorderConfig, side: Side) -> Style {
  case list.key_find(config.side_styles, side) {
    Ok(style) -> style
    Error(Nil) -> config.base
  }
}

fn contains_control(text: String) -> Bool {
  text
  |> string.to_utf_codepoints
  |> list.any(fn(point) {
    let code = string.utf_codepoint_to_int(point)
    code < 0x20 || { code >= 0x7f && code <= 0x9f }
  })
}

fn box_pattern(pattern: String) -> String {
  case contains_control(pattern) || string_width.line(pattern) == 0 {
    True -> " "
    False -> pattern
  }
}

/// Render a styled span, or render a box when layout settings are present.
pub fn render(style: Style, text: String) -> String {
  case style.box == default_box() {
    True -> render_span(style, text)
    False -> render_box(style, text)
  }
}

fn render_box(style: Style, text: String) -> String {
  let box = style.box
  let padding = option.unwrap(box.padding, Insets(0, 0, 0, 0))
  let edges = case box.border {
    None -> Insets(0, 0, 0, 0)
    Some(config) -> border_insets(config)
  }
  let target_width =
    int.max(
      0,
      box.width - padding.left - padding.right - edges.left - edges.right,
    )
  let text =
    text
    |> ansi_style.normalize
    |> string.replace("\r\n", "\n")
    |> string_width.tabs_to_spaces
  let text = case
    box.width > 0 && string_width.line(text) > int.max(1, target_width)
  {
    True -> {
      let columns =
        string_width.fold(
          text,
          from: int.max(1, target_width),
          with: fn(widest, piece) { int.max(widest, piece.width) },
        )
      string_width.limit(
        text,
        to: string_width.Size(rows: string.byte_size(text) + 1, columns:),
        ellipsis: "",
      )
      |> string_width.inline_styles
    }
    False -> text
  }

  let lines =
    text
    |> string.split("\n")
    |> list.map(fn(line) { #(line, string_width.line(line)) })
  let content_width =
    list.fold(lines, target_width, fn(widest, line) { int.max(widest, line.1) })
  let inner_width = content_width + padding.left + padding.right
  let left_pad = fill_columns(box.padding_fill, padding.left)
  let right_pad = fill_columns(box.padding_fill, padding.right)
  let padding_row = fill_columns(box.padding_fill, inner_width)

  let fill = option.unwrap(box.fill, " ")
  let horizontal = option.unwrap(box.horizontal, string_width.Left)
  let content =
    list.map(lines, fn(line) {
      let #(text, columns) = line
      let missing = content_width - columns
      let before = case horizontal {
        string_width.Left -> 0
        string_width.Center -> missing / 2
        string_width.Right -> missing
      }
      left_pad
      <> fill_columns(fill, before)
      <> text
      <> fill_columns(fill, missing - before)
      <> right_pad
    })

  let missing_rows =
    int.max(
      0,
      box.height
        - edges.top
        - edges.bottom
        - padding.top
        - padding.bottom
        - list.length(lines),
    )
  let above = case option.unwrap(box.vertical, string_width.Top) {
    string_width.Top -> 0
    string_width.Middle -> missing_rows / 2
    string_width.Bottom -> missing_rows
  }
  let fill_row = fill_columns(fill, inner_width)
  let rows =
    list.flatten([
      list.repeat(fill_row, above),
      list.repeat(padding_row, padding.top),
      content,
      list.repeat(padding_row, padding.bottom),
      list.repeat(fill_row, missing_rows - above),
    ])
    |> list.map(render_span(style, _))

  let rows = case box.border {
    None -> rows
    Some(config) -> render_border(config, edges, rows, inner_width)
  }
  let rows = case box.margin {
    Insets(0, 0, 0, 0) -> rows
    _ -> render_margin(box, rows, inner_width + edges.left + edges.right)
  }
  let cropped_height = box.max_height > 0 && box.max_height < list.length(rows)
  let rows = case box.max_height {
    0 -> rows
    cap -> list.take(rows, cap)
  }
  let rows = case box.max_width {
    0 -> rows
    cap -> list.map(rows, fn(row) { take_columns(row, cap).0 })
  }
  let rendered = string.join(rows, "\n")
  case cropped_height {
    False -> rendered
    True -> {
      let empty = ansi_style.empty()
      let style =
        string_width.fold_raw(
          rendered,
          string_width.new(),
          from: empty,
          with: fn(style, piece, _) { ansi_style.apply(style, piece) },
        )
      rendered <> ansi_style.transition(style, empty)
    }
  }
}

fn render_margin(box: Box, rows: List(String), width: Int) -> List(String) {
  let margin = box.margin
  let style = option.unwrap(box.margin_style, new())
  let left = paint_margin(style, box.margin_fill, margin.left)
  let right = paint_margin(style, box.margin_fill, margin.right)
  let blank =
    paint_margin(style, box.margin_fill, width + margin.left + margin.right)
  list.flatten([
    list.repeat(blank, margin.top),
    list.map(rows, fn(row) { left <> row <> right }),
    list.repeat(blank, margin.bottom),
  ])
}

fn paint_margin(style: Style, fill: String, columns: Int) -> String {
  case columns {
    0 -> ""
    _ -> render_span(style, fill_columns(fill, columns))
  }
}

fn fill_columns(pattern: String, columns: Int) -> String {
  case columns, pattern {
    0, _ -> ""
    _, " " -> string.repeat(" ", columns)
    _, _ -> {
      let width = string_width.line(pattern)
      let remainder = columns % width
      let repeated = string.repeat(pattern, columns / width)
      case remainder {
        0 -> repeated
        _ -> {
          let #(prefix, used) = take_columns(pattern, remainder)
          repeated <> prefix <> string.repeat(" ", remainder - used)
        }
      }
    }
  }
}

// Keep ANSI sequences on either side of the cut, including style resets.
fn take_columns(row: String, columns: Int) -> #(String, Int) {
  let options = string_width.new()
  string_width.fold(row, from: #("", 0), with: fn(acc, piece) {
    let #(text, used) = acc
    let end = piece.column + piece.width
    case end <= columns, string_width.is_ansi_component(piece.piece, options) {
      True, _ -> #(text <> piece.piece, end)
      False, True -> #(text <> piece.piece, used)
      _, _ -> acc
    }
  })
}

fn border_insets(config: BorderConfig) -> Insets {
  let BorderSides(top, right, bottom, left) = config.sides
  let glyphs = config.glyphs
  let left_width = case left {
    False -> 0
    True ->
      [
        glyphs.left,
        visible(glyphs.top_left, top),
        visible(glyphs.bottom_left, bottom),
      ]
      |> string.join("\n")
      |> string_width.line
  }
  let right_width = case right {
    False -> 0
    True ->
      [
        glyphs.right,
        visible(glyphs.top_right, top),
        visible(glyphs.bottom_right, bottom),
      ]
      |> string.join("\n")
      |> string_width.line
  }
  Insets(
    case top {
      True -> 1
      False -> 0
    },
    right_width,
    case bottom {
      True -> 1
      False -> 0
    },
    left_width,
  )
}

fn visible(text: String, enabled: Bool) -> String {
  case enabled {
    True -> text
    False -> ""
  }
}

fn fit_border_glyph(glyph: String, columns: Int) -> String {
  case columns {
    0 -> ""
    _ -> glyph <> string.repeat(" ", columns - string_width.line(glyph))
  }
}

fn render_border(
  config: BorderConfig,
  edges: Insets,
  content: List(String),
  width: Int,
) -> List(String) {
  let glyphs = config.glyphs
  let height = list.length(content)
  let outer_width = edges.left + width + edges.right
  let right_start = outer_width * edges.top
  let bottom_start = right_start + edges.right * height
  let left_start = bottom_start + outer_width * edges.bottom
  let perimeter = left_start + edges.left * height
  let gradient = border_ramp(config.colors, perimeter)

  let horizontal_edge = fn(
    side,
    start,
    step,
    left_glyph,
    middle_glyph,
    right_glyph,
  ) {
    let edge =
      fit_border_glyph(left_glyph, edges.left)
      <> fill_columns(middle_glyph, width)
      <> fit_border_glyph(right_glyph, edges.right)
    paint_border(edge, edge_style(config, side), gradient, start, step)
  }
  let top = case config.sides.top {
    True -> [
      horizontal_edge(Top, 0, 1, glyphs.top_left, glyphs.top, glyphs.top_right),
    ]
    False -> []
  }
  let bottom = case config.sides.bottom {
    True -> [
      horizontal_edge(
        Bottom,
        left_start - 1,
        -1,
        glyphs.bottom_left,
        glyphs.bottom,
        glyphs.bottom_right,
      ),
    ]
    False -> []
  }
  let left_glyph = fit_border_glyph(glyphs.left, edges.left)
  let right_glyph = fit_border_glyph(glyphs.right, edges.right)
  let left_style = edge_style(config, Left)
  let right_style = edge_style(config, Right)
  let middle =
    list.index_map(content, fn(line, row) {
      paint_border(
        left_glyph,
        left_style,
        gradient,
        perimeter - 1 - row * edges.left,
        -1,
      )
      <> line
      <> paint_border(
        right_glyph,
        right_style,
        gradient,
        right_start + row * edges.right,
        1,
      )
    })

  list.flatten([top, middle, bottom])
}

fn border_ramp(
  colors: List(Color),
  perimeter: Int,
) -> Option(fn(Int) -> Color) {
  case colors {
    [] -> None
    _ -> {
      let intervals = int.max(1, perimeter - 1)
      let last = list.length(colors) - 1
      let palette =
        list.index_map(colors, fn(color, index) { #(index, color) })
        |> dict.from_list
      Some(fn(position) {
        let index = { position * last + intervals / 2 } / intervals
        let assert Ok(color) = dict.get(palette, index)
        color
      })
    }
  }
}

fn paint_border(
  text: String,
  style: Style,
  gradient: Option(fn(Int) -> Color),
  start: Int,
  step: Int,
) -> String {
  case text, gradient {
    "", _ -> ""
    _, None -> render_span(style, text)
    _, Some(color_at) ->
      string_width.fold(text, from: "", with: fn(acc, piece) {
        let offset = case step {
          1 -> piece.column
          _ -> -piece.column - int.max(0, piece.width - 1)
        }
        acc
        <> render_span(foreground(style, color_at(start + offset)), piece.piece)
      })
  }
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
  let underline = case style.underline {
    None -> ""
    Some(SingleUnderline) -> "4"
    Some(DoubleUnderline) -> "4:2"
    Some(CurlyUnderline) -> "4:3"
    Some(DottedUnderline) -> "4:4"
    Some(DashedUnderline) -> "4:5"
  }
  let attrs =
    [
      #(style.bold, "1"),
      #(style.faint, "2"),
      #(style.italic, "3"),
      #(underline != "", underline),
      #(style.blink, "5"),
      #(style.reverse, "7"),
      #(style.strikethrough, "9"),
    ]
    |> list.filter_map(fn(item) {
      case item.0 {
        True -> Ok(item.1)
        False -> Error(Nil)
      }
    })

  let colors =
    [
      #(style.foreground, 38),
      #(style.background, 48),
      #(style.underline_color, 58),
    ]
    |> list.filter_map(fn(channel) {
      case channel.0 {
        Some(color) -> Ok(color_to_code(color, channel.1))
        None -> Error(Nil)
      }
    })
  list.append(attrs, colors)
}

fn color_to_code(color: Color, base: Int) -> String {
  case color {
    Black -> basic_color_to_code(0, base)
    Red -> basic_color_to_code(1, base)
    Green -> basic_color_to_code(2, base)
    Yellow -> basic_color_to_code(3, base)
    Blue -> basic_color_to_code(4, base)
    Magenta -> basic_color_to_code(5, base)
    Cyan -> basic_color_to_code(6, base)
    White -> basic_color_to_code(7, base)
    BrightBlack -> basic_color_to_code(8, base)
    BrightRed -> basic_color_to_code(9, base)
    BrightGreen -> basic_color_to_code(10, base)
    BrightYellow -> basic_color_to_code(11, base)
    BrightBlue -> basic_color_to_code(12, base)
    BrightMagenta -> basic_color_to_code(13, base)
    BrightCyan -> basic_color_to_code(14, base)
    BrightWhite -> basic_color_to_code(15, base)
    Indexed(index) -> indexed_color_to_code(index, base)
    Color(red, green, blue) ->
      string.join(
        [
          int.to_string(base),
          "2",
          int.to_string(int.clamp(red, 0, 255)),
          int.to_string(int.clamp(green, 0, 255)),
          int.to_string(int.clamp(blue, 0, 255)),
        ],
        ";",
      )
  }
}

fn basic_color_to_code(index: Int, base: Int) -> String {
  case base, index < 8 {
    58, _ -> indexed_color_to_code(index, base)
    _, True -> int.to_string(base - 8 + index)
    _, False -> int.to_string(base + 44 + index)
  }
}

fn indexed_color_to_code(index: Int, base: Int) -> String {
  int.to_string(base) <> ";5;" <> int.to_string(int.clamp(index, 0, 255))
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
