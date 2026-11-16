import gleam/option.{None, Some}
import moss
import moss/compositor

pub fn z_order_and_hit_testing_test() {
  let base = compositor.layer("base", "abc\ndef")
  let front =
    compositor.layer("front", "X")
    |> compositor.position(x: 1, y: 0)
    |> compositor.z_index(2)
  let ragged = compositor.layer("ragged", "  \nq")
  let layers = [front, base, ragged]
  let canvas =
    compositor.canvas(width: 4, height: 2) |> compositor.compose(layers)

  assert compositor.render_canvas(canvas) == " Xc \nqef "
  assert compositor.hit_test(canvas, x: 0, y: 0) == Some("ragged")
  assert compositor.hit_test(canvas, x: 1, y: 0) == Some("front")
  assert compositor.hit_test(canvas, x: 1, y: 1) == Some("base")
  assert compositor.hit_test(canvas, x: 3, y: 0) == None
  assert compositor.find_layer(layers, "front") == Some(front)
  assert compositor.bounds(front) == compositor.Bounds(1, 0, 1, 1)
  assert compositor.render(layers) == " Xc\nqef"
}

pub fn viewport_and_occlusion_keep_graphemes_whole_test() {
  let wide = compositor.layer("wide", "A界B\ne\u{301}🌿z")
  let top = compositor.layer("top", "x") |> compositor.position(x: 2, y: 0)
  let canvas =
    compositor.canvas(width: 4, height: 2) |> compositor.compose([wide, top])
  assert compositor.render_canvas(canvas) == "A xB\ne\u{301}🌿z"
  assert compositor.hit_test(canvas, x: 1, y: 0) == None
  assert compositor.hit_test(canvas, x: 2, y: 1) == Some("wide")
  assert compositor.render_viewport([wide], width: 2, height: 2)
    == "A \ne\u{301} "
  assert compositor.render([compositor.position(wide, x: -2, y: -1)]) == " z"
}

pub fn canvas_clips_drawings_and_expands_tabs_test() {
  let empty = compositor.canvas(width: 4, height: 3)
  let drawn = empty |> compositor.draw("a\tz\r\n界b\nxyz", x: -5, y: -1)
  assert compositor.render_canvas(empty) == "    \n    \n    "
  assert compositor.render_canvas(drawn) == "    \n    \n    "

  let drawn = empty |> compositor.draw("a\tz\r\n界b", x: -5, y: 0)
  assert compositor.render_canvas(drawn) == "   z\n    \n    "
  assert compositor.hit_test(drawn, x: 3, y: 0) == None
}

pub fn applies_terminal_styles_without_leaking_across_layers_or_rows_test() {
  let open_link = "\u{1b}]8;;https://example.org\u{1b}\\"
  let close_link = "\u{1b}]8;;\u{1b}\\"
  let red = "\u{1b}[31m"
  let green = "\u{1b}[32m"
  let reset = "\u{1b}[0m"
  let base =
    moss.new()
    |> moss.foreground(moss.Red)
    |> moss.hyperlink("https://example.org")
    |> moss.render("abc\ndef")
    |> compositor.layer("base", _)
  let overlay =
    moss.new()
    |> moss.foreground(moss.Green)
    |> moss.render("X")
    |> compositor.layer("overlay", _)
    |> compositor.position(x: 1, y: 0)

  assert compositor.render([base, overlay])
    == open_link
    <> red
    <> "a"
    <> close_link
    <> reset
    <> green
    <> "X"
    <> open_link
    <> reset
    <> red
    <> "c"
    <> close_link
    <> reset
    <> "\n"
    <> open_link
    <> red
    <> "def"
    <> close_link
    <> reset
}

pub fn ignores_cursor_controls_and_keeps_selective_sgr_and_osc8_test() {
  let osc_bel = "\u{1b}]8;;https://example.org\u{7}"
  let osc_st = "\u{1b}]8;;https://example.org\u{1b}\\"
  let close_link = "\u{1b}]8;;\u{1b}\\"
  let reset = "\u{1b}[0m"
  let red_bold = "\u{1b}[31;1m"
  let no_bold = "\u{1b}[22m"
  let base =
    compositor.layer(
      "base",
      osc_bel <> red_bold <> "A\u{1b}[2J" <> no_bold <> "B" <> close_link <> "C",
    )

  assert compositor.render_viewport([base], width: 2, height: 1)
    == osc_st
    <> red_bold
    <> "A"
    <> reset
    <> red_bold
    <> no_bold
    <> "B"
    <> close_link
    <> reset
}

pub fn c1_controls_render_as_canonical_sgr_and_hyperlinks_test() {
  let content =
    "\u{009b}31m\u{009d}8;;https://example.org\u{009c}A\u{009d}8;;\u{009c}\u{009b}0mB"
  let layer = compositor.layer("c1", content)
  let drawing =
    compositor.canvas(width: 2, height: 1)
    |> compositor.draw(content, x: 0, y: 0)
  let expected =
    "\u{1b}]8;;https://example.org\u{1b}\\\u{1b}[31mA\u{1b}]8;;\u{1b}\\\u{1b}[0mB"

  assert compositor.bounds(layer) == compositor.Bounds(0, 0, 2, 1)
  assert compositor.render([layer]) == expected
  assert compositor.render_canvas(drawing) == expected
}

pub fn color_changes_replace_the_previous_color_without_losing_bold_test() {
  let bold = "\u{1b}[1m"
  let red = "\u{1b}[31m"
  let blue = "\u{1b}[38;2;0;80;255m"
  let reset = "\u{1b}[0m"
  let layer = compositor.layer("colors", bold <> red <> "A" <> blue <> "B")

  assert compositor.render([layer])
    == bold <> red <> "A" <> reset <> bold <> blue <> "B" <> reset
}
