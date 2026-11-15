import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import moss
import string_width

/// A standalone text block with padding, an interior style, and an optional border.
pub opaque type Block {
  Block(
    top: Int,
    right: Int,
    bottom: Int,
    left: Int,
    interior: moss.Style,
    border: Option(moss.Style),
  )
}

/// Create a block with zero padding, an empty style, and no border.
pub fn new() -> Block {
  Block(
    top: 0,
    right: 0,
    bottom: 0,
    left: 0,
    interior: moss.new(),
    border: None,
  )
}

/// Set the padding in terminal rows and columns. Negative values become zero.
pub fn padding(
  block: Block,
  top top: Int,
  right right: Int,
  bottom bottom: Int,
  left left: Int,
) -> Block {
  Block(
    ..block,
    top: int.max(top, 0),
    right: int.max(right, 0),
    bottom: int.max(bottom, 0),
    left: int.max(left, 0),
  )
}

/// Apply a style to the content and its padding.
pub fn style(block: Block, style: moss.Style) -> Block {
  Block(..block, interior: style)
}

/// Add a rounded border with its own style. Pass `moss.new()` for a plain border.
pub fn rounded_border(block: Block, style: moss.Style) -> Block {
  Block(..block, border: Some(style))
}

/// Render plain text as a rectangular block. Shorter lines are filled on the
/// right. A trailing newline counts as an empty row, and tabs expand relative
/// to the start of the content.
pub fn render(block: Block, text: String) -> String {
  let lines =
    text
    |> string.replace("\r\n", "\n")
    |> string_width.tabs_to_spaces
    |> string.split("\n")
    |> list.map(fn(line) { #(line, string_width.line(line)) })

  let content_width =
    list.fold(lines, 0, fn(widest, line) { int.max(widest, line.1) })
  let width = content_width + block.left + block.right
  let left = string.repeat(" ", block.left)
  let blank = string.repeat(" ", width)
  let content =
    list.map(lines, fn(line) {
      let #(text, columns) = line
      left <> text <> string.repeat(" ", content_width - columns + block.right)
    })

  let rows =
    [list.repeat(blank, block.top), content, list.repeat(blank, block.bottom)]
    |> list.flatten
    |> list.map(moss.render(block.interior, _))

  let framed = case block.border {
    None -> rows
    Some(style) -> {
      // shortcut: assumes one-column box glyphs, add an ASCII preset for wide glyphs.
      let edge = string.repeat("─", width)
      let top = moss.render(style, "╭" <> edge <> "╮")
      let bottom = moss.render(style, "╰" <> edge <> "╯")
      let side = moss.render(style, "│")
      let middle = list.map(rows, fn(row) { side <> row <> side })
      list.flatten([[top], middle, [bottom]])
    }
  }

  string.join(framed, "\n")
}
