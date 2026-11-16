import gleam/string
import moss
import moss/internal/ansi_style
import moss/ranges
import string_width

pub fn range_offsets_count_graphemes_and_preserve_the_surrounding_style_test() {
  let family = "👩‍👩‍👦‍👦"
  let base = moss.new() |> moss.bold |> moss.foreground(moss.Red)
  let accent = moss.new() |> moss.foreground(moss.Green)
  let text = moss.render(base, "a" <> family <> "z")
  let rendered = ranges.render(text, [ranges.Range(1, 2, accent)])
  assert string_width.strip_ansi(rendered) == "a" <> family <> "z"

  let options = string_width.new()
  let #(_, pieces) =
    string_width.fold(
      rendered,
      from: #(ansi_style.empty(), []),
      with: fn(acc, piece) {
        let #(style, pieces) = acc
        case string_width.is_ansi_component(piece.piece, options) {
          True -> #(ansi_style.apply(style, piece.piece), pieces)
          False -> #(style, [
            #(piece.piece, ansi_style.transition(ansi_style.empty(), style)),
            ..pieces
          ])
        }
      },
    )
  let assert [#("z", red_after), #(emoji, green), #("a", red_before)] = pieces
  assert emoji == family
  assert red_before == red_after
  assert string.contains(red_before, "31")
  assert string.contains(green, "32")
}

pub fn range_links_close_at_the_boundary_test() {
  let link = moss.new() |> moss.hyperlink("https://example.com")
  let result = ranges.render("abc", [ranges.Range(1, 2, link)])
  assert result == "a" <> moss.render(link, "b") <> "c"
  assert ranges.render("abc", [ranges.Range(2, 1, link)]) == "abc"
}

pub fn range_preserves_c1_formatting_and_grapheme_offsets_test() {
  let styled = "\u{009b}31mabc\u{009b}0m"
  let rendered =
    ranges.render(styled, [ranges.Range(1, 2, moss.new() |> moss.bold)])
  assert string_width.strip_ansi(rendered) == "abc"
  assert string.contains(rendered, "\u{001b}[31m")
  assert string.contains(rendered, "\u{001b}[1m")
}
