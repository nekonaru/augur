# Model decisions

Augur is honest about uncertainty and prefers simple, explainable models.
This file records why each model exists and how they are compared.

## Candidates

| Model | File | Why it is here |
|---|---|---|
| Naive | `src/models/naive.jl` | Simplest possible baseline. If a fancier model cannot beat this, it is not earning its complexity. |
| Seasonal Naive (7) | `src/models/naive.jl` | Strong baseline for daily UMKM sales with weekly seasonality. Everything is scored against it. |
| Moving Average (7) | `src/models/naive.jl` | Smoothed baseline, robust to noise, weak on seasonality. |
| SES | `src/models/exp_smoothing.jl` | Level-only exponential smoothing. Alpha fitted by grid search (0.05 to 0.95). |
| Holt | `src/models/exp_smoothing.jl` | Level + linear trend. Alpha and beta fitted by grid search. |
| Holt-Winters additive | `src/models/exp_smoothing.jl` | Level + trend + additive seasonality. The classic for weekly retail patterns. |
| Holt-Winters multiplicative | `src/models/exp_smoothing.jl` | Same, multiplicative seasonality, for series where the seasonal swing grows with the level. |
| Calendar Regression (OLS) | `src/models/regression.jl` | Linear model with trend, day-of-week dummies, payday flag (day 25 to 2), holiday flag from `data/libur_nasional.csv` and promo. |
| Ensemble | `src/models/ensemble.jl` | Equal-weight average of fitted members. Available but not in the default backtest set (kept simple and honest). |

## Evaluation

- Rolling-origin backtest with `folds = 3` by default and horizon equal to the
  forecast horizon (`h`). No fold ever trains on data from its own test window.
- Metrics: MAE, RMSE, sMAPE, MASE.
  - MASE denominator is the in-sample MAE of a seasonal naive walk on the training set.
  - A MASE below 1.0 means the model beats the seasonal naive baseline.
- Model selection: lowest aggregated MASE wins; ties broken by RMSE. The
  selection reason is reported in plain language in the report and in the
  `selection.reason` field.

## Intervals

- Bootstrap on in-sample residuals (centered), 300 resamples by default,
  seed via StableRNGs (`seed` is explicit everywhere, default `20250601`).
- 80% and 95% intervals, clipped at zero (sales cannot be negative).
- The additive error assumption is a deliberate simplification; it is
  documented here and in the report footer. Intervals are honest about
  uncertainty but are not calibrated prediction intervals per fold.

## Cleaning before modeling

- Missing calendar days are filled (linear interpolation, edges = nearest).
- Negative sales are treated as missing.
- Outliers detected with robust z-score (MAD, default) or IQR; default
  handling is winsorize (alternatives: mark, drop).
- Warnings about every cleaning action are carried into the final report.

## Why no ARIMA/ETS state-space models as primary candidates

Per the project brief, the basic models are implemented by hand so they stay
readable and testable. State-space libraries can be added later as an optional
comparator without changing the backtest interface (`AbstractForecaster`).

## Known limitations

- Data shorter than 8 weeks triggers an explicit warning; forecasts are unreliable.
- Payday effect modeled as a fixed day-of-month window (25th to 2nd), not salary-cycle detection.
- Holiday effects are binary flags, not event magnitude estimates.
- Multiplicative Holt-Winters falls back to additive when non-positive values exist.
