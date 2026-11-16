import gleam/float
import gleam/int
import moss

pub type Rgb =
  #(Int, Int, Int)

pub fn from_color(color: moss.Color) -> Rgb {
  case color {
    moss.Black -> from_index(0)
    moss.Red -> from_index(1)
    moss.Green -> from_index(2)
    moss.Yellow -> from_index(3)
    moss.Blue -> from_index(4)
    moss.Magenta -> from_index(5)
    moss.Cyan -> from_index(6)
    moss.White -> from_index(7)
    moss.BrightBlack -> from_index(8)
    moss.BrightRed -> from_index(9)
    moss.BrightGreen -> from_index(10)
    moss.BrightYellow -> from_index(11)
    moss.BrightBlue -> from_index(12)
    moss.BrightMagenta -> from_index(13)
    moss.BrightCyan -> from_index(14)
    moss.BrightWhite -> from_index(15)
    moss.Indexed(index) -> from_index(index)
    moss.Color(red, green, blue) -> #(
      int.clamp(red, 0, 255),
      int.clamp(green, 0, 255),
      int.clamp(blue, 0, 255),
    )
  }
}

pub fn from_index(index: Int) -> Rgb {
  let index = int.clamp(index, 0, 255)
  case index {
    0 -> #(0, 0, 0)
    1 -> #(128, 0, 0)
    2 -> #(0, 128, 0)
    3 -> #(128, 128, 0)
    4 -> #(0, 0, 128)
    5 -> #(128, 0, 128)
    6 -> #(0, 128, 128)
    7 -> #(192, 192, 192)
    8 -> #(128, 128, 128)
    9 -> #(255, 0, 0)
    10 -> #(0, 255, 0)
    11 -> #(255, 255, 0)
    12 -> #(0, 0, 255)
    13 -> #(255, 0, 255)
    14 -> #(0, 255, 255)
    15 -> #(255, 255, 255)
    _ if index < 232 -> {
      let cube = index - 16
      #(
        cube_channel(cube / 36),
        cube_channel(cube / 6 % 6),
        cube_channel(cube % 6),
      )
    }
    _ -> {
      let gray = 8 + { index - 232 } * 10
      #(gray, gray, gray)
    }
  }
}

fn cube_channel(level: Int) -> Int {
  case level {
    0 -> 0
    _ -> 55 + level * 40
  }
}

pub fn nearest_index(color: Rgb, from start: Int, through end: Int) -> Int {
  let #(index, _) =
    int.range(start, end + 1, #(start, 256 * 256 * 3), fn(best, candidate) {
      let #(r, g, b) = from_index(candidate)
      let dr = color.0 - r
      let dg = color.1 - g
      let db = color.2 - b
      let distance = dr * dr + dg * dg + db * db
      case distance < best.1 {
        True -> #(candidate, distance)
        False -> best
      }
    })
  index
}

pub fn linear(channel: Int) -> Float {
  let value = int.to_float(channel) /. 255.0
  case value <=. 0.04045 {
    True -> value /. 12.92
    False -> power({ value +. 0.055 } /. 1.055, 2.4)
  }
}

pub fn srgb(value: Float) -> Int {
  let value = float.clamp(value, 0.0, 1.0)
  let encoded = case value <=. 0.0031308 {
    True -> 12.92 *. value
    False -> 1.055 *. power(value, 1.0 /. 2.4) -. 0.055
  }
  float.round(encoded *. 255.0)
}

pub fn luminance(color: Rgb) -> Float {
  let #(red, green, blue) = color
  0.2126 *. linear(red) +. 0.7152 *. linear(green) +. 0.0722 *. linear(blue)
}

pub fn power(base: Float, exponent: Float) -> Float {
  let assert Ok(value) = float.power(base, of: exponent)
  value
}
