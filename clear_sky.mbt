///|
// Clear-sky solar irradiance decomposition and tilted-surface modeling.
//
// Computes beam (DNI), diffuse (DHI) and global (GHI) irradiance for clear
// skies and decomposes them onto a tilted surface using the Hay isotropic
// model for sky diffuse and uniform ground reflection. All values are in W/m².

///|
// Solar constant at 1 AU, W/m². Standard PMOD/WRC value.
pub const SOLAR_CONSTANT : Double = 1367.0

///|
pub const DEFAULT_GROUND_ALBEDO : Double = 0.2

///|
pub const DEFAULT_TURBIDITY : Double = 2.0

///|
pub const SNOW_ALBEDO : Double = 0.6

///|
pub const URBAN_ALBEDO : Double = 0.3

///|
pub const WATER_ALBEDO : Double = 0.1

///|
// Earth-sun distance correction factor. ≈ 1.0 mean, ±3.3% annual variation.
pub fn earth_sun_distance_factor(jd : Double) -> Double {
  let t = @skycal.julian_centuries(jd)
  let m = 357.52911 + 35999.05029 * t - 0.0001537 * t * t
  let e = 0.016708634 - 0.000042037 * t - 0.0000001267 * t * t
  let c = (1.914602 - 0.004817 * t) * @skycal.sin_deg(m) +
    0.019993 * @skycal.sin_deg(2.0 * m)
  let true_long = 280.46646 + 36000.76983 * t + c - 180.0
  let omega = 125.04 - 1934.136 * t
  let _lambda = @skycal.normalize_deg(true_long - 0.00569 - 0.00478 * @skycal.sin_deg(omega))
  let d_au = 1.0 / (1.0 + e * @skycal.cos_deg(m + c))
  1.0 / (d_au * d_au)
}

///|
// Kasten 1966 airmass. h in degrees, sea level.
pub fn airmass_kasten(altitude_deg : Double) -> Double {
  let h = altitude_deg.max(-90.0).min(90.0)
  if h <= -1.0 {
    return 1000000000000000000.0
  }
  let am = 1.0 / (
    @skycal.sin_deg(h) +
    0.50572 * @math.pow(h + (-6.07995), (-1.636))
  )
  am.max(1.0)
}

///|
// Solar incidence angle on a tilted collector. All angles degrees.
pub fn solar_incidence_angle(
  tilt_deg : Double,
  panel_az_deg : Double,
  solar_alt_deg : Double,
  solar_az_deg : Double,
) -> Double {
  let cos_incidence =
    @skycal.cos_deg(tilt_deg) * @skycal.sin_deg(solar_alt_deg) +
      @skycal.sin_deg(tilt_deg) * @skycal.cos_deg(solar_alt_deg) *
      @skycal.cos_deg(solar_az_deg - panel_az_deg)
  let clamped = if cos_incidence < -1.0 { -1.0 } else { if cos_incidence > 1.0 { 1.0 } else { cos_incidence } }
  @skycal.acos_deg(clamped)
}

// Convert skycal azimuth (north=0, clockwise) to south=0 convention.

///|
pub fn az_north0_to_south0(az_north_deg : Double) -> Double {
  @skycal.normalize_deg(az_north_deg + 180.0)
}

///|
// Clear-sky direct normal irradiance (DNI), W/m².
pub fn dni_clear_sky(
  solar_alt_deg : Double,
  turbidity : Double,
  jd : Double,
) -> Double {
  if solar_alt_deg <= 0.0 {
    return 0.0
  }
  let am = airmass_kasten(solar_alt_deg).max(1.0).min(38.0)
  let e_factor = earth_sun_distance_factor(jd)
  let i0 = SOLAR_CONSTANT * e_factor
  let tr = @math.pow(0.72, turbidity * @math.pow(am, 0.65))
  i0 * tr
}

///|
// Clear-sky global horizontal irradiance (GHI), W/m².
pub fn ghi_clear_sky(
  solar_alt_deg : Double,
  turbidity : Double,
  jd : Double,
) -> Double {
  if solar_alt_deg <= 0.0 {
    return 0.0
  }
  let am = airmass_kasten(solar_alt_deg)
  let tr = @math.pow(0.75, turbidity * @math.pow(am, 0.6))
  let beam_horiz = dni_clear_sky(solar_alt_deg, turbidity, jd) * @skycal.sin_deg(solar_alt_deg)
  let clearness = tr
  let diff_frac = if clearness < 0.22 { 1.0 } else { if clearness < 0.8 { 0.9 - clearness } else { 0.1 } }
  beam_horiz / (1.0 - diff_frac)
}

///|
// Hay 1978 isotropic sky model: GHI/DNI decomposition onto tilted surface.
pub fn hay_tilted(
  ghi_whm2 : Double,
  dni_whm2 : Double,
  solar_alt_deg : Double,
  incidence_deg : Double,
  tilt_deg : Double,
  ground_albedo : Double,
) -> Double {
  if solar_alt_deg <= 0.0 {
    return 0.0
  }
  let beam_denom = @skycal.sin_deg(solar_alt_deg)
  let beam_tilt = if beam_denom > 0.01 {
    dni_whm2 * (@skycal.cos_deg(incidence_deg) / beam_denom).max(0.0)
  } else {
    0.0
  }
  let beam_horiz = dni_whm2 * @skycal.sin_deg(solar_alt_deg)
  let diffuse_horiz = (ghi_whm2 - beam_horiz).max(0.0)
  let sky_diff = diffuse_horiz * (1.0 + @skycal.cos_deg(tilt_deg)) / 2.0
  let ground_refl = ghi_whm2 * ground_albedo * (1.0 - @skycal.cos_deg(tilt_deg)) / 2.0
  beam_tilt + sky_diff + ground_refl
}

///|
// One-shot clear-sky tilted irradiance from a skycal Julian Date + GeoPos.
pub fn clear_sky_tilted_irradiance(
  jd : Double,
  pos : @skycal.GeoPos,
  tilt_deg : Double,
  panel_az_deg : Double,
  ground_albedo : Double,
  turbidity : Double,
) -> Double {
  let sp = @skycal.sun_position(jd, pos)
  let alt = sp.get_altitude()
  if alt <= 0.0 {
    return 0.0
  }
  let az_n0 = sp.get_azimuth()
  let az_s0 = az_north0_to_south0(az_n0)
  let inc = solar_incidence_angle(tilt_deg, panel_az_deg, alt, az_s0)
  let ghi = ghi_clear_sky(alt, turbidity, jd)
  let dni = dni_clear_sky(alt, turbidity, jd)
  hay_tilted(ghi, dni, alt, inc, tilt_deg, ground_albedo)
}
