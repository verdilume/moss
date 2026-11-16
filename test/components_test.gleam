import gleam/int
import gleam/string
import moss
import moss/list
import moss/table
import moss/tree
import string_width

pub fn table_aligns_multiline_and_ragged_cells_with_wide_text_test() {
  let rendered =
    table.new(["Key", "Value"], [["界", "12\n34"], ["a"]])
    |> table.cell_style(fn(row, _) {
      case row {
        table.Header -> moss.new() |> moss.bold
        table.Body(_) -> moss.new()
      }
    })
    |> table.column_alignment(fn(column) {
      case column {
        0 -> string_width.Left
        _ -> string_width.Right
      }
    })
    |> table.render

  assert string_width.strip_ansi(rendered)
    == "┌─────┬───────┐\n│ Key │ Value │\n├─────┼───────┤\n│ 界  │    12 │\n│     │    34 │\n│ a   │       │\n└─────┴───────┘"
  assert string.contains(rendered, "\u{001b}[1m Key \u{001b}[0m│")
}

pub fn table_border_style_covers_entire_horizontal_rules_test() {
  let rendered =
    table.new(["A", "B"], [["C", "D"]])
    |> table.border_style(moss.new() |> moss.foreground(moss.Green))
    |> table.render

  let assert [top, _, separator, _, bottom] = string.split(rendered, "\n")
  assert top == "\u{001b}[32m┌───┬───┐\u{001b}[0m"
  assert separator == "\u{001b}[32m├───┼───┤\u{001b}[0m"
  assert bottom == "\u{001b}[32m└───┴───┘\u{001b}[0m"
}

pub fn list_indents_continuation_and_child_lines_to_wide_markers_test() {
  let items = [
    list.Item("First\ncontinued", [list.Item("child", [])]),
    list.Item("Second", []),
  ]
  let numbered =
    list.render_with(
      items,
      marker: fn(_, depth, index) {
        case depth {
          0 -> "界" <> int.to_string(index + 1) <> " "
          _ -> "• "
        }
      },
      style: fn(_, _, _) { moss.new() },
    )

  assert numbered == "界1 First\n    continued\n    • child\n界2 Second"
}

pub fn tree_preserves_connectors_through_multiline_labels_test() {
  let root =
    tree.Node("Root", [
      tree.Node("Branch\ncontinued", [tree.Node("Leaf", [])]),
      tree.Node("Other", []),
    ])
  let rendered =
    tree.render_with(
      root,
      branch_style: moss.new() |> moss.foreground(moss.Green),
      label_style: fn(_, _) { moss.new() },
    )
  assert string_width.strip_ansi(rendered)
    == "Root\n├── Branch\n│   continued\n│   └── Leaf\n└── Other"
}
