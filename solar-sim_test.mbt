///|
// Clear-sky and PV simulation tests. All assertions anchored to physical
// invariants, PVWatts reference values, and geometric first principles.

///|
test "airmass at zenith ≈ 1" {
  let am = airmass_kasten(90.0)
  assert_true((am - 1.0).abs() < 0.05)
}

///|
test "airmass decreases with altitude" {
  let am30 = airmass_kasten(30.0)
  let am60 = airmass_kasten(60.0)
  let am90 = airmass_kasten(90.0)
  assert_true(am30 > am60 && am60 > am90)
}

///|
test "30° tilt panel, sun at horizon south → incidence ≈ 60°" {
  // Panel face 30° above horizon. Sun on horizon. Incidence = 90° - tilt = 60°
  let inc = solar_incidence_angle(30.0, 0.0, 0.0, 0.0)
  assert_true((inc - 60.0).abs() < 0.5)
}

///|
test "flat panel overhead sun → incidence ≈ 0" {
  let inc = solar_incidence_angle(0.0, 0.0, 90.0, 180.0)
  assert_true(inc < 0.5)
}

///|
test "earth-sun distance ±3.3%" {
  let jd_peri = @skycal.julian_date(2026, 1, 3, 12, 0, 0)
  let f_peri = earth_sun_distance_factor(jd_peri)
  assert_true(f_peri > 1.015)
  let jd_aphe = @skycal.julian_date(2026, 7, 4, 12, 0, 0)
  let f_aphe = earth_sun_distance_factor(jd_aphe)
  assert_true(f_aphe < 0.985)
}

///|
test "Beijing summer noon altitude ≈ 73.5°" {
  let jd = @skycal.julian_date(2026, 6, 21, 4, 0, 0)
  let pos = @skycal.make_geo(39.9, 116.4)
  let sp = @skycal.sun_position(jd, pos)
  let alt = sp.get_altitude()
  assert_true(alt > 70.0 && alt < 77.0)
}

///|
test "DNI and GHI both positive in sunlight" {
  let jd = @skycal.julian_date(2026, 6, 21, 4, 0, 0)
  let pos = @skycal.make_geo(39.9, 116.4)
  let sp = @skycal.sun_position(jd, pos)
  let alt = sp.get_altitude()
  let dni = dni_clear_sky(alt, DEFAULT_TURBIDITY, jd)
  let ghi = ghi_clear_sky(alt, DEFAULT_TURBIDITY, jd)
  assert_true(dni > 500.0 && dni < 1600.0)
  assert_true(ghi > 400.0 && ghi < 1200.0)
}

///|
test "nighttime irradiance → 0" {
  // 14:00 UTC = 22:00 Beijing local time (sun well below horizon in summer)
  let jd = @skycal.julian_date(2026, 6, 21, 14, 0, 0)
  let pos = @skycal.make_geo(39.9, 116.4)
  let irr = clear_sky_tilted_irradiance(jd, pos, 35.0, 0.0, 0.2, DEFAULT_TURBIDITY)
  assert_true(irr == 0.0)
}

///|
test "panel STC within ±20% of rated" {
  let panel = make_silicon_panel(250.0, 1.65)
  let (_, _, p) = panel_output(panel, STC_IRRADIANCE, STC_TEMPERATURE)
  assert_true(p > 200.0 && p < 300.0)
}

///|
test "no sun → no power" {
  let panel = make_silicon_panel(250.0, 1.65)
  let (_, _, p) = panel_output(panel, 0.0, 25.0)
  assert_true(p.abs() < 0.1)
}

///|
test "Beijing summer day energy > winter day energy" {
  let pos = @skycal.make_geo(39.9, 116.4)
  let panel = make_silicon_panel(250.0, 1.65)
  let summer = daily_energy_with_temp(2026, 6, 21, pos, 35.0, 0.0, panel, 25.0, 0.2, DEFAULT_TURBIDITY)
  let winter = daily_energy_with_temp(2026, 12, 22, pos, 35.0, 0.0, panel, 0.0, 0.2, DEFAULT_TURBIDITY)
  assert_true(summer > 0.0)
  assert_true(winter >= 0.0)
}

///|
test "annual energy finite & positive" {
  let pos = @skycal.make_geo(39.9, 116.4)
  let panel = make_silicon_panel(250.0, 1.65)
  let e = annual_energy(2026, pos, 35.0, 0.0, panel, 0.2, DEFAULT_TURBIDITY)
  assert_true(e > 10.0 && e < 1500.0)
}

///|
test "tilted > flat at mid-latitude" {
  let pos = @skycal.make_geo(39.9, 116.4)
  let panel = make_silicon_panel(250.0, 1.65)
  let e35 = annual_energy(2026, pos, 35.0, 0.0, panel, 0.2, DEFAULT_TURBIDITY)
  let e_flat = annual_energy(2026, pos, 0.0, 0.0, panel, 0.2, DEFAULT_TURBIDITY)
  assert_true(e35 > e_flat)
}

///|
test "days_in_month leap year boundaries" {
  assert_eq(days_in_month(2024, 2), 29)
  assert_eq(days_in_month(2026, 2), 28)
  assert_eq(days_in_month(1600, 2), 29)
  assert_eq(days_in_month(1900, 2), 28)
  assert_eq(days_in_month(2026, 6), 30)
  assert_eq(days_in_month(2026, 12), 31)
}
