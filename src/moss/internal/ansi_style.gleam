import gleam/int
import gleam/list
import gleam/string

pub opaque type State {
  State(sgr: List(String), link: String)
}

const reset = "\u{1b}[0m"

const close_link = "\u{1b}]8;;\u{1b}\\"

pub fn empty() -> State {
  State([], "")
}

/// Convert C1 controls to ESC sequences before measuring or tokenizing text.
pub fn normalize(text: String) -> String {
  text
  |> string.replace("\u{009b}", "\u{1b}[")
  |> string.replace("\u{009d}", "\u{1b}]")
  |> string.replace("\u{009c}", "\u{1b}\\")
}

/// Track SGR and OSC 8 without replaying terminal commands such as cursor moves.
pub fn apply(state: State, escape: String) -> State {
  case escape {
    "\u{1b}[" <> sgr -> apply_sgr(state, sgr, escape)
    "\u{1b}]8;" <> link -> apply_link(state, link)
    "\u{009b}" <> _ | "\u{009d}8;" <> _ -> apply(state, normalize(escape))
    _ -> state
  }
}

fn apply_sgr(state: State, sgr: String, escape: String) -> State {
  let parameters = string.remove_suffix(sgr, "m")
  let valid =
    parameters != sgr
    && list.all(string.to_utf_codepoints(parameters), fn(point) {
      let code = string.utf_codepoint_to_int(point)
      code >= 0x30 && code <= 0x3b
    })

  case valid, parameters, state.sgr {
    False, _, _ -> state
    True, "", _ | True, "0", _ -> State(..state, sgr: [])
    True, "0;" <> _, _ | True, ";" <> _, _ -> State(..state, sgr: [escape])
    True, _, [first, ..] if first == escape -> state
    True, _, previous ->
      State(..state, sgr: [
        escape,
        ..without_overwritten_color(parameters, previous)
      ])
  }
}

fn without_overwritten_color(
  parameters: String,
  previous: List(String),
) -> List(String) {
  case standalone_color(parameters), previous {
    0, _ -> previous
    color, ["\u{1b}[" <> prior, ..rest] ->
      case standalone_color(string.remove_suffix(prior, "m")) == color {
        True -> rest
        False -> previous
      }
    _, _ -> previous
  }
}

fn standalone_color(parameters: String) -> Int {
  case string.split(parameters, ";") {
    [code] ->
      case int.parse(code) {
        Ok(n) if { n >= 30 && n <= 37 } || { n >= 90 && n <= 97 } || n == 39 ->
          38
        Ok(n) if { n >= 40 && n <= 47 } || { n >= 100 && n <= 107 } || n == 49 ->
          48
        Ok(59) -> 58
        _ -> 0
      }
    [code, "5", index] -> extended_color(code, [index])
    [code, "2", r, g, b] -> extended_color(code, [r, g, b])
    _ -> 0
  }
}

fn extended_color(code: String, channels: List(String)) -> Int {
  let valid =
    list.all(channels, fn(channel) {
      case int.parse(channel) {
        Ok(value) -> value >= 0 && value <= 255
        Error(Nil) -> False
      }
    })
  case valid, int.parse(code) {
    True, Ok(38) -> 38
    True, Ok(48) -> 48
    True, Ok(58) -> 58
    _, _ -> 0
  }
}

fn apply_link(state: State, link: String) -> State {
  let payload =
    link
    |> string.remove_suffix("\u{1b}\\")
    |> string.remove_suffix("\u{7}")
    |> string.remove_suffix("\u{009c}")
  let safe =
    payload != link
    && list.all(string.to_utf_codepoints(payload), fn(point) {
      let code = string.utf_codepoint_to_int(point)
      code >= 0x20 && { code < 0x7f || code > 0x9f }
    })

  case safe, string.split_once(payload, on: ";") {
    True, Ok(#(_, "")) -> State(..state, link: "")
    True, Ok(_) -> State(..state, link: "\u{1b}]8;" <> payload <> "\u{1b}\\")
    _, _ -> state
  }
}

/// Replay the top style's SGR parameters after the base's. An unspecified
/// hyperlink in the top style inherits the base link.
pub fn overlay(base: State, top: State) -> State {
  let link = case top.link {
    "" -> base.link
    link -> link
  }
  State(list.append(top.sgr, base.sgr), link)
}

/// Transition between known styles, restoring the destination's active codes.
pub fn transition(from previous: State, to next: State) -> String {
  let link = case previous.link == next.link, previous.link {
    True, _ -> ""
    False, "" -> next.link
    False, _ -> close_link <> next.link
  }

  let sgr = case previous.sgr == next.sgr, previous.sgr {
    True, _ -> ""
    False, [] -> next.sgr |> list.reverse |> string.concat
    False, _ -> reset <> { next.sgr |> list.reverse |> string.concat }
  }

  link <> sgr
}
