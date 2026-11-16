import gleam/list
import gleam/string
import moss
import moss/compositor
import moss/gradient
import moss/ranges
import moss/terminal
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
  render(terminal.background_is_dark(fallback: True), columns)
  |> terminal.println
}

/// Render the Moss layout with the requested palette. Use zero columns
/// for the full-width document.
pub fn render(dark_background: Bool, columns: Int) -> String {
  let theme = fn(light, dark) {
    terminal.adaptive(light: rgb(light), dark: rgb(dark), dark_background:)
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

  let layers = [
    compositor.layer("page", page),
    compositor.layer("modal", modal())
      |> compositor.position(x: modal_x, y: modal_y),
  ]
  let size = string_width.dimensions(page)
  case columns > 0 && columns < size.columns {
    True ->
      compositor.render_viewport(layers, width: columns, height: size.rows)
    False -> compositor.render(layers)
  }
}

fn tabs(highlight: moss.Color) -> String {
  let edge = moss.new() |> moss.foreground(highlight)
  let inactive =
    moss.Border(
      top: "─",
      right: "│",
      bottom: "─",
      left: "│",
      top_left: "╭",
      top_right: "╮",
      bottom_left: "┴",
      bottom_right: "┴",
    )
  let active =
    moss.Border(..inactive, bottom: " ", bottom_left: "┘", bottom_right: "└")
  let blocks =
    ["Moss", "Styles", "Borders", "Colors", "Layers"]
    |> list.index_map(fn(name, index) {
      let glyphs = case index {
        0 -> active
        _ -> inactive
      }
      moss.new()
      |> moss.border(glyphs, edge)
      |> moss.padding(top: 0, right: 1, bottom: 0, left: 1)
      |> moss.render(name)
    })
  let row =
    string_width.stack_horizontal(blocks, string_width.Top, gap: 0, with: " ")
  let gap =
    moss.new()
    |> moss.width(width - 2 - string_width.line(row))
    |> moss.border(moss.normal_border_glyphs(), edge)
    |> moss.border_sides(moss.BorderSides(False, False, True, False))
    |> moss.render("")
  string_width.stack_horizontal(
    [row, gap],
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
    gradient.blend_1d(5, [rgb(mint), rgb("#55AB91")])
    |> list.index_map(fn(color, index) {
      style
      |> moss.background(color)
      |> moss.margin(top: 0, right: 0, bottom: 0, left: index * 2)
      |> moss.render("Moss")
    })
    |> string.join("\n")
  let info =
    "Made with Gleam"
    <> moss.render(subtle, " • ")
    <> moss.render(special, "https://github.com/verdilume/moss")
  let info =
    moss.new()
    |> moss.border(moss.normal_border_glyphs(), subtle)
    |> moss.border_sides(moss.BorderSides(True, False, False, False))
    |> moss.render(info)
  let description = "\nStyles and Layouts for Gleam Terminals\n" <> info

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
  let colors =
    gradient.blend_1d(string.length(question), [gradient_start, highlight])
  let spans =
    list.index_map(colors, fn(color, index) {
      ranges.Range(index, index + 1, moss.new() |> moss.foreground(color))
    })
  let question =
    moss.new()
    |> moss.width(50)
    |> moss.align_horizontal(string_width.Center)
    |> moss.render(ranges.render(question, spans))

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
  let side = { width - columns } / 2
  let top = { 9 - rows } / 2
  moss.new()
  |> moss.margin(
    top: top,
    right: width - columns - side,
    bottom: 9 - rows - top,
    left: side,
  )
  |> moss.margin_fill("青苔")
  |> moss.margin_style(subtle)
  |> moss.render(panel)
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

  let left = gradient.blend_1d(8, [rgb(mint), rgb("#215740")])
  let right = gradient.blend_1d(8, [rgb("#D9F99D"), rgb("#2DD4BF")])
  let grid =
    list.zip(left, right)
    |> list.map(fn(pair) {
      gradient.blend_1d(14, [pair.0, pair.1])
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
  let bordered = moss.new() |> moss.border(moss.normal_border_glyphs(), edge)
  let heading =
    bordered
    |> moss.border_sides(moss.BorderSides(False, False, True, False))
    |> moss.render(heading)
  bordered
  |> moss.border_sides(moss.BorderSides(False, True, False, False))
  |> moss.width(width / 3)
  |> moss.height(8)
  |> moss.margin(top: 0, right: 1, bottom: 0, left: 0)
  |> moss.render(string.join([heading, ..rows], "\n"))
}

fn notes() -> String {
  let style =
    moss.new()
    |> moss.foreground(rgb("#E9FBF2"))
    |> moss.background(rgb("#174936"))
    |> moss.width(history_width)
    |> moss.height(19)
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
      style
      |> moss.align_horizontal(alignment)
      |> moss.render(text)
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
  let value = status |> moss.width(available) |> moss.render(text)
  key <> value <> encoding <> brand
}

fn modal() -> String {
  moss.new()
  |> moss.italic
  |> moss.foreground(rgb("#102A22"))
  |> moss.background(rgb(mint))
  |> moss.padding(top: 1, right: 6, bottom: 1, left: 6)
  |> moss.render("Moss in the foreground")
}

fn rgb(hex: String) -> moss.Color {
  let assert Ok(color) = moss.hex(hex)
  color
}
