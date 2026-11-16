//// Render nested lists with hanging indentation.

import gleam/int
import gleam/list
import gleam/string
import moss
import string_width

pub type Item {
  Item(text: String, children: List(Item))
}

/// Render a bulleted list.
pub fn render(items: List(Item)) -> String {
  render_with(items, marker: fn(_, _, _) { "• " }, style: fn(_, _, _) {
    moss.new()
  })
}

/// Marker and style callbacks receive the item, zero-based depth, and
/// zero-based index among siblings. Include any desired space in the marker.
pub fn render_with(
  items: List(Item),
  marker marker: fn(Item, Int, Int) -> String,
  style style: fn(Item, Int, Int) -> moss.Style,
) -> String {
  render_items(items, 0, "", marker, style) |> string.join("\n")
}

fn render_items(
  items: List(Item),
  depth: Int,
  indent: String,
  marker: fn(Item, Int, Int) -> String,
  style: fn(Item, Int, Int) -> moss.Style,
) -> List(String) {
  items
  |> list.index_map(fn(item, index) {
    let prefix = marker(item, depth, index)
    let continuation = indent <> string.repeat(" ", string_width.line(prefix))
    let item_style = moss.span_style(style(item, depth, index))
    let rows =
      item.text
      |> string.replace("\r\n", "\n")
      |> string_width.tabs_to_spaces
      |> string.split("\n")
      |> list.index_map(fn(line, line_index) {
        let left = case line_index {
          0 -> indent <> prefix
          _ -> continuation
        }
        left <> moss.render(item_style, line)
      })
    let child_indent =
      indent <> string.repeat(" ", int.max(2, string_width.line(prefix)))
    list.append(
      rows,
      render_items(item.children, depth + 1, child_indent, marker, style),
    )
  })
  |> list.flatten
}
