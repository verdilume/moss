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
