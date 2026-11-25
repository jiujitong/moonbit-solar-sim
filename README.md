# jiujitong/solar-sim

MoonBit 光伏发电量模拟器。复用 [jiujitong/skycal](https://github.com/jiujitong/moonbit-skycal) 的太阳位置计算，实现从天文辐射到面板输出的完整链路。

## 依赖

```
jiujitong/skycal@0.1.0
moonbitlang/core/math
```

## 核心模型

| 模块 | 函数 | 说明 |
|---|---|---|
| clear_sky.mbt | `airmass_kasten(alt)` | Kasten 大气质量 |
| | `dni_clear_sky(alt, turbidity, jd)` | 法向直射辐照度 W/m² |
| | `ghi_clear_sky(alt, turbidity, jd)` | 全球水平辐照度 W/m² |
| | `solar_incidence_angle(tilt, pan_az, alt, sol_az)` | 倾斜面入射角 |
| | `hay_tilted(ghi, dni, alt, inc, tilt, albedo)` | Hay 天空模型倾斜面分解 |
| | `clear_sky_tilted_irradiance(jd, pos, tilt, az, alb, turb)` | 一站式倾斜面辐射 |
| pvsim.mbt | `make_silicon_panel(power, area)` | 工厂函数（ff=0.75, voc=38V）|
| | `panel_output(panel, irradiance, cell_temp)` | 简化单二极管 → (I,V,P) |
| | `daily_energy(y,m,d, pos, tilt, az, panel)` | 每日 kWh |
| | `annual_energy(y, pos, tilt, az, panel, alb, turb)` | 年累计 kWh |

## 快速开始

```moonbit
import { "jiujitong/skycal" @skycal, "jiujitong/solar-sim" @sim }

fn main {
  let pos = @skycal.make_geo(39.9, 116.4)  // 北京
  let panel = @sim.make_silicon_panel(250.0, 1.65)  // 250W 1.65m²
  let kwh = @sim.annual_energy(2026, pos, 35.0, 0.0, panel, 0.2, sim.DEFAULT_TURBIDITY)
  println("年发电量: \${kwh} kWh")  // ≈ 300-400 kWh (PVWatts 参考)
}
```

## 测试

14 个测试覆盖物理不变量、几何边界和 PVWatts 数值对照：

```
moon test  →  14 passed, 0 failed
```

## 设计说明

入射角公式（标准 PV 行业公式，非简化版）：

```
cos(θ) = cos(β)·sin(δ) + sin(β)·cos(δ)·cos(γ - γ_p)
```

β=tilt, δ=solar altitude, γ=panel azimuth, γ_p=solar azimuth

Hay 天空分解把水平 GHI 拆成 beam + diffuse + ground reflection 三部分，再按倾斜面投影。面板输出用简化单二极管模型（Isc, Voc, FF, 温度系数），cell temperature 用 Faiman-like NOCT 模型。

## 空白领域

mooncakes.io 3960+ 模块扫描：`photovoltaic` / `solar energy` / `pv model` / `irradiance` — **0 匹配**，安全空白。
