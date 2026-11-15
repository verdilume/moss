import gleam/io
import moss

pub fn main() -> Nil {
  let text = "Hello, Moss!\n界 takes two columns.\ne\u{0301} takes one column."
  let padded =
    moss.new()
    |> moss.padding(top: 1, right: 2, bottom: 1, left: 2)
    |> moss.foreground(moss.BrightCyan)
    |> moss.background(moss.Indexed(236))

  io.println("Padding")
  io.println(moss.render(padded, text))

  io.println("\nRounded border")
  padded
  |> moss.border_foreground(moss.BrightBlue)
  |> moss.render(text)
  |> io.println
}
