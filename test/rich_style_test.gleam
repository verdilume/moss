import moss
import string_width

pub fn inherit_fills_only_unset_style_properties_test() {
  let fallback =
    moss.new()
    |> moss.foreground(moss.Red)
    |> moss.background(moss.Blue)
    |> moss.bold
    |> moss.padding(top: 0, right: 1, bottom: 0, left: 1)
    |> moss.underline_style(moss.DoubleUnderline)
    |> moss.underline_color(moss.Green)

  let style =
    moss.new()
    |> moss.foreground(moss.Cyan)
    |> moss.underline
    |> moss.inherit(fallback)

  assert moss.render(style, "a") == "\u{001b}[1;4;36;44;58;5;2ma\u{001b}[0m"
}

pub fn extended_underline_color_and_blink_can_be_cleared_test() {
  let style =
    moss.new()
    |> moss.blink
    |> moss.underline_style(moss.CurlyUnderline)
    |> moss.underline_color(moss.Color(110, 231, 183))

  assert moss.render(style, "a")
    == "\u{001b}[4:3;5;58;2;110;231;183ma\u{001b}[0m"
  assert style
    |> moss.unset_blink
    |> moss.unset_underline
    |> moss.unset_underline_color
    == moss.new()
}

pub fn inherit_keeps_explicit_default_alignment_and_local_spacing_test() {
  let base =
    moss.new()
    |> moss.width(6)
    |> moss.padding(top: 0, right: 0, bottom: 0, left: 1)
    |> moss.margin(top: 0, right: 0, bottom: 0, left: 1)
    |> moss.align_horizontal(string_width.Right)
    |> moss.fill(".")

  let style =
    moss.new()
    |> moss.align_horizontal(string_width.Left)
    |> moss.inherit(base)

  assert moss.render(style, "a") == "a....."
}

pub fn clipping_away_later_rows_closes_surviving_styles_and_links_test() {
  let box = moss.new() |> moss.max_height(1)
  let link =
    moss.new()
    |> moss.hyperlink("https://example.com")
    |> moss.foreground(moss.Red)
  let rendered = link |> moss.render("visible\nhidden") |> moss.render(box, _)
  assert rendered
    == "\u{001b}]8;;https://example.com\u{001b}\\\u{001b}[31mvisible\u{001b}]8;;\u{001b}\\\u{001b}[0m"
}
