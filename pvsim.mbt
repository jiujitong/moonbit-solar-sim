///|
// PV panel modeling and energy yield estimation.
//
// Simplified single-diode model at STC (G=1000 W/m², T=25°C). Annual/daily
// totals integrate clear-sky tilted irradiance in 10-minute steps via the
// trapezoidal rule.

///|
pub const ALPHA_TEMP_COEFF : Double = -0.004

///|
pub const STC_TEMPERATURE : Double = 25.0

///|
pub const STC_IRRADIANCE : Double = 1000.0

///|
pub const AMBIENT_TEMP_STC : Double = 25.0

///|
pub const DEFAULT_NOCT : Double = 48.0

///|
pub struct Panel {
  peak_power_w : Double
  isc_stc : Double
  voc_stc : Double
  ff_stc : Double
  area_m2 : Double
  noct : Double
  alpha_temp : Double
}

///|
pub fn Panel::get_peak_power(self : Panel) -> Double { self.peak_power_w }
pub fn Panel::get_isc_stc(self : Panel) -> Double { self.isc_stc }
pub fn Panel::get_voc_stc(self : Panel) -> Double { self.voc_stc }
pub fn Panel::get_ff_stc(self : Panel) -> Double { self.ff_stc }
pub fn Panel::get_area_m2(self : Panel) -> Double { self.area_m2 }
pub fn Panel::get_noct(self : Panel) -> Double { self.noct }

///|
// Build a standard crystalline-silicon panel. Industry-typical Isc/Voc/FF.
pub fn make_silicon_panel(peak_power_w : Double, area_m2 : Double) -> Panel {
  let ff = 0.75
  let voc = 38.0
  let isc = peak_power_w / (voc * ff)
  Panel::{
    peak_power_w,
    isc_stc: isc,
    voc_stc: voc,
    ff_stc: ff,
    area_m2,
    noct: DEFAULT_NOCT,
    alpha_temp: ALPHA_TEMP_COEFF,
  }
}

///|
// Cell temperature from tilted irradiance + ambient temperature (Faiman-like).
pub fn cell_temperature(
  irradiance_whm2 : Double,
  ambient_temp_c : Double,
  noct : Double,
) -> Double {
  ambient_temp_c + irradiance_whm2 * (noct - 20.0) / 800.0
}

///|
// Simplified single-diode output model. Returns (current A, voltage V, power W).
pub fn panel_output(
  panel : Panel,
  irradiance_whm2 : Double,
  cell_temp_c : Double,
) -> (Double, Double, Double) {
  let g = irradiance_whm2.max(0.0)
  if g < 1.0 {
    return (0.0, 0.0, 0.0)
  }
  let t_stc = STC_TEMPERATURE
  let g_stc = STC_IRRADIANCE
  let isc_ratio = g / g_stc
  let t_diff = cell_temp_c - t_stc
  let isc = panel.isc_stc * isc_ratio * (1.0 + 0.0005 * t_diff)
  let voc_ratio_t = 1.0 + panel.alpha_temp * t_diff
  let voc = panel.voc_stc * voc_ratio_t
  let ff = panel.ff_stc * (1.0 + 0.001 * t_diff)
  let power = isc * voc * ff
  let i = power / voc.max(0.1)
  (i.max(0.0), voc.max(0.0), power.max(0.0))
}

///|
// Daily energy yield, kWh, scanning 10-minute clear-sky tilted irradiance.
pub fn daily_energy(
  year : Int32,
  month : Int32,
  day : Int32,
  pos : @skycal.GeoPos,
  tilt_deg : Double,
  panel_az_deg : Double,
  panel : Panel,
) -> Double {
  daily_energy_with_temp(
    year, month, day, pos, tilt_deg, panel_az_deg, panel,
    15.0, 0.2, DEFAULT_TURBIDITY,
  )
}

///|
// Daily energy with caller-supplied ambient temperature, ground albedo and
// atmospheric turbidity (most accurate entry point).
pub fn daily_energy_with_temp(
  year : Int32,
  month : Int32,
  day : Int32,
  pos : @skycal.GeoPos,
  tilt_deg : Double,
  panel_az_deg : Double,
  panel : Panel,
  ambient_temp_c : Double,
  ground_albedo : Double,
  turbidity : Double,
) -> Double {
  let jd_start = @skycal.julian_date(year, month, day, 0, 0, 0)
  let step_hours = 10.0 / 60.0
  let n_steps = 144
  let mut energy_wh = 0.0
  let mut prev_power = 0.0
  for i in 1..<=n_steps {
    let t_h = i.to_double() * step_hours
    let jd = jd_start + t_h / 24.0
    let irr = clear_sky_tilted_irradiance(
      jd, pos, tilt_deg, panel_az_deg, ground_albedo, turbidity,
    )
    let cell_t = cell_temperature(irr, ambient_temp_c, panel.noct)
    let (_, _, power_w) = panel_output(panel, irr, cell_t)
    let dt_h = step_hours
    energy_wh = energy_wh + (prev_power + power_w) / 2.0 * dt_h
    prev_power = power_w
  }
  energy_wh / 1000.0
}

///|
// Monthly energy yield, kWh (clear-sky, constant ambient temp).
pub fn monthly_energy(
  year : Int32,
  month : Int32,
  pos : @skycal.GeoPos,
  tilt_deg : Double,
  panel_az_deg : Double,
  panel : Panel,
  ambient_temp_c : Double,
  ground_albedo : Double,
  turbidity : Double,
) -> Double {
  let mut total = 0.0
  let dim = days_in_month(year, month)
  for d in 1..<=dim {
    total = total + daily_energy_with_temp(
      year, month, d, pos, tilt_deg, panel_az_deg, panel,
      ambient_temp_c, ground_albedo, turbidity,
    )
  }
  total
}

///|
// Annual energy yield, kWh. Scans every calendar day of the given year.
pub fn annual_energy(
  year : Int32,
  pos : @skycal.GeoPos,
  tilt_deg : Double,
  panel_az_deg : Double,
  panel : Panel,
  ground_albedo : Double,
  turbidity : Double,
) -> Double {
  let mut total = 0.0
  for m in 1..<=12 {
    let dim = days_in_month(year, m)
    for d in 1..<=dim {
      total = total + daily_energy_with_temp(
        year, m, d, pos, tilt_deg, panel_az_deg, panel,
        15.0, ground_albedo, turbidity,
      )
    }
  }
  total
}

///|
// Days in a Gregorian month, leap-year aware.
pub fn days_in_month(year : Int32, month : Int32) -> Int32 {
  match month {
    2 =>
      if (year % 4 == 0 && year % 100 != 0) || year % 400 == 0 {
        29
      } else {
        28
      }
    4 | 6 | 9 | 11 => 30
    _ => 31
  }
}
