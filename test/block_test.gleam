import moss

pub fn zero_padding_test() {
  let style = moss.new() |> moss.padding(top: 0, right: 0, bottom: 0, left: 0)

  assert moss.render(style, "") == ""
  assert moss.render(style, "a\n") == "a\n "
}

pub fn pads_all_four_sides_in_terminal_columns_test() {
  let padded = moss.new() |> moss.padding(top: 1, right: 2, bottom: 1, left: 1)

  assert moss.render(padded, "界\ne\u{0301}")
    == "     \n 界  \n e\u{0301}   \n     "
}

pub fn negative_padding_becomes_zero_test() {
  let padded =
    moss.new() |> moss.padding(top: -1, right: 2, bottom: -1, left: -1)

  assert moss.render(padded, "text") == "text  "
}

pub fn normalizes_tabs_and_crlf_test() {
  let padded = moss.new() |> moss.padding(top: 0, right: 0, bottom: 0, left: 1)

  assert moss.render(padded, "a\tb\r\nc") == " a       b\n c        "
}

pub fn styles_the_content_and_padding_test() {
  let styled =
    moss.new()
    |> moss.padding(top: 1, right: 1, bottom: 0, left: 1)
    |> moss.background(moss.Blue)

  assert moss.render(styled, "x")
    == "\u{001b}[44m   \u{001b}[0m\n\u{001b}[44m x \u{001b}[0m"
}

pub fn rounded_border_with_empty_content_test() {
  let bordered = moss.new() |> moss.rounded_border(moss.new())

  assert moss.render(bordered, "") == "╭╮\n││\n╰╯"
}

pub fn rounded_border_wraps_padded_unicode_rows_test() {
  let bordered =
    moss.new()
    |> moss.padding(top: 1, right: 1, bottom: 0, left: 1)
    |> moss.rounded_border(moss.new())

  assert moss.render(bordered, "界\nx")
    == "╭────╮\n│    │\n│ 界 │\n│ x  │\n╰────╯"
}

pub fn interior_and_border_styles_are_independent_test() {
  let border =
    moss.new()
    |> moss.foreground(moss.Cyan)
    |> moss.padding(top: 1, right: 1, bottom: 1, left: 1)

  let bordered =
    moss.new()
    |> moss.bold
    |> moss.rounded_border(border)

  assert moss.render(bordered, "x")
    == "\u{001b}[36m╭─╮\u{001b}[0m\n"
    <> "\u{001b}[36m│\u{001b}[0m\u{001b}[1mx\u{001b}[0m\u{001b}[36m│\u{001b}[0m\n"
    <> "\u{001b}[36m╰─╯\u{001b}[0m"
}

pub fn span_style_preserves_text_formatting_test() {
  let text_style = moss.new() |> moss.bold
  let boxed =
    text_style
    |> moss.padding(top: 1, right: 1, bottom: 0, left: 1)
    |> moss.rounded_border(moss.new())

  assert moss.span_style(boxed) == text_style
  assert boxed |> moss.unset_padding |> moss.unset_border == text_style
}
