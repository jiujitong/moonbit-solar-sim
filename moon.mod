// Learn more about moon.mod configuration:
// https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html

name = "jiujitong/solar-sim"

version = "0.2.0"

readme = "README.mbt.md"

repository = ""

license = "Apache-2.0"

keywords = ["photovoltaic", "solar", "pv-simulation", "irradiance", "renewable-energy"]

preferred_target = "wasm"

description = "Pure MoonBit solar energy simulation: clear-sky irradiance, PV panel I-V model, daily/annual energy yield"

import {
  "jiujitong/skycal@0.1.0",
}
