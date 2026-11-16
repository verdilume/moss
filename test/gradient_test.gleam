import moss
import moss/gradient

pub fn gradient_uses_lab_lightness_and_retains_exact_stops_test() {
  assert gradient.blend_1d(3, [moss.Black, moss.Indexed(231)])
    == [
      moss.Black,
      moss.Color(119, 119, 119),
      moss.Indexed(231),
    ]
  assert gradient.blend_1d(3, [moss.Red, moss.Green, moss.Blue])
    == [
      moss.Red,
      moss.Green,
      moss.Blue,
    ]
  assert gradient.blend_1d(1, [moss.Indexed(21), moss.White])
    == [moss.Indexed(21)]
  assert gradient.blend_1d(3, [moss.Cyan]) == [moss.Cyan, moss.Cyan, moss.Cyan]
  assert gradient.blend_1d(2, []) == []
  assert gradient.blend_1d(-1, [moss.Black]) == []
}

pub fn rectangle_uses_row_major_order_and_projected_endpoints_test() {
  let stops = [moss.Black, moss.BrightWhite]
  let middle = moss.Color(119, 119, 119)
  assert gradient.blend_2d(width: 3, height: 2, angle: 0.0, stops:)
    == [
      moss.Black, middle, moss.BrightWhite, moss.Black, middle, moss.BrightWhite,
    ]
  assert gradient.blend_2d(width: 2, height: 2, angle: 90.0, stops:)
    == [moss.BrightWhite, moss.BrightWhite, moss.Black, moss.Black]
  assert gradient.blend_2d(width: 2, height: 2, angle: 45.0, stops:)
    == [middle, moss.BrightWhite, moss.Black, middle]
  assert gradient.blend_2d(width: 1, height: 1, angle: 45.0, stops:)
    == [moss.Black]
  assert gradient.blend_2d(width: 0, height: 1, angle: 45.0, stops:) == []
}
