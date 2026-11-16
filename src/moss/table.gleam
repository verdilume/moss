//// Render tables with multiline cells, styled borders, and per-cell styling.

import gleam/int
import gleam/list
import gleam/string
import moss
import string_width

pub type Row {
  Header
  Body(index: Int)
}

pub opaque type Table {
  Table(
    headers: List(String),
    rows: List(List(String)),
    border_style: moss.Style,
    cell_style: fn(Row, Int) -> moss.Style,
    alignment: fn(Int) -> string_width.Alignment,
  )
}

/// Pass an empty header list to render a table without a header.
pub fn new(headers: List(String), rows: List(List(String))) -> Table {
  Table(headers, rows, moss.new(), fn(_, _) { moss.new() }, fn(_) {
    string_width.Left
  })
}

pub fn border_style(table: Table, style: moss.Style) -> Table {
  Table(..table, border_style: moss.span_style(style))
}

/// The callback receives the row and zero-based column for every cell.
pub fn cell_style(table: Table, style: fn(Row, Int) -> moss.Style) -> Table {
  Table(..table, cell_style: style)
}

/// Choose the text alignment of each zero-based column.
pub fn column_alignment(
  table: Table,
  alignment: fn(Int) -> string_width.Alignment,
) -> Table {
  Table(..table, alignment:)
}

pub fn render(table: Table) -> String {
  let rows = [table.headers, ..table.rows]
  let columns =
    list.fold(rows, 0, fn(count, row) { int.max(count, list.length(row)) })
  case columns {
    0 -> ""
    _ -> render_table(table, columns)
  }
}

fn render_table(table: Table, columns: Int) -> String {
  let headers = normalize_row(table.headers, columns)
  let rows = list.map(table.rows, normalize_row(_, columns))
  let widths =
    list.fold([headers, ..rows], list.repeat(0, columns), fn(widths, row) {
      list.zip(widths, row)
      |> list.map(fn(cell) { int.max(cell.0, string_width.line(cell.1)) })
    })
  let rule = fn(left, joint, right) {
    let line =
      left
      <> string.join(
        list.map(widths, fn(width) { string.repeat("─", width + 2) }),
        joint,
      )
      <> right
    moss.render(table.border_style, line)
  }
  let header_rows = case table.headers {
    [] -> []
    _ -> [render_row(table, Header, headers, widths), rule("├", "┼", "┤")]
  }
  let body_rows =
    list.index_map(rows, fn(row, index) {
      render_row(table, Body(index), row, widths)
    })
  let header_rows = case body_rows {
    [] -> list.take(header_rows, 1)
    _ -> header_rows
  }

  list.flatten([
    [rule("┌", "┬", "┐")],
    header_rows,
    body_rows,
    [rule("└", "┴", "┘")],
  ])
  |> string.join("\n")
}

fn normalize_row(row: List(String), columns: Int) -> List(String) {
  row
  |> list.map(fn(cell) {
    cell |> string.replace("\r\n", "\n") |> string_width.tabs_to_spaces
  })
  |> list.append(list.repeat("", columns - list.length(row)))
}

fn render_row(
  table: Table,
  row: Row,
  cells: List(String),
  widths: List(Int),
) -> String {
  let lines = list.map(cells, string.split(_, "\n"))
  let height =
    list.fold(lines, 1, fn(height, cell) { int.max(height, list.length(cell)) })
  let side = moss.render(table.border_style, "│")
  let columns =
    list.zip(lines, widths)
    |> list.index_map(fn(cell, index) {
      let #(lines, width) = cell
      let style = moss.span_style(table.cell_style(row, index))
      let padded =
        list.append(lines, list.repeat("", height - list.length(lines)))
      list.map(padded, fn(line) {
        let aligned =
          string_width.align(
            line,
            to: width,
            align: table.alignment(index),
            with: " ",
          )
        side <> moss.render(style, " " <> aligned <> " ")
      })
    })
  list.transpose(columns)
  |> list.map(fn(row) { string.concat(row) <> side })
  |> string.join("\n")
}
