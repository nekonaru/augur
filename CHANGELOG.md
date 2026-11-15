# Changelog

## v0.1.1

Bug fix release for the command-line entry point.

## Bug fixes

- **CLI startup.** `scripts/ramal.jl` crashed on launch with "cannot document the following expression"; it now runs cleanly from a fresh clone.
- **Report numbers.** Metrics tables use Indonesian thousands separators instead of scientific notation.

## v0.1.0

First public release of Augur, a local-first forecasting tool for UMKM sales data.

## New features

- **CSV pipeline.** Read, clean and model daily or weekly sales history from a single CSV file with Indonesian date and number formats.
- **Model library.** Naive, Seasonal Naive, Moving Average, SES, Holt, Holt-Winters additive and multiplicative, and a calendar-regression OLS with payday and holiday effects.
- **Honest backtesting.** Rolling-origin backtest selects the best model by MASE (ties by RMSE) and reports MAE, RMSE, sMAPE and MASE per fold.
- **Bootstrap intervals.** Every forecast comes with 80% and 95% uncertainty intervals, reproducible via seeded bootstrap.
- **Reports.** Self-contained HTML report with embedded charts, Markdown report, forecast CSV, and PNG charts for history, weekly pattern and model comparison.
- **CLI.** One command turns a CSV into a full report: `julia --project=. scripts/ramal.jl data.csv --horizon 14 --out laporan/`.
- **Synthetic demo.** Bundled example dataset and generator with trend, weekly seasonality, Lebaran surge and promo days.

## Improvements

- **Precompile workload.** Hot paths are precompiled, so cold starts drop to seconds instead of minutes.
- **Outlier handling.** MAD (default) or IQR detection with winsorize, mark or drop strategies, all reported in the final warnings.

## Bug fixes

- **Calendar regression.** Fixed missing `LinearAlgebra` import that made OLS fail inside backtests.
- **Makie plots.** Fixed date x-axis handling in charts; y-axes now use readable juta rupiah units.
