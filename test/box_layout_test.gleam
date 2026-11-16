import moss
import string_width

pub fn wraps_and_aligns_inside_the_requested_frame_test() {
  let boxed =
    moss.new()
    |> moss.border(moss.ascii_border_glyphs(), moss.new())
    |> moss.width(8)
    |> moss.height(6)
    |> moss.padding(top: 0, right: 1, bottom: 0, left: 1)
    |> moss.align_horizontal(string_width.Right)
    |> moss.align_vertical(string_width.Bottom)
    |> moss.margin(top: 0, right: 0, bottom: 0, left: 1)

  assert moss.render(boxed, "red blue")
    == " +------+\n |      |\n |      |\n |  red |\n | blue |\n +------+"
}

pub fn pads_with_complete_wide_glyphs_in_each_region_test() {
  let boxed =
    moss.new()
    |> moss.width(9)
    |> moss.align_horizontal(string_width.Center)
    |> moss.padding(top: 1, right: 1, bottom: 0, left: 3)
    |> moss.padding_fill("界")
    |> moss.fill(".")
    |> moss.margin(top: 1, right: 0, bottom: 0, left: 2)
    |> moss.margin_fill("苔")

  assert moss.render(boxed, "x") == "苔苔苔苔苔 \n苔界界界界 \n苔界 ..x.. "
  assert string_width.dimensions(moss.render(boxed, "x"))
    == string_width.Size(3, 11)
}

pub fn clips_finished_box_dimensions_without_splitting_glyphs_or_ansi_test() {
  let boxed =
    moss.new()
    |> moss.foreground(moss.Blue)
    |> moss.margin(top: 0, right: 0, bottom: 0, left: 1)
    |> moss.max_width(3)
    |> moss.max_height(1)

  assert moss.render(boxed, "a界b\nsecond") == " \u{001b}[34ma\u{001b}[0m"
}

pub fn supports_custom_patterns_and_independent_sides_test() {
  let glyphs =
    moss.Border(
      top: "-=",
      right: "!",
      bottom: "_",
      left: "界",
      top_left: "+++",
      top_right: ">",
      bottom_left: "⌞",
      bottom_right: "⌟",
    )
  let boxed =
    moss.new()
    |> moss.border(glyphs, moss.new())
    |> moss.border_sides(moss.BorderSides(
      top: True,
      right: True,
      bottom: False,
      left: True,
    ))

  assert moss.render(boxed, "yes") == "+++-=->\n界 yes!"
}

pub fn renders_side_colors_with_an_independent_margin_style_test() {
  let boxed =
    moss.new()
    |> moss.border(moss.double_border_glyphs(), moss.new())
    |> moss.border_sides(moss.BorderSides(
      top: True,
      right: True,
      bottom: False,
      left: False,
    ))
    |> moss.border_side_background(moss.Right, moss.Yellow)
    |> moss.border_foreground(moss.Cyan)
    |> moss.border_side_foreground(moss.Right, moss.Red)
    |> moss.margin(top: 0, right: 1, bottom: 0, left: 0)
    |> moss.margin_fill(".")
    |> moss.margin_style(moss.new() |> moss.foreground(moss.Green))

  assert moss.render(boxed, "x")
    == "\u{001b}[36m═╗\u{001b}[0m\u{001b}[32m.\u{001b}[0m\n"
    <> "x\u{001b}[31;43m║\u{001b}[0m\u{001b}[32m.\u{001b}[0m"
}

pub fn applies_the_color_ramp_clockwise_around_the_border_test() {
  let boxed =
    moss.new()
    |> moss.border(moss.ascii_border_glyphs(), moss.new())
    |> moss.border_gradient([
      moss.Red,
      moss.Green,
      moss.Yellow,
      moss.Blue,
      moss.Magenta,
      moss.Cyan,
      moss.White,
      moss.Black,
    ])

  assert moss.render(boxed, "x")
    == "\u{001b}[31m+\u{001b}[0m\u{001b}[32m-\u{001b}[0m\u{001b}[33m+\u{001b}[0m\n"
    <> "\u{001b}[30m|\u{001b}[0mx\u{001b}[34m|\u{001b}[0m\n"
    <> "\u{001b}[37m+\u{001b}[0m\u{001b}[36m-\u{001b}[0m\u{001b}[35m+\u{001b}[0m"
}

pub fn invalid_patterns_fall_back_to_spaces_test() {
  let boxed =
    moss.new()
    |> moss.width(3)
    |> moss.fill("\u{001b}[32m")
    |> moss.padding(top: 0, right: 0, bottom: 0, left: 1)
    |> moss.padding_fill("\n")

  assert moss.render(boxed, "x") == " x "
  assert moss.span_style(boxed) == moss.new()
}

pub fn width_can_grow_to_fit_a_wide_glyph_test() {
  let boxed = moss.new() |> moss.width(1)
  assert moss.render(boxed, "界") == "界"
}

pub fn wrapping_keeps_inline_colors_on_each_line_test() {
  let boxed = moss.new() |> moss.width(2)
  assert moss.render(boxed, "\u{001b}[31mabcd\u{001b}[0m")
    == "\u{001b}[31mab\u{001b}[m\n\u{001b}[31mcd\u{001b}[0m"
}
