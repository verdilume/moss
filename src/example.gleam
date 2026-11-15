import gleam/io
import moss
import moss/block

pub fn main() -> Nil {
  let text = "Hello, Moss!\n界 takes two columns.\ne\u{0301} takes one column."
  let padded =
    block.new()
    |> block.padding(top: 1, right: 2, bottom: 1, left: 2)
    |> block.style(
      moss.new()
      |> moss.foreground(moss.BrightCyan)
      |> moss.background(moss.Indexed(236)),
    )

  io.println("Padding")
  io.println(block.render(padded, text))

  io.println("\nRounded border")
  padded
  |> block.rounded_border(moss.new() |> moss.foreground(moss.BrightBlue))
  |> block.render(text)
  |> io.println
}
