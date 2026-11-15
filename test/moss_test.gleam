import gleam/list
import gleeunit
import gleeunit/should
import moss

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn unstyled_render_test() {
  moss.new()
  |> moss.render("plain\ntext")
  |> should.equal("plain\ntext")

  moss.new()
  |> moss.render("")
  |> should.equal("")
}

pub fn foreground_test() {
  list.each(
    [
      #(moss.Black, "\u{001b}[30mcolor\u{001b}[0m"),
      #(moss.Red, "\u{001b}[31mcolor\u{001b}[0m"),
      #(moss.Green, "\u{001b}[32mcolor\u{001b}[0m"),
      #(moss.Yellow, "\u{001b}[33mcolor\u{001b}[0m"),
      #(moss.Blue, "\u{001b}[34mcolor\u{001b}[0m"),
      #(moss.Magenta, "\u{001b}[35mcolor\u{001b}[0m"),
      #(moss.Cyan, "\u{001b}[36mcolor\u{001b}[0m"),
      #(moss.White, "\u{001b}[37mcolor\u{001b}[0m"),
      #(moss.BrightBlack, "\u{001b}[90mcolor\u{001b}[0m"),
      #(moss.BrightRed, "\u{001b}[91mcolor\u{001b}[0m"),
      #(moss.BrightGreen, "\u{001b}[92mcolor\u{001b}[0m"),
      #(moss.BrightYellow, "\u{001b}[93mcolor\u{001b}[0m"),
      #(moss.BrightBlue, "\u{001b}[94mcolor\u{001b}[0m"),
      #(moss.BrightMagenta, "\u{001b}[95mcolor\u{001b}[0m"),
      #(moss.BrightCyan, "\u{001b}[96mcolor\u{001b}[0m"),
      #(moss.BrightWhite, "\u{001b}[97mcolor\u{001b}[0m"),
    ],
    fn(example) {
      let #(color, expected) = example
      moss.new()
      |> moss.foreground(color)
      |> moss.render("color")
      |> should.equal(expected)
    },
  )
}

pub fn background_test() {
  list.each(
    [
      #(moss.Black, "\u{001b}[40mcolor\u{001b}[0m"),
      #(moss.Red, "\u{001b}[41mcolor\u{001b}[0m"),
      #(moss.Green, "\u{001b}[42mcolor\u{001b}[0m"),
      #(moss.Yellow, "\u{001b}[43mcolor\u{001b}[0m"),
      #(moss.Blue, "\u{001b}[44mcolor\u{001b}[0m"),
      #(moss.Magenta, "\u{001b}[45mcolor\u{001b}[0m"),
      #(moss.Cyan, "\u{001b}[46mcolor\u{001b}[0m"),
      #(moss.White, "\u{001b}[47mcolor\u{001b}[0m"),
      #(moss.BrightBlack, "\u{001b}[100mcolor\u{001b}[0m"),
      #(moss.BrightRed, "\u{001b}[101mcolor\u{001b}[0m"),
      #(moss.BrightGreen, "\u{001b}[102mcolor\u{001b}[0m"),
      #(moss.BrightYellow, "\u{001b}[103mcolor\u{001b}[0m"),
      #(moss.BrightBlue, "\u{001b}[104mcolor\u{001b}[0m"),
      #(moss.BrightMagenta, "\u{001b}[105mcolor\u{001b}[0m"),
      #(moss.BrightCyan, "\u{001b}[106mcolor\u{001b}[0m"),
      #(moss.BrightWhite, "\u{001b}[107mcolor\u{001b}[0m"),
    ],
    fn(example) {
      let #(color, expected) = example
      moss.new()
      |> moss.background(color)
      |> moss.render("color")
      |> should.equal(expected)
    },
  )
}

pub fn bold_test() {
  moss.new()
  |> moss.bold
  |> moss.render("bold")
  |> should.equal("\u{001b}[1mbold\u{001b}[0m")
}

pub fn faint_test() {
  moss.new()
  |> moss.faint
  |> moss.render("faint")
  |> should.equal("\u{001b}[2mfaint\u{001b}[0m")
}

pub fn italic_test() {
  moss.new()
  |> moss.italic
  |> moss.render("italic")
  |> should.equal("\u{001b}[3mitalic\u{001b}[0m")
}

pub fn underline_test() {
  moss.new()
  |> moss.underline
  |> moss.render("underline")
  |> should.equal("\u{001b}[4munderline\u{001b}[0m")
}

pub fn reverse_test() {
  moss.new()
  |> moss.reverse
  |> moss.render("reverse")
  |> should.equal("\u{001b}[7mreverse\u{001b}[0m")
}

pub fn strikethrough_test() {
  moss.new()
  |> moss.strikethrough
  |> moss.render("strikethrough")
  |> should.equal("\u{001b}[9mstrikethrough\u{001b}[0m")
}

pub fn combined_style_test() {
  moss.new()
  |> moss.foreground(moss.Green)
  |> moss.background(moss.Blue)
  |> moss.bold
  |> moss.italic
  |> moss.underline
  |> moss.render("Sprig")
  |> should.equal("\u{001b}[1;3;4;32;44mSprig\u{001b}[0m")
}

pub fn adjacent_runs_test() {
  let first = moss.new() |> moss.foreground(moss.Red) |> moss.faint
  let second = moss.new() |> moss.faint |> moss.foreground(moss.Red)
  assert first == second

  let styled = moss.render(first, "ab")
  let plain = moss.render(moss.new(), "cd")
  let other =
    moss.render(moss.new() |> moss.reverse |> moss.strikethrough, "ef")

  should.equal(
    styled <> plain <> other,
    "\u{001b}[2;31mab\u{001b}[0mcd\u{001b}[7;9mef\u{001b}[0m",
  )
}

pub fn indexed_colors_test() {
  moss.new()
  |> moss.foreground(moss.Indexed(201))
  |> moss.background(moss.Indexed(17))
  |> moss.bold
  |> moss.render("indexed")
  |> should.equal("\u{001b}[1;38;5;201;48;5;17mindexed\u{001b}[0m")
}

pub fn indexed_color_bounds_test() {
  moss.new()
  |> moss.foreground(moss.Indexed(-1))
  |> moss.background(moss.Indexed(256))
  |> moss.render("clamped")
  |> should.equal("\u{001b}[38;5;0;48;5;255mclamped\u{001b}[0m")
}

pub fn rgb_foreground_test() {
  moss.new()
  |> moss.foreground(moss.Color(255, 123, 19))
  |> moss.render("custom")
  |> should.equal("\u{001b}[38;2;255;123;19mcustom\u{001b}[0m")
}

pub fn rgb_background_test() {
  moss.new()
  |> moss.background(moss.Color(74, 89, 174))
  |> moss.render("custom")
  |> should.equal("\u{001b}[48;2;74;89;174mcustom\u{001b}[0m")
}

pub fn rgb_channel_bounds_test() {
  moss.new()
  |> moss.foreground(moss.Color(-1, 256, 128))
  |> moss.background(moss.Color(999, -20, 300))
  |> moss.render("clamped")
  |> should.equal("\u{001b}[38;2;0;255;128;48;2;255;0;255mclamped\u{001b}[0m")
}

pub fn hex_test() {
  moss.hex("#88C070")
  |> should.equal(Ok(moss.Color(136, 192, 112)))

  moss.hex("88c070")
  |> should.equal(Ok(moss.Color(136, 192, 112)))

  moss.hex("#000000")
  |> should.equal(Ok(moss.Color(0, 0, 0)))

  moss.hex("#ffffff")
  |> should.equal(Ok(moss.Color(255, 255, 255)))
}

pub fn invalid_hex_test() {
  list.each(
    ["", "#", "#fff", "#1234567", "#gg0000", "0x1234", "##123456", " 123456"],
    fn(value) {
      moss.hex(value)
      |> should.equal(Error(moss.InvalidHex))
    },
  )
}

pub fn hex_with_named_color_test() {
  let assert Ok(accent) = moss.hex("#88C070")

  moss.new()
  |> moss.foreground(accent)
  |> moss.background(moss.Blue)
  |> moss.bold
  |> moss.render("Sprig")
  |> should.equal("\u{001b}[1;38;2;136;192;112;44mSprig\u{001b}[0m")
}
