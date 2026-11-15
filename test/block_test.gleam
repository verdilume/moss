import moss
import moss/block

pub fn zero_padding_test() {
  assert block.render(block.new(), "") == ""
  assert block.render(block.new(), "a\n") == "a\n "
}

pub fn pads_all_four_sides_in_terminal_columns_test() {
  let padded =
    block.new() |> block.padding(top: 1, right: 2, bottom: 1, left: 1)

  assert block.render(padded, "界\ne\u{0301}")
    == "     \n 界  \n e\u{0301}   \n     "
}

pub fn negative_padding_becomes_zero_test() {
  let padded =
    block.new() |> block.padding(top: -1, right: 2, bottom: -1, left: -1)

  assert block.render(padded, "text") == "text  "
}

pub fn normalizes_tabs_and_crlf_test() {
  let padded =
    block.new() |> block.padding(top: 0, right: 0, bottom: 0, left: 1)

  assert block.render(padded, "a\tb\r\nc") == " a       b\n c        "
}

pub fn styles_the_content_and_padding_test() {
  let styled =
    block.new()
    |> block.padding(top: 1, right: 1, bottom: 0, left: 1)
    |> block.style(moss.new() |> moss.background(moss.Blue))

  assert block.render(styled, "x")
    == "\u{001b}[44m   \u{001b}[0m\n\u{001b}[44m x \u{001b}[0m"
}

pub fn rounded_border_with_empty_content_test() {
  let bordered = block.new() |> block.rounded_border(moss.new())

  assert block.render(bordered, "") == "╭╮\n││\n╰╯"
}

pub fn rounded_border_wraps_padded_unicode_rows_test() {
  let bordered =
    block.new()
    |> block.padding(top: 1, right: 1, bottom: 0, left: 1)
    |> block.rounded_border(moss.new())

  assert block.render(bordered, "界\nx")
    == "╭────╮\n│    │\n│ 界 │\n│ x  │\n╰────╯"
}

pub fn interior_and_border_styles_are_independent_test() {
  let bordered =
    block.new()
    |> block.style(moss.new() |> moss.bold)
    |> block.rounded_border(moss.new() |> moss.foreground(moss.Cyan))

  assert block.render(bordered, "x")
    == "\u{001b}[36m╭─╮\u{001b}[0m\n"
    <> "\u{001b}[36m│\u{001b}[0m\u{001b}[1mx\u{001b}[0m\u{001b}[36m│\u{001b}[0m\n"
    <> "\u{001b}[36m╰─╯\u{001b}[0m"
}
