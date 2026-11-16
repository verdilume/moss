//// Apply span styles to grapheme ranges in plain or ANSI-styled text.

import gleam/int
import gleam/list
import gleam/string
import moss
import moss/internal/ansi_style
import string_width

/// A half-open range of zero-based grapheme offsets. Escape sequences do
/// not consume an offset. Only the span properties of the style are used.
pub type Range {
  Range(start: Int, end: Int, style: moss.Style)
}

type StyledRange {
  StyledRange(start: Int, end: Int, style: ansi_style.State)
}

type RenderState {
  RenderState(
    index: Int,
    ranges: List(StyledRange),
    source: ansi_style.State,
    emitted: ansi_style.State,
    chunks: List(String),
  )
}

/// Apply the ranges while preserving the surrounding SGR and hyperlink state.
/// Ranges are sorted by start offset. The first range covers any overlap.
pub fn render(text: String, ranges: List(Range)) -> String {
  let ranges =
    ranges
    |> list.filter_map(fn(range) {
      let start = int.max(range.start, 0)
      case range.end > start {
        True -> Ok(StyledRange(start, range.end, state_for(range.style)))
        False -> Error(Nil)
      }
    })
    |> list.sort(fn(a, b) { int.compare(a.start, b.start) })
  case ranges {
    [] -> text
    _ -> {
      let empty = ansi_style.empty()
      let options = string_width.new()
      let state =
        string_width.fold(
          ansi_style.normalize(text),
          from: RenderState(0, ranges, empty, empty, []),
          with: fn(state, piece) {
            case string_width.is_ansi_component(piece.piece, options) {
              True -> push_escape(state, piece.piece)
              False -> push_grapheme(state, piece.piece)
            }
          },
        )
      let tail = ansi_style.transition(state.emitted, state.source)
      [tail, ..state.chunks] |> list.reverse |> string.concat
    }
  }
}

fn state_for(style: moss.Style) -> ansi_style.State {
  // Everything before the marker opens the Moss span.
  let rendered = moss.render(moss.span_style(style), "\u{0000}")
  let assert Ok(#(opening, _)) = string.split_once(rendered, on: "\u{0000}")
  string_width.fold(opening, from: ansi_style.empty(), with: fn(state, piece) {
    ansi_style.apply(state, piece.piece)
  })
}

fn push_escape(state: RenderState, escape: String) -> RenderState {
  let is_style = case escape {
    "\u{001b}[" <> body | "\u{009b}" <> body -> string.ends_with(body, "m")
    "\u{001b}]8;" <> _ | "\u{009d}8;" <> _ -> True
    _ -> False
  }
  case is_style {
    True -> RenderState(..state, source: ansi_style.apply(state.source, escape))
    False -> {
      let before = ansi_style.transition(state.emitted, state.source)
      RenderState(..state, emitted: state.source, chunks: [
        escape,
        before,
        ..state.chunks
      ])
    }
  }
}

fn push_grapheme(state: RenderState, grapheme: String) -> RenderState {
  let ranges =
    list.drop_while(state.ranges, fn(range) { range.end <= state.index })
  let style = case ranges {
    [range, ..] if range.start <= state.index ->
      ansi_style.overlay(state.source, range.style)
    _ -> state.source
  }
  let transition = ansi_style.transition(state.emitted, style)
  RenderState(..state, index: state.index + 1, ranges:, emitted: style, chunks: [
    grapheme,
    transition,
    ..state.chunks
  ])
}
