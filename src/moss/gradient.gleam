import gleam/float
import gleam/int
import gleam/list
import moss.{type Color}
import moss/internal/rgb

type Lab {
  Lab(lightness: Float, a: Float, b: Float)
}

/// Blend evenly spaced color stops into a CIELAB gradient on the D65 white point.
/// Non-positive lengths and empty stops yield an empty list. A one-step gradient
/// returns the first stop. Exact stops retain their original color values.
/// Colors between stops are returned as RGB and clipped to the sRGB gamut.
/// Named and indexed stops use the standard xterm palette for interpolation.
pub fn blend_1d(steps: Int, stops: List(Color)) -> List(Color) {
  case steps > 0 && stops != [] {
    False -> []
    True -> {
      let stops = prepare(stops)
      let span = int.to_float(int.max(steps - 1, 1))
      generate(steps, fn(index) { sample(stops, int.to_float(index) /. span) })
    }
  }
}

/// Blend a rectangular CIELAB gradient, in row-major order. An angle of zero
/// runs from left to right. At 90 degrees it runs from bottom to top.
/// The projected corners define the first and last stops. Non-positive
/// dimensions or empty stops yield an empty list.
pub fn blend_2d(
  width width: Int,
  height height: Int,
  angle angle: Float,
  stops stops: List(Color),
) -> List(Color) {
  case width > 0 && height > 0 && stops != [] {
    False -> []
    True -> {
      let radians = angle *. 0.017453292519943295
      let horizontal = snap_direction(cos(radians))
      let vertical = snap_direction(0.0 -. sin(radians))
      let far_x = int.to_float(width - 1) *. horizontal
      let far_y = int.to_float(height - 1) *. vertical
      let start = float.min(0.0, far_x) +. float.min(0.0, far_y)
      let finish = float.max(0.0, far_x) +. float.max(0.0, far_y)
      let span = finish -. start
      let stops = prepare(stops)
      generate(width * height, fn(index) {
        let x = int.to_float(index % width)
        let y = int.to_float(index / width)
        let projection = x *. horizontal +. y *. vertical
        let position = case span == 0.0 {
          True -> 0.0
          False -> { projection -. start } /. span
        }
        sample(stops, float.clamp(position, 0.0, 1.0))
      })
    }
  }
}

fn snap_direction(value: Float) -> Float {
  case value >. -0.000000000001 && value <. 0.000000000001 {
    True -> 0.0
    False -> value
  }
}

@external(erlang, "math", "cos")
@external(javascript, "../moss_gradient_ffi.mjs", "cos")
fn cos(value: Float) -> Float

@external(erlang, "math", "sin")
@external(javascript, "../moss_gradient_ffi.mjs", "sin")
fn sin(value: Float) -> Float

fn generate(size: Int, sample: fn(Int) -> Result(Color, Nil)) -> List(Color) {
  int.range(0, size, [], fn(colors, index) {
    case sample(index) {
      Ok(color) -> [color, ..colors]
      Error(Nil) -> colors
    }
  })
  |> list.reverse
}

fn prepare(stops: List(Color)) -> List(#(Color, Lab)) {
  list.map(stops, fn(color) { #(color, to_lab(rgb.from_color(color))) })
}

fn sample(stops: List(#(Color, Lab)), position: Float) -> Result(Color, Nil) {
  let segment_position = position *. int.to_float(list.length(stops) - 1)
  let index = float.truncate(segment_position)
  case list.drop(stops, index) {
    [] -> Error(Nil)
    [#(start, _)] -> Ok(start)
    [#(start, from), #(_, to), ..] -> {
      let mixing = segment_position -. int.to_float(index)
      case mixing == 0.0 {
        True -> Ok(start)
        False ->
          Ok(
            from_lab(Lab(
              from.lightness +. { to.lightness -. from.lightness } *. mixing,
              from.a +. { to.a -. from.a } *. mixing,
              from.b +. { to.b -. from.b } *. mixing,
            )),
          )
      }
    }
  }
}

fn to_lab(color: rgb.Rgb) -> Lab {
  let r = rgb.linear(color.0)
  let g = rgb.linear(color.1)
  let b = rgb.linear(color.2)
  let x =
    lab_transfer(
      { 0.4124564 *. r +. 0.3575761 *. g +. 0.1804375 *. b } /. 0.95047,
    )
  let y = lab_transfer(0.2126729 *. r +. 0.7151522 *. g +. 0.072175 *. b)
  let z =
    lab_transfer(
      { 0.0193339 *. r +. 0.119192 *. g +. 0.9503041 *. b } /. 1.08883,
    )
  Lab(116.0 *. y -. 16.0, 500.0 *. { x -. y }, 200.0 *. { y -. z })
}

fn from_lab(lab: Lab) -> Color {
  let y = { lab.lightness +. 16.0 } /. 116.0
  let x = 0.95047 *. inverse_lab_transfer(y +. lab.a /. 500.0)
  let z = 1.08883 *. inverse_lab_transfer(y -. lab.b /. 200.0)
  let y = inverse_lab_transfer(y)
  moss.Color(
    rgb.srgb(3.2404542 *. x -. 1.5371385 *. y -. 0.4985314 *. z),
    rgb.srgb(-0.969266 *. x +. 1.8760108 *. y +. 0.041556 *. z),
    rgb.srgb(0.0556434 *. x -. 0.2040259 *. y +. 1.0572252 *. z),
  )
}

const lab_delta = 0.20689655172413793

fn lab_transfer(value: Float) -> Float {
  case value >. lab_delta *. lab_delta *. lab_delta {
    True -> rgb.power(value, 1.0 /. 3.0)
    False -> value /. { 3.0 *. lab_delta *. lab_delta } +. 4.0 /. 29.0
  }
}

fn inverse_lab_transfer(value: Float) -> Float {
  case value >. lab_delta {
    True -> value *. value *. value
    False -> 3.0 *. lab_delta *. lab_delta *. { value -. 4.0 /. 29.0 }
  }
}
