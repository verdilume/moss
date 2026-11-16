import moss
import moss/terminal.{Ansi16, Ansi256, NoColor, Plain, TrueColor}

pub fn profile_respects_redirection_terminal_hints_and_no_color_test() {
  assert terminal.profile_for(
      tty: False,
      term: "xterm-256color",
      color_term: "truecolor",
      no_color: "",
    )
    == Plain
  assert terminal.profile_for(
      tty: True,
      term: "DUMB",
      color_term: "truecolor",
      no_color: "",
    )
    == Plain
  assert terminal.profile_for(
      tty: True,
      term: "xterm-256color",
      color_term: "truecolor",
      no_color: "0",
    )
    == NoColor
  assert terminal.profile_for(
      tty: True,
      term: "xterm-256color",
      color_term: "24bit",
      no_color: "",
    )
    == TrueColor
  assert terminal.profile_for(
      tty: True,
      term: "xterm-direct",
      color_term: "",
      no_color: "",
    )
    == TrueColor
  assert terminal.profile_for(
      tty: True,
      term: "screen-256color",
      color_term: "",
      no_color: "",
    )
    == Ansi256
  assert terminal.profile_for(
      tty: True,
      term: "vt100",
      color_term: "",
      no_color: "",
    )
    == Ansi16
  assert terminal.adaptive(
      light: moss.Black,
      dark: moss.White,
      dark_background: True,
    )
    == moss.White
  assert terminal.adaptive(
      light: moss.Black,
      dark: moss.White,
      dark_background: False,
    )
    == moss.Black
}

pub fn profiles_convert_colors_and_preserve_attributes_and_links_test() {
  let open_link = "\u{001b}]8;;https://example.org\u{001b}\\"
  let close_link = "\u{001b}]8;;\u{001b}\\"
  let reset = "\u{001b}[0m"
  let text = "界 sample 👩‍💻"
  let styled =
    open_link
    <> "\u{001b}[1;38;2;255;0;0;48;5;21;4:3m"
    <> text
    <> reset
    <> close_link
  assert terminal.render_for(TrueColor, styled) == styled
  assert terminal.render_for(Ansi256, styled)
    == open_link
    <> "\u{001b}[1;38;5;196;48;5;21;4:3m"
    <> text
    <> reset
    <> close_link
  assert terminal.render_for(Ansi16, styled)
    == open_link <> "\u{001b}[1;91;104;4:3m" <> text <> reset <> close_link
  assert terminal.render_for(NoColor, styled)
    == open_link <> "\u{001b}[1;4:3m" <> text <> reset <> close_link
  assert terminal.render_for(Plain, styled) == text
}

pub fn colon_colors_swallow_only_their_own_parameters_test() {
  let styled =
    "\u{001b}[38:2::0:255:0;48:5:16;58:2:0:0:0:255;2;7mX\u{001b}[39;49;59m"
  assert terminal.render_for(Ansi256, styled)
    == "\u{001b}[38;5;46;48;5;16;58;5;21;2;7mX\u{001b}[39;49;59m"
  assert terminal.render_for(Ansi16, styled)
    == "\u{001b}[92;40;2;7mX\u{001b}[39;49m"
  assert terminal.render_for(NoColor, styled) == "\u{001b}[2;7mX"
  assert terminal.render_for(NoColor, "\u{001b}[38;2;1;2mX\u{001b}[K")
    == "X\u{001b}[K"
}
