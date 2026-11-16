import gleam/dict
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import gleam/string_tree
import moss
import moss/internal/ansi_style
import moss/internal/rgb
import string_width

/// ANSI support of a terminal output stream.
pub type Profile {
  /// Remove all ANSI sequences, including hyperlink controls.
  Plain
  /// Remove color codes while preserving attributes and hyperlinks.
  NoColor
  Ansi16
  Ansi256
  TrueColor
}

/// Choose an output profile using TTY status, TERM, COLORTERM, and NO_COLOR.
pub fn detect_profile() -> Profile {
  profile_for(
    tty: stdout_is_tty(),
    term: getenv("TERM"),
    color_term: getenv("COLORTERM"),
    no_color: getenv("NO_COLOR"),
  )
}

/// Choose a profile for a stream using explicit capability hints.
pub fn profile_for(
  tty tty: Bool,
  term term: String,
  color_term color_term: String,
  no_color no_color: String,
) -> Profile {
  let term = string.lowercase(term)
  let color_term = string.lowercase(color_term)
  case tty, term, no_color, color_term {
    False, _, _, _ | _, "dumb", _, _ -> Plain
    _, _, value, _ if value != "" -> NoColor
    _, _, _, "truecolor" | _, _, _, "24bit" -> TrueColor
    _, _, _, _ ->
      case
        string.ends_with(term, "-direct")
        || string.ends_with(term, "-truecolor")
      {
        True -> TrueColor
        False ->
          case string.contains(term, "256color") {
            True -> Ansi256
            False -> Ansi16
          }
      }
  }
}

/// Downgrade ANSI foreground, background, and underline colors to a profile.
/// Named ANSI colors retain their terminal palette meaning. Non-color escapes
/// are preserved on all profiles except Plain.
pub fn render_for(profile: Profile, text: String) -> String {
  case profile {
    Plain -> text |> ansi_style.normalize |> string_width.strip_ansi
    TrueColor -> text
    _ -> {
      let #(output, _) =
        string_width.fold_raw(
          ansi_style.normalize(text),
          string_width.new(),
          from: #(string_tree.new(), dict.new()),
          with: fn(state, token, _) {
            let #(output, converted) = state
            case token {
              "\u{001b}[" <> fields -> {
                case dict.get(converted, token) {
                  Ok(sequence) -> #(
                    string_tree.append(output, sequence),
                    converted,
                  )
                  Error(Nil) -> {
                    let sequence = case string.ends_with(fields, "m") {
                      True ->
                        convert_sgr(profile, string.remove_suffix(fields, "m"))
                      False -> token
                    }
                    #(
                      string_tree.append(output, sequence),
                      dict.insert(converted, token, sequence),
                    )
                  }
                }
              }
              _ -> #(string_tree.append(output, token), converted)
            }
          },
        )
      string_tree.to_string(output)
    }
  }
}

/// Write a rendered string to stdout using its detected color profile.
pub fn print(text: String) -> Nil {
  io.print(render_for(detect_profile(), text))
}

/// Write a rendered line to stdout using its detected color profile.
pub fn println(text: String) -> Nil {
  io.println(render_for(detect_profile(), text))
}

/// Select a color for the detected or configured background.
pub fn adaptive(
  light light: moss.Color,
  dark dark: moss.Color,
  dark_background dark_background: Bool,
) -> moss.Color {
  case dark_background {
    True -> dark
    False -> light
  }
}

/// Read the terminal background through a bounded OSC 11 probe on a POSIX TTY.
/// Call during startup before another input reader takes ownership of stdin.
/// When no reply is available, try the last ANSI palette index in COLORFGBG.
pub fn background() -> Option(moss.Color) {
  let detected = case detect_profile() {
    Plain -> None
    _ -> parse_background(query_background(background_query))
  }
  case detected {
    Some(_) -> detected
    None -> {
      case list.last(string.split(getenv("COLORFGBG"), ";")) {
        Ok(last) ->
          case int.parse(string.trim(last)) {
            Ok(index) if index >= 0 && index <= 255 -> Some(moss.Indexed(index))
            _ -> None
          }
        Error(Nil) -> None
      }
    }
  }
}

/// Classify the terminal background by relative luminance, falling back to
/// the supplied choice when no background color is available.
pub fn background_is_dark(fallback fallback: Bool) -> Bool {
  case background() {
    Some(color) -> rgb.luminance(rgb.from_color(color)) <. 0.179
    None -> fallback
  }
}

fn convert_sgr(profile: Profile, fields: String) -> String {
  let fields = string.split(fields, ";")
  case convert_parameters(profile, fields, []) |> list.reverse {
    [] -> ""
    parameters -> "\u{001b}[" <> string.join(parameters, ";") <> "m"
  }
}

fn convert_parameters(
  profile: Profile,
  fields: List(String),
  output: List(String),
) -> List(String) {
  case fields {
    [] -> output
    [code, ..rest] -> {
      let #(replacement, rest) = case code {
        "38" | "48" | "58" -> convert_extended(profile, code, rest)
        _ -> #(convert_parameter(profile, code), rest)
      }
      let output = case replacement {
        Some(parameter) -> [parameter, ..output]
        None -> output
      }
      convert_parameters(profile, rest, output)
    }
  }
}

fn convert_extended(
  profile: Profile,
  code: String,
  values: List(String),
) -> #(Option(String), List(String)) {
  case values {
    ["2", r, g, b, ..rest] -> #(convert_rgb(profile, code, r, g, b), rest)
    ["5", index, ..rest] -> #(convert_index(profile, code, index), rest)
    ["2", ..] | ["5", ..] -> #(None, [])
    _ -> #(None, values)
  }
}

fn convert_parameter(profile: Profile, code: String) -> Option(String) {
  case string.split(code, ":") {
    ["38" as channel, ..values]
    | ["48" as channel, ..values]
    | ["58" as channel, ..values] -> {
      case values {
        ["2", r, g, b] -> convert_rgb(profile, channel, r, g, b)
        ["2", space, r, g, b, ..] if space == "" || space == "0" ->
          convert_rgb(profile, channel, r, g, b)
        ["5", index] -> convert_index(profile, channel, index)
        _ -> None
      }
    }
    _ ->
      case int.parse(code) {
        Ok(n)
          if profile == NoColor
          && { n >= 30 && n <= 49 || n >= 90 && n <= 107 || n == 59 }
        -> None
        Ok(59) if profile == Ansi16 -> None
        _ -> Some(code)
      }
  }
}

fn convert_rgb(
  profile: Profile,
  channel: String,
  r: String,
  g: String,
  b: String,
) -> Option(String) {
  case int.parse(r), int.parse(g), int.parse(b) {
    Ok(r), Ok(g), Ok(b)
      if r >= 0 && r <= 255 && g >= 0 && g <= 255 && b >= 0 && b <= 255
    -> {
      case profile {
        Ansi256 ->
          Some(indexed_code(
            channel,
            rgb.nearest_index(#(r, g, b), from: 16, through: 255),
          ))
        Ansi16 ->
          ansi16_code(
            channel,
            rgb.nearest_index(#(r, g, b), from: 0, through: 15),
          )
        _ -> None
      }
    }
    _, _, _ -> None
  }
}

fn convert_index(
  profile: Profile,
  channel: String,
  value: String,
) -> Option(String) {
  case int.parse(value) {
    Ok(index) if index >= 0 && index <= 255 -> {
      case profile {
        Ansi256 -> Some(indexed_code(channel, index))
        Ansi16 -> {
          let index = case index < 16 {
            True -> index
            False ->
              rgb.nearest_index(rgb.from_index(index), from: 0, through: 15)
          }
          ansi16_code(channel, index)
        }
        _ -> None
      }
    }
    _ -> None
  }
}

fn indexed_code(channel: String, index: Int) -> String {
  channel <> ";5;" <> int.to_string(index)
}

fn ansi16_code(channel: String, index: Int) -> Option(String) {
  let foreground = case index < 8 {
    True -> 30 + index
    False -> 90 + index - 8
  }
  case channel {
    "38" -> Some(int.to_string(foreground))
    "48" -> Some(int.to_string(foreground + 10))
    _ -> None
  }
}

fn parse_background(response: String) -> Option(moss.Color) {
  let response =
    response
    |> string.replace("\u{009d}", "\u{001b}]")
    |> string.replace("\u{009c}", "\u{0007}")
    |> string.replace("\u{001b}\\", "\u{0007}")
  case string.split_once(response, on: "\u{001b}]11;rgb:") {
    Ok(#(_, rgb)) ->
      case string.split_once(rgb, on: "\u{0007}") {
        Ok(#(rgb, _)) ->
          case string.split(rgb, "/") {
            [r, g, b] ->
              case parse_channel(r), parse_channel(g), parse_channel(b) {
                Ok(r), Ok(g), Ok(b) -> Some(moss.Color(r, g, b))
                _, _, _ -> None
              }
            _ -> None
          }
        Error(Nil) -> None
      }
    Error(Nil) -> None
  }
}

fn parse_channel(hex: String) -> Result(Int, Nil) {
  let maximum = case string.byte_size(hex) {
    1 -> 0xf
    2 -> 0xff
    3 -> 0xfff
    4 -> 0xffff
    _ -> 0
  }
  case int.base_parse(hex, 16) {
    Ok(value) if maximum > 0 && value >= 0 && value <= maximum ->
      Ok({ value * 255 + maximum / 2 } / maximum)
    _ -> Error(Nil)
  }
}

@external(erlang, "moss_terminal_ffi", "stdout_is_tty")
@external(javascript, "../moss_terminal_ffi.mjs", "stdoutIsTty")
fn stdout_is_tty() -> Bool

@external(erlang, "moss_terminal_ffi", "getenv")
@external(javascript, "../moss_terminal_ffi.mjs", "getenv")
fn getenv(name: String) -> String

@external(erlang, "moss_terminal_ffi", "query_background")
@external(javascript, "../moss_terminal_ffi.mjs", "queryBackground")
fn query_background(script: String) -> String

// Both runtimes use the same probe. An idle read stops after 100 ms and the
// watchdog also bounds reads from a terminal that sends bytes continuously.
const background_query =
  "
exec 2>/dev/null
saved=$(stty -g <&5) || exit 1
reader=
cleanup() {
  [ -z \"$reader\" ] || kill \"$reader\"
  stty \"$saved\" <&5
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM
stty -echo -icanon min 0 time 1 <&5 || exit 1
printf '\\033]11;?\\033\\\\' >&6 || exit 1
dd bs=1 count=64 <&5 &
reader=$!
(sleep 0.2; kill \"$reader\") </dev/null >/dev/null &
watchdog=$!
wait \"$reader\"
reader=
kill \"$watchdog\"
wait \"$watchdog\"
"
