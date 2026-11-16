import gleam/list
import gleam/string
import moss_layout
import string_width.{Size}

pub fn layout_keeps_the_document_and_overlay_at_their_expected_size_test() {
  let styled = moss_layout.render(True, 0)
  let plain = string_width.strip_ansi(styled)
  assert string_width.dimensions(plain) == Size(rows: 52, columns: 100)
  assert string.contains(styled, "\u{001b}[9;38;2;135;169;154mItalics")
  assert string.contains(styled, "\u{001b}[48;2;110;231;183m  ")
  assert string.contains(plain, "Try the Moss palette?")
  assert string.contains(plain, "Dark palette")

  let assert [notes_bottom] =
    styled |> string.split("\n") |> list.drop(48) |> list.take(1)
  assert list.length(string.split(
      notes_bottom,
      "\u{001b}[38;2;233;251;242;48;2;23;73;54m",
    ))
    == 4

  let assert [modal_top, modal_middle, modal_bottom] =
    styled |> string.split("\n") |> list.drop(44) |> list.take(3)
  let modal_background = "\u{001b}[3;38;2;16;42;34;48;2;110;231;183m"
  list.each([modal_top, modal_middle, modal_bottom], fn(row) {
    let assert Ok(#(left, _)) = string.split_once(row, on: modal_background)
    assert string_width.line(left) == 58
  })
  assert string.contains(modal_middle, "      Moss in the foreground      ")
}

pub fn light_palette_and_narrow_terminal_test() {
  let styled = moss_layout.render(False, 59)
  assert string.contains(styled, "\u{001b}[38;2;38;119;94m")
  let plain = string_width.strip_ansi(styled)
  assert string_width.dimensions(plain) == Size(rows: 52, columns: 59)
  assert string.contains(plain, "Light palette")
  let assert [pattern] =
    plain |> string.split("\n") |> list.drop(11) |> list.take(1)
  assert pattern == "  " <> string.repeat("青苔", 14) <> " "
}
