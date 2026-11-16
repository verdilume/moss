import gleam/int
import gleam/io
import gleam/list
import gleam/string
import moss
import string_width.{Size}

const width = 96

const history_width = 30

const modal_x = 58

const modal_y = 44

const mint = "#6EE7B7"

pub fn main() -> Nil {
  let columns = case string_width.get_terminal_size() {
    Ok(size) -> size.columns
    Error(Nil) -> 0
  }
  let document = render(True, columns)
  case string_width.is_tty() {
    True -> io.println(document)
    False -> io.println(string_width.strip_ansi(document))
  }
}

/// Render the Moss layout with the requested palette. Use zero columns
/// for the full-width document.
pub fn render(dark_background: Bool, columns: Int) -> String {
  let theme = fn(light, dark) {
    case dark_background {
      True -> rgb(dark)
      False -> rgb(light)
    }
  }
  let subtle = moss.new() |> moss.foreground(theme("#557A6A", "#3F6253"))
  let highlight = theme("#26775E", mint)
  let special = moss.new() |> moss.foreground(theme("#12634D", mint))
  let gradient_start = theme("#467527", "#D9F99D")
  let completed =
    moss.new()
    |> moss.foreground(theme("#527364", "#87A99A"))
    |> moss.strikethrough
  let status =
    moss.new()
    |> moss.foreground(theme("#284638", "#D2E9DB"))
    |> moss.background(theme("#DDEEE4", "#203C31"))
  let background_name = case dark_background {
    True -> "Dark"
    False -> "Light"
  }

  let document =
    [
      tabs(highlight),
      title(subtle, special),
      dialog(subtle, highlight, gradient_start),
      lists_and_grid(subtle, special, completed),
      notes(),
      status_bar(status, background_name),
    ]
    |> string.join("\n\n")
  let page =
    moss.new()
    |> moss.padding(top: 1, right: 2, bottom: 1, left: 2)
    |> moss.render(document)
    |> add_modal

  case columns > 0 && columns < width + 4 {
    True ->
      page
      |> string.split("\n")
      |> list.map(slice_columns(_, 0, columns))
      |> string.join("\n")
    False -> page
  }
}

fn tabs(highlight: moss.Color) -> String {
  let edge = moss.new() |> moss.foreground(highlight)
  let names = ["Moss", "Styles", "Borders", "Colors", "Layers"]
  let blocks =
    list.index_map(names, fn(name, index) {
      let label = " " <> name <> " "
      let size = string_width.line(label)
      let bottom = case index {
        0 -> "┘" <> string.repeat(" ", size) <> "└"
        _ -> "┴" <> string.repeat("─", size) <> "┴"
      }
      let side = moss.render(edge, "│")
      string.join(
        [
          moss.render(edge, "╭" <> string.repeat("─", size) <> "╮"),
          side <> label <> side,
          moss.render(edge, bottom),
        ],
        "\n",
      )
    })
  let row =
    string_width.stack_horizontal(blocks, string_width.Top, gap: 0, with: " ")
  let gap = string.repeat("─", width - 2 - string_width.line(row))
  string_width.stack_horizontal(
    [row, moss.render(edge, gap)],
    string_width.Bottom,
    gap: 0,
    with: " ",
  )
}

fn title(subtle: moss.Style, special: moss.Style) -> String {
  let style =
    moss.new()
    |> moss.foreground(rgb("#102A22"))
    |> moss.italic
    |> moss.padding(top: 0, right: 1, bottom: 0, left: 1)
  let logo =
    blend(5, rgb(mint), rgb("#55AB91"))
    |> list.index_map(fn(color, index) {
      string.repeat(" ", index * 2)
      <> { style |> moss.background(color) |> moss.render("Moss") }
    })
    |> string.join("\n")
  let info =
    "Made with Gleam"
    <> moss.render(subtle, " • ")
    <> moss.render(special, "https://github.com/verdilume/moss")
  let description =
    "\nStyles and Layouts for Gleam Terminals\n"
    <> moss.render(subtle, string.repeat("─", string_width.line(info)))
    <> "\n"
    <> info

  string_width.stack_horizontal(
    [logo, description],
    string_width.Top,
    gap: 5,
    with: " ",
  )
}

fn dialog(
  subtle: moss.Style,
  highlight: moss.Color,
  gradient_start: moss.Color,
) -> String {
  let question = "Try the Moss palette?"
  let characters = string.to_graphemes(question)
  let colors = blend(list.length(characters), gradient_start, highlight)
  let question =
    list.zip(characters, colors)
    |> list.map(fn(pair) {
      let #(character, color) = pair
      moss.new() |> moss.foreground(color) |> moss.render(character)
    })
    |> string.concat
    |> string_width.align(to: 50, align: string_width.Center, with: " ")

  let button =
    moss.new()
    |> moss.foreground(rgb("#E9FBF2"))
    |> moss.padding(top: 0, right: 3, bottom: 0, left: 3)
  let yes =
    button
    |> moss.foreground(rgb("#102A22"))
    |> moss.background(rgb(mint))
    |> moss.underline
    |> moss.render("Yes")
  let maybe = button |> moss.background(rgb("#52685E")) |> moss.render("Maybe")
  let contents =
    [question, yes <> "  " <> maybe]
    |> string_width.stack_vertical(string_width.Center, gap: 1, with: " ")
  let panel =
    moss.new()
    |> moss.border_foreground(highlight)
    |> moss.padding(top: 1, right: 0, bottom: 1, left: 0)
    |> moss.render(contents)

  let Size(rows, columns) = string_width.dimensions(panel)
  let sides = moss_fill(subtle, { width - columns } / 2)
  let full = moss_fill(subtle, width)
  let top = { 9 - rows } / 2
  let panel_rows =
    string.split(panel, "\n") |> list.map(fn(row) { sides <> row <> sides })
  list.flatten([
    list.repeat(full, top),
    panel_rows,
    list.repeat(full, 9 - rows - top),
  ])
  |> string.join("\n")
}

fn moss_fill(style: moss.Style, columns: Int) -> String {
  // Each character takes two cells. Fill the last odd cell with a space.
  let remainder = case columns % 4 {
    0 -> ""
    1 -> " "
    2 -> "青"
    _ -> "青 "
  }
  moss.render(style, string.repeat("青苔", columns / 4) <> remainder)
}

fn lists_and_grid(
  subtle: moss.Style,
  special: moss.Style,
  completed: moss.Style,
) -> String {
  let check = moss.render(special, "✓ ")
  let styles =
    list_column(
      "Text Styles",
      [
        #(True, "Italics"),
        #(True, "Underline"),
        #(False, "Bold"),
        #(False, "Faint"),
        #(False, "Reverse video"),
      ],
      subtle,
      check,
      completed,
    )
  let layout =
    list_column(
      "Terminal Layout",
      [
        #(False, "Padding"),
        #(False, "Rounded borders"),
        #(True, "Aligned columns"),
        #(False, "Color gradients"),
        #(True, "Layered blocks"),
      ],
      subtle,
      check,
      completed,
    )

  let left = blend(8, rgb(mint), rgb("#215740"))
  let right = blend(8, rgb("#D9F99D"), rgb("#2DD4BF"))
  let grid =
    list.zip(left, right)
    |> list.map(fn(pair) {
      blend(14, pair.0, pair.1)
      |> list.map(fn(color) {
        moss.new() |> moss.background(color) |> moss.render("  ")
      })
      |> string.concat
    })
    |> string.join("\n")

  string_width.stack_horizontal(
    [styles, layout, " " <> string.replace(grid, "\n", "\n ")],
    string_width.Top,
    gap: 0,
    with: " ",
  )
}

fn list_column(
  heading: String,
  items: List(#(Bool, String)),
  edge: moss.Style,
  check: String,
  completed: moss.Style,
) -> String {
  let rows =
    list.map(items, fn(item) {
      case item {
        #(True, text) -> check <> moss.render(completed, text)
        #(False, text) -> "  " <> text
      }
    })
  let divider =
    moss.render(edge, string.repeat("─", string_width.line(heading)))
  let side = moss.render(edge, "│")
  [heading, divider, ..rows]
  |> list.append([""])
  |> list.map(fn(row) {
    string_width.align(
      row,
      to: width / 3 - 1,
      align: string_width.Left,
      with: " ",
    )
    <> side
    <> " "
  })
  |> string.join("\n")
}

fn notes() -> String {
  let style =
    moss.new()
    |> moss.foreground(rgb("#E9FBF2"))
    |> moss.background(rgb("#174936"))
    |> moss.padding(top: 1, right: 2, bottom: 1, left: 2)
  let blocks =
    [
      #(
        "Start with an empty Moss style and add a foreground, background, or text effect. Every setter returns a new value, so you can keep a base style for a screen and derive variations for labels, headings, and links. Render when the text is ready to print. Matching styles can share a single run when redrawing a terminal interface.",
        string_width.Right,
      ),
      #(
        "A block adds padding or a rounded border around its content. Moss measures each line in terminal cells, which keeps the edges aligned around wide characters. The dialog above uses a border with its own foreground color and sits inside a repeated moss pattern.",
        string_width.Center,
      ),
      #(
        "Join the finished blocks into columns, then layer a small panel over the page. This demo uses the same cell measurements to clip the page at the terminal edge, keeping wide characters whole. Redirect the output to save a plain-text version with the layout intact.",
        string_width.Left,
      ),
    ]
    |> list.map(fn(block) {
      let #(text, alignment) = block
      let wrapped =
        string_width.limit(
          text,
          to: Size(string.length(text), history_width - 4),
          ellipsis: "",
        )
      let missing_rows = int.max(0, 17 - string_width.dimensions(wrapped).rows)
      let padded = wrapped <> string.repeat("\n ", missing_rows)
      let aligned =
        string_width.align(
          padded,
          to: history_width - 4,
          align: alignment,
          with: " ",
        )
      moss.render(style, aligned)
    })

  string_width.stack_horizontal(blocks, string_width.Top, gap: 3, with: " ")
}

fn status_bar(status: moss.Style, background_name: String) -> String {
  let badge =
    moss.new()
    |> moss.foreground(rgb("#E9FBF2"))
    |> moss.padding(top: 0, right: 1, bottom: 0, left: 1)
  let key =
    badge
    |> moss.foreground(rgb("#102A22"))
    |> moss.background(rgb(mint))
    |> moss.render("STATUS")
  let encoding =
    badge |> moss.background(rgb("#26775E")) |> moss.render("UTF-8")
  let brand = badge |> moss.background(rgb("#174936")) |> moss.render("🌿 Moss")
  let available = width - string_width.line(key <> encoding <> brand)
  let text = " " <> background_name <> " palette"
  let value =
    string_width.align(text, to: available, align: string_width.Left, with: " ")
  key <> moss.render(status, value) <> encoding <> brand
}

fn add_modal(page: String) -> String {
  let modal =
    moss.new()
    |> moss.italic
    |> moss.foreground(rgb("#102A22"))
    |> moss.background(rgb(mint))
    |> moss.padding(top: 1, right: 6, bottom: 1, left: 6)
    |> moss.render("Moss in the foreground")
  let size = string_width.dimensions(modal)
  let rows = string.split(page, "\n")
  let #(before, rest) = list.split(rows, at: modal_y)
  let #(covered, after) = list.split(rest, at: size.rows)
  let right = modal_x + size.columns
  let overlaid =
    list.zip(covered, string.split(modal, "\n"))
    |> list.map(fn(pair) {
      let #(row, overlay) = pair
      slice_columns(row, 0, modal_x)
      <> overlay
      <> slice_columns(row, right, width + 4)
    })
  list.flatten([before, overlaid, after]) |> string.join("\n")
}

// Keep style resets and include only graphemes that fit entirely in the slice.
fn slice_columns(row: String, left: Int, right: Int) -> String {
  string_width.fold(row, from: "", with: fn(acc, piece) {
    case
      piece.width == 0
      || { piece.column >= left && piece.column + piece.width <= right }
    {
      True -> acc <> piece.piece
      False -> acc
    }
  })
}

fn rgb(hex: String) -> moss.Color {
  let assert Ok(color) = moss.hex(hex)
  color
}

fn blend(steps: Int, from: moss.Color, to: moss.Color) -> List(moss.Color) {
  let assert moss.Color(r1, g1, b1) = from
  let assert moss.Color(r2, g2, b2) = to
  let intervals = steps - 1
  int.range(0, steps, [], fn(colors, index) {
    let mix = fn(a, b) {
      { a * { intervals - index } + b * index + intervals / 2 } / intervals
    }
    [moss.Color(mix(r1, r2), mix(g1, g2), mix(b1, b2)), ..colors]
  })
  |> list.reverse
}
