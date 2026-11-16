//// Render hierarchy with box-drawing connectors.

import gleam/list
import gleam/string
import moss
import string_width

pub type Node {
  Node(label: String, children: List(Node))
}

pub fn render(root: Node) -> String {
  render_with(root, branch_style: moss.new(), label_style: fn(_, _) {
    moss.new()
  })
}

/// The label style callback receives the node and its zero-based depth.
pub fn render_with(
  root: Node,
  branch_style branch_style: moss.Style,
  label_style label_style: fn(Node, Int) -> moss.Style,
) -> String {
  let branch_style = moss.span_style(branch_style)
  let root_rows =
    label_rows(root.label, moss.span_style(label_style(root, 0)), "", "")
  list.append(
    root_rows,
    render_children(root.children, "", 1, branch_style, label_style),
  )
  |> string.join("\n")
}

fn render_children(
  children: List(Node),
  indent: String,
  depth: Int,
  branch_style: moss.Style,
  label_style: fn(Node, Int) -> moss.Style,
) -> List(String) {
  let last = list.length(children) - 1
  children
  |> list.index_map(fn(child, index) {
    let #(connector, continuation) = case index == last {
      True -> #("└── ", "    ")
      False -> #("├── ", "│   ")
    }
    let prefix = indent <> moss.render(branch_style, connector)
    let next_indent = indent <> moss.render(branch_style, continuation)
    let style = moss.span_style(label_style(child, depth))
    list.append(
      label_rows(child.label, style, prefix, next_indent),
      render_children(
        child.children,
        next_indent,
        depth + 1,
        branch_style,
        label_style,
      ),
    )
  })
  |> list.flatten
}

fn label_rows(
  label: String,
  style: moss.Style,
  first: String,
  continuation: String,
) -> List(String) {
  label
  |> string.replace("\r\n", "\n")
  |> string_width.tabs_to_spaces
  |> string.split("\n")
  |> list.index_map(fn(line, index) {
    let prefix = case index {
      0 -> first
      _ -> continuation
    }
    prefix <> moss.render(style, line)
  })
}
