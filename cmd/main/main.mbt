///|
// CLI demo for solar-sim. Shows annual PV yield for a given location
// and panel. Run with `moon run cmd/main`.
fn main {
  let lat = 39.9
  let lon = 116.4
  let tilt = 35.0
  let az = 0.0
  let year = 2026
  let albedo = 0.2
  let turb = @sim.DEFAULT_TURBIDITY

  let pos = @skycal.make_geo(lat, lon)
  let panel = @sim.make_silicon_panel(250.0, 1.65)
  let yearly = @sim.annual_energy(year, pos, tilt, az, panel, albedo, turb)
  let cf = @sim.capacity_factor(year, pos, tilt, az, panel, albedo, turb)
  let (best_tilt, best_kwh) = @sim.best_tilt(year, pos, az, panel, albedo, turb)
  let daylight = @sim.annual_daylight_hours(year, pos, turb)

  println("=== Solar PV Report ===")
  println("Beijing, China (39.9N 116.4E)")
  println("250W silicon panel, 35deg tilt south")
  println("---")
  println("Annual yield (kWh)")
  println(yearly)
  println("Capacity factor (%)")
  println(cf * 100.0)
  println("Daylight hours / year")
  println(daylight)
  println("Best tilt (deg)")
  println(best_tilt)
  println("Best tilt annual (kWh)")
  println(best_kwh)

  let e_flat = @sim.annual_energy(year, pos, 0.0, az, panel, albedo, turb)
  let e30 = @sim.annual_energy(year, pos, 30.0, az, panel, albedo, turb)
  let e35 = @sim.annual_energy(year, pos, 35.0, az, panel, albedo, turb)
  let e40 = @sim.annual_energy(year, pos, 40.0, az, panel, albedo, turb)
  println("---")
  println("Tilt comparison (kWh): flat / 30 / 35 / 40")
  println(e_flat)
  println(e30)
  println(e35)
  println(e40)

  let panel_cdte = @sim.make_cdte_panel(250.0, 1.65)
  let e_cdte = @sim.annual_energy(year, pos, tilt, az, panel_cdte, albedo, turb)
  let panel_cigs = @sim.make_cigs_panel(250.0, 1.65)
  let e_cigs = @sim.annual_energy(year, pos, tilt, az, panel_cigs, albedo, turb)
  println("---")
  println("Panel type comparison (kWh): silicon / CdTe / CIGS")
  println(yearly)
  println(e_cdte)
  println(e_cigs)
}
