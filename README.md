<div align="center">
  <img src="assets/augur-mark.png" alt="Augur logo" width="140" />
  <h1>Augur: Forecasting for Small Businesses</h1>
  <p><b>Turn CSV sales data into honest forecasts and plain-language insights<br/>
  for warungs and UMKM. Fully offline, no account.</b></p>

  <a href="https://github.com/nekonaru/augur/releases"><img src="https://img.shields.io/github/v/release/nekonaru/augur?style=flat-square&color=blue" alt="Release" /></a>
  <a href="https://github.com/nekonaru/augur/actions/workflows/ci.yml"><img src="https://github.com/nekonaru/augur/actions/workflows/ci.yml/badge.svg" alt="CI" /></a>
  <img src="https://img.shields.io/badge/julia-1.10%2B-9558B2?style=flat-square&logo=julia&logoColor=white" alt="Julia" />
  <img src="https://img.shields.io/badge/Platform-Linux%20%7C%20macOS%20%7C%20Windows-2f2f2f?style=flat-square" alt="Platform" />
  <img src="https://img.shields.io/badge/License-MIT-green?style=flat-square" alt="License" />
  <img src="https://img.shields.io/badge/Status-Active-brightgreen?style=flat-square" alt="Status" />
</div>

<br />

**English** | [Bahasa Indonesia](README.id.md)

> [!NOTE]
> Augur runs entirely on your machine. Sales data never leaves your computer, and no account or internet connection is needed after installation.

---

## Table of Contents

- [About](#about)
- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Usage](#usage)
- [Data Sources](#data-sources)
- [Project Structure](#project-structure)
- [Development](#development)
- [Testing](#testing)
- [Continuous Integration](#continuous-integration)
- [FAQ](#faq)
- [Author](#author)
- [Disclaimer](#disclaimer)
- [License](#license)

---

## About

**Augur** reads daily or weekly sales history from a CSV file, cleans it, compares several forecasting models on your own data, and produces a 7, 14 or 30 day forecast with uncertainty intervals, charts, and a plain-language Bahasa Indonesia summary. It is built for UMKM owners (warung makan, toko kelontong, kedai kopi, small online shops) and for students who want a transparent, honest example of applied forecasting.

> _"Ramalkan penjualan dengan data, bukan tebakan."_

---

## Features

### Forecasting engine

| Feature | Description |
|---------|-------------|
| **Multiple models** | Naive, Seasonal Naive (7 hari), Moving Average, SES, Holt, Holt-Winters additive and multiplicative, calendar-regression OLS. All implemented from scratch. |
| **Calendar features** | Day-of-week effects, payday flag (25th to 2nd), Indonesian national holidays from a bundled, updatable CSV, and a promo flag. |
| **Automatic model selection** | Rolling-origin backtest picks the best model by MASE (ties by RMSE) and explains the choice in plain language. |
| **Bootstrap intervals** | 80% and 95% prediction intervals from residual bootstrap, reproducible via seeded RNG. |
| **Synthetic demo data** | Built-in generator with trend, weekly seasonality, Lebaran surge, promo days and noise, for trying Augur without your own data. |

### Honest evaluation

| Feature | Description |
|---------|-------------|
| **Rolling-origin backtest** | No model ever sees its own test window; metrics are computed per fold and aggregated. |
| **MASE reporting** | Models are compared against a seasonal naive baseline (MASE below 1.0 beats the baseline). |
| **Uncertainty first** | No single-number forecast is ever shown without a range, and data shorter than 8 weeks raises an explicit warning. |
| **Outlier handling** | Robust z-score (MAD) or IQR detection, with winsorize (default), mark or drop options. |

### Input and output

| Feature | Description |
|---------|-------------|
| **Flexible CSV input** | `tanggal`, `penjualan`, optional `promo` (0/1) and `produk`. ISO and Indonesian date and number formats accepted; duplicates are summed. |
| **Gap filling** | Missing calendar days are filled by linear interpolation; negatives are treated as missing. |
| **Report export** | Self-contained HTML report (charts embedded), Markdown report, forecast CSV, and PNG charts (history + forecast, weekly pattern, model comparison). |
| **Bahasa Indonesia insights** | Total forecast, change vs the previous period, peak and quietest day, weekly pattern, model choice reason, all in plain Indonesian. |

---

## Requirements

| Dependency | Minimum Version | Notes |
|------------|-----------------|-------|
| **Julia** | 1.10 | Pinned environment via `Project.toml` and `Manifest.toml` |
| **Git** | 2.x | For cloning the repository |

> [!TIP]
> No Julia installation yet? The `data/contoh_penjualan.csv` example lets you try the whole pipeline after a one-line install. Building from source is the only way to run the tool.

### Never used a terminal? Start here

<details>
<summary><b>How to open a terminal</b></summary>

1. **Windows**: press `Win + R`, type `powershell`, press Enter. Or search for "Terminal" in the Start menu.
2. **macOS**: press `Cmd + Space`, type `terminal`, press Enter.
3. **Linux**: press `Ctrl + Alt + T` on most desktops.

</details>

---

## Installation

### Option A: Clone and run (recommended)

#### 1. Get the code

<details>
<summary><b>I have Git installed</b></summary>

```bash
git clone https://github.com/nekonaru/augur.git
cd augur
```

</details>

<details>
<summary><b>I don't have Git</b></summary>

Download the ZIP from the green "Code" button on the repository page, extract it, then open a terminal in the extracted folder.

</details>

#### 2. Install dependencies and verify

Install [Julia 1.10 or newer](https://julialang.org/downloads/), make sure `julia` is on your PATH, then run:

```bash
julia --project=. -e "using Pkg; Pkg.instantiate()"
```

> [!IMPORTANT]
> Package download is several hundred MB (CairoMakie). Use a stable connection and let precompilation finish; do not interrupt the first run.

#### 3. Run the example

```bash
julia --project=. scripts/ramal.jl data/contoh_penjualan.csv --horizon 14 --out laporan/
```

Open `laporan/laporan.html` in a browser. That is the full report.

---

## Usage

### First launch

1. Prepare your sales CSV (see format below), or use the bundled example.
2. Run `julia --project=. scripts/ramal.jl yourfile.csv --horizon 14 --out laporan/`.
3. Open `laporan/laporan.html` and read the "Ringkasan untuk Pemilik" section first.
4. Use `ramalan.csv` for import into your own spreadsheet.

### Your CSV format

```csv
tanggal,penjualan,promo
2026-01-01,1250000,0
2026-01-02,980000,0
2026-01-03,1670000,1
```

| Column | Required | Notes |
|--------|----------|-------|
| `tanggal` | yes | `yyyy-mm-dd`, `yyyy/mm/dd`, `dd/mm/yyyy` or `dd-mm-yyyy` |
| `penjualan` | yes | Number; accepts `1.250.000` and `1250000,50` formats; negatives are dropped |
| `promo` | no | `0` or `1`; missing defaults to `0` |
| `produk` | no | Kept as-is; per-product forecasts are not supported yet |

Duplicate dates are summed. The sales unit is whatever you track (rupiah or units); Augur treats the column as a plain number.

### Everyday use

- **Forecast more days**: `--horizon 30` (7 or 14 are the usual choices).
- **Weekly aggregation**: `--granularity mingguan` for shorter, coarser data.
- **Aggressive outlier handling**: change `--outlier mark` or `--outlier drop`.
- **Reproducible runs**: fix `--seed 20250601` (default) so bootstrap intervals repeat exactly.
- **Update holidays**: edit `data/libur_nasional.csv` (format `tanggal,keterangan`); no code change needed.

### Options

| Flag | Default | Meaning |
|------|---------|---------|
| `--horizon N` | `14` | Days ahead to forecast |
| `--out DIR` | `laporan/` | Output directory (created if missing) |
| `--granularity G` | `harian` | `harian` or `mingguan` |
| `--outlier MODE` | `winsorize` | `winsorize`, `mark` or `drop` |
| `--seed N` | `20250601` | Bootstrap seed |

---

## Data Sources

| Purpose | Source |
|---------|--------|
| Indonesian national holidays | SKB 3 Menteri (Hari Libur Nasional dan Cuti Bersama), bundled in `data/libur_nasional.csv` (2025 to 2027) |
| Example sales data | Synthetic, generated by `generate_synthetic` with a fixed seed; not real transactions |

> [!NOTE]
> Update `libur_nasional.csv` every year after the SKB is published. Cuti bersama can be added as extra rows if your shop closes on those days.

---

## Project Structure

```
augur/
  assets/             # logo and icon (SVG)
  data/
    contoh_penjualan.csv   # synthetic example, 365 days
    libur_nasional.csv     # Indonesian holidays 2025-2027
  docs/
    model.md          # modeling decisions and evaluation notes
  scripts/
    ramal.jl          # CLI entry point
  src/
    Augur.jl          # module and exports
    io.jl             # CSV reading and validation
    clean.jl          # gap filling, outliers, weekly aggregation
    calendar.jl       # holiday and payday features
    models/           # naive, seasonal naive, moving average,
                      # SES, Holt, Holt-Winters, calendar regression, ensemble
    backtest.jl       # rolling-origin backtest, metrics, model selection
    intervals.jl      # bootstrap prediction intervals
    insights.jl       # Bahasa Indonesia insight templates
    plots.jl          # CairoMakie charts
    report.jl         # CSV/HTML/Markdown report writers
    pipeline.jl       # end-to-end orchestration
    synthetic.jl      # synthetic data generator
  test/
    runtests.jl       # test suite (67 tests)
  README.md           # English (source)
  README.id.md        # Bahasa Indonesia
```

---

## Development

### Adding a new model

1. Create `src/models/yourmodel.jl` following the `AbstractForecaster` interface in `src/models/common.jl` (`fit`, `forecast`, `fitted_values`).
2. Include it in `src/Augur.jl` and export the type.
3. Add it to `default_models` in `src/backtest.jl` and to `_champion_template` in `src/pipeline.jl`.
4. Add tests in `test/runtests.jl` (fit on a known series, beat a baseline on synthetic data).

### Updating the example data

```bash
julia --project=. -e "using Augur, CSV, DataFrames; CSV.write(\"data/contoh_penjualan.csv\", generate_synthetic(n_days = 365, seed = 20260601))"
```

### Releasing

1. Update `version` in `Project.toml` and both changelog files.
2. Tag `vX.Y.Z` after CI is green.
3. Publish the GitHub release from the changelog entry.

> [!WARNING]
> `Manifest.toml` is committed on purpose. Do not delete or regenerate it casually; reproducible environments are part of the design. Generated reports (`laporan/`) and any `SECURITY_*.md` working files must not be committed.

---

## Testing

```bash
julia --project=. -e "using Pkg; Pkg.test()"
```

| Check | Requirement |
|-------|-------------|
| Test suite | 67 tests, all passing |
| CI | Green on push and PR to `main` |
| Analyzer | No linter configured; the test suite is the gate |

---

## Continuous Integration

| Workflow | Purpose |
|----------|---------|
| `ci.yml` | Installs Julia 1.10, instantiates, runs the test suite on push and PR to `main` |

CI runs on every push to the default branch. Tag a release only after CI is green.

---

## FAQ

<details>
<summary><b>Do I need my own sales data to try Augur?</b></summary>

No. The bundled `data/contoh_penjualan.csv` is synthetic and realistic (trend, weekly seasonality, Lebaran surge, promo days). Run one command and you get a full report.

</details>

<details>
<summary><b>My data is shorter than 8 weeks. Can I still use it?</b></summary>

Yes, but Augur will warn you that the forecast is unstable. Treat it as a rough guide, not a number to plan purchases around.

</details>

<details>
<summary><b>Which models does Augur use?</b></summary>

Naive, Seasonal Naive, Moving Average, SES, Holt, Holt-Winters (additive and multiplicative) and a calendar-regression OLS. The best one is picked automatically by MASE on a rolling-origin backtest of your own data. See `docs/model.md`.

</details>

<details>
<summary><b>Does Augur support multiple products?</b></summary>

Not yet. The `produk` column is parsed and kept, but forecasts are produced for the total daily series. Per-product forecasts are planned for v0.2.

</details>

<details>
<summary><b>Are my sales numbers sent anywhere?</b></summary>

No. Augur runs fully offline after packages are installed. There is no telemetry, no account, and no network call during forecasting.

</details>

---

## Author

<div align="center">
  <table>
    <tr>
      <td align="center"><a href="https://github.com/nekonaru"><img src="https://github.com/nekonaru.png?size=100" alt="Nicolas Dwi Dharma" /></a></td>
    </tr>
    <tr>
      <td align="center"><b>Nicolas Dwi Dharma</b><br/><a href="https://github.com/nekonaru">github.com/nekonaru</a></td>
    </tr>
  </table>
</div>

---

## Disclaimer

Augur produces statistical estimates, not guarantees. Real sales also depend on weather, competitors, and local events that no model can see. Use intervals, not point values, when making stocking decisions. The holiday list is based on the SKB 3 Menteri for 2025 to 2027 and must be updated yearly.

---

## License

Distributed under the **MIT License**. See [`LICENSE`](LICENSE) for more information.
