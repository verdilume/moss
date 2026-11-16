//// Draw ANSI-styled text using terminal cell coordinates.

import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import gleam/string_tree
import moss/internal/ansi_style
import string_width.{Size}

pub type Bounds {
  Bounds(x: Int, y: Int, width: Int, height: Int)
}

pub opaque type Layer {
  Layer(id: String, content: String, bounds: Bounds, z_index: Int)
}

pub opaque type Canvas {
  Canvas(width: Int, height: Int, cells: Dict(#(Int, Int), Cell))
}

type Cell {
  Cell(
    start: Int,
    width: Int,
    text: String,
    style: ansi_style.State,
    layer_id: Option(String),
  )
}

/// Make a layer at the origin with a z-index of zero. Spaces are opaque.
/// An empty line or the missing part of a short line leaves the canvas visible.
pub fn layer(id: String, content: String) -> Layer {
  let content = normalize(content)
  let Size(rows: height, columns: width) = string_width.dimensions(content)
  Layer(id:, content:, bounds: Bounds(0, 0, width, height), z_index: 0)
}

/// Move the layer in terminal columns and rows. Negative coordinates clip at
/// the top or left edge of the canvas.
pub fn position(layer: Layer, x x: Int, y y: Int) -> Layer {
  Layer(..layer, bounds: Bounds(..layer.bounds, x:, y:))
}

/// Set the paint order. Higher z-indices are on top. Among equal indices, a
/// later layer in the list is on top of an earlier layer.
pub fn z_index(layer: Layer, index: Int) -> Layer {
  Layer(..layer, z_index: index)
}

pub fn bounds(layer: Layer) -> Bounds {
  layer.bounds
}

/// Find the topmost layer with an ID, even if it is outside the viewport.
pub fn find_layer(layers: List(Layer), id: String) -> Option(Layer) {
  layers
  |> paint_order
  |> list.reverse
  |> list.find(fn(layer) { layer.id == id })
  |> option.from_result
}

/// Create an empty viewport. Negative dimensions become zero.
pub fn canvas(width width: Int, height height: Int) -> Canvas {
  Canvas(int.max(width, 0), int.max(height, 0), dict.new())
}

/// Draw a string at a cell coordinate. Tabs use eight-column stops relative to
/// the string's origin. SGR formatting and OSC 8 links can span multiple rows.
pub fn draw(canvas: Canvas, content: String, x x: Int, y y: Int) -> Canvas {
  paint(canvas, normalize(content), x, y, None)
}

/// Draw layers on a canvas in z-order. A wide grapheme cut by the viewport
/// becomes spaces. Overwriting one cell of a wide grapheme clears it entirely.
pub fn compose(canvas: Canvas, layers: List(Layer)) -> Canvas {
  list.fold(paint_order(layers), canvas, fn(canvas, layer) {
    paint(canvas, layer.content, layer.bounds.x, layer.bounds.y, Some(layer.id))
  })
}

/// Find the layer ID at a painted cell. Empty cells and content drawn directly
/// with `draw` have no layer ID.
pub fn hit_test(canvas: Canvas, x x: Int, y y: Int) -> Option(String) {
  case dict.get(canvas.cells, #(x, y)) {
    Ok(cell) -> cell.layer_id
    Error(Nil) -> None
  }
}

/// Render an automatically sized canvas with its origin at (0, 0).
pub fn render(layers: List(Layer)) -> String {
  let #(width, height) =
    list.fold(layers, #(0, 0), fn(size, layer) {
      let Bounds(x, y, width, height) = layer.bounds
      case width > 0 && height > 0 && x + width > 0 && y + height > 0 {
        True -> #(int.max(size.0, x + width), int.max(size.1, y + height))
        False -> size
      }
    })
  render_viewport(layers, width:, height:)
}

/// Render layers clipped to the given columns and rows.
pub fn render_viewport(
  layers: List(Layer),
  width width: Int,
  height height: Int,
) -> String {
  canvas(width:, height:) |> compose(layers) |> render_canvas
}

/// Render a canvas as rows separated by newlines. Unpainted cells are spaces.
pub fn render_canvas(canvas: Canvas) -> String {
  int.range(0, canvas.height, string_tree.new(), fn(output, row) {
    render_row(canvas, output, row)
  })
  |> string_tree.to_string
}

fn render_row(
  canvas: Canvas,
  output: string_tree.StringTree,
  row: Int,
) -> string_tree.StringTree {
  let empty = ansi_style.empty()
  let output = case row {
    0 -> output
    _ -> string_tree.append(output, "\n")
  }

  let #(output, style) =
    int.range(0, canvas.width, #(output, empty), fn(state, col) {
      let #(output, style) = state
      case dict.get(canvas.cells, #(col, row)) {
        Ok(cell) if cell.start != col -> state
        Ok(cell) -> #(
          output
            |> string_tree.append(ansi_style.transition(style, cell.style))
            |> string_tree.append(cell.text),
          cell.style,
        )
        Error(Nil) -> #(
          output
            |> string_tree.append(ansi_style.transition(style, empty))
            |> string_tree.append(" "),
          empty,
        )
      }
    })
  string_tree.append(output, ansi_style.transition(style, empty))
}

fn paint_order(layers: List(Layer)) -> List(Layer) {
  list.sort(layers, by: fn(a, b) { int.compare(a.z_index, b.z_index) })
}

fn normalize(content: String) -> String {
  content |> string.replace("\r\n", "\n") |> ansi_style.normalize
}

fn paint(
  canvas: Canvas,
  content: String,
  x: Int,
  y: Int,
  layer_id: Option(String),
) -> Canvas {
  let #(canvas, _) =
    string_width.fold(content, #(canvas, ansi_style.empty()), fn(state, piece) {
      let #(canvas, style) = state
      let column = x + piece.column
      let row = y + piece.row
      case piece.piece {
        "\n" -> state
        "\t" -> {
          let canvas =
            int.range(column, column + piece.width, canvas, fn(canvas, column) {
              paint_cell(canvas, row, Cell(column, 1, " ", style, layer_id))
            })
          #(canvas, style)
        }
        text if piece.width > 0 -> #(
          paint_cell(
            canvas,
            row,
            Cell(column, piece.width, text, style, layer_id),
          ),
          style,
        )
        escape -> #(canvas, ansi_style.apply(style, escape))
      }
    })
  canvas
}

fn paint_cell(canvas: Canvas, row: Int, cell: Cell) -> Canvas {
  let end = cell.start + cell.width
  let first = int.max(0, cell.start)
  let last = int.min(canvas.width, end)
  case row < 0 || row >= canvas.height || first >= last {
    True -> canvas
    False -> {
      // Clear intersecting glyphs before drawing any part of the replacement.
      let cells =
        int.range(first, last, canvas.cells, fn(cells, column) {
          case dict.get(cells, #(column, row)) {
            Error(Nil) -> cells
            Ok(old) ->
              int.range(
                old.start,
                old.start + old.width,
                cells,
                fn(cells, column) { dict.delete(cells, #(column, row)) },
              )
          }
        })
      let clipped = first != cell.start || last != end
      let cells =
        int.range(first, last, cells, fn(cells, column) {
          let visible = case clipped {
            True -> Cell(..cell, start: column, width: 1, text: " ")
            False -> cell
          }
          dict.insert(cells, #(column, row), visible)
        })
      Canvas(..canvas, cells:)
    }
  }
}
