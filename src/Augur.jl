module Augur

using CSV
using DataFrames
using Dates
using Statistics
using StatsBase
using Distributions
using StableRNGs
using LinearAlgebra

export read_sales_csv, clean_sales, aggregate_weekly, weekly_pattern, WEEKDAY_ID
export load_holidays, default_holidays_path, calendar_features, is_payday
export AbstractForecaster, fit, forecast, fitted_values, model_name
export Naive, SeasonalNaive, MovingAverage, SES, Holt, HoltWinters, CalendarRegression, Ensemble, fit_ensemble
export mae, rmse, smape, mase, rolling_origin_backtest, select_best_model, default_models
export bootstrap_intervals, interval_coverage
export generate_insights, format_rupiah, format_pct, format_date_id
export generate_synthetic, SYNTHETIC_WEEKLY
export run_pipeline

include("io.jl")
include("clean.jl")
include("calendar.jl")
include("models/common.jl")
include("models/naive.jl")
include("models/exp_smoothing.jl")
include("models/regression.jl")
include("models/ensemble.jl")
include("backtest.jl")
include("intervals.jl")
include("insights.jl")
include("plots.jl")
include("report.jl")
include("synthetic.jl")
include("pipeline.jl")

# Warm up the hot paths (plotting + pipeline) so cold starts are fast.
# Any failure here must not break precompilation.
using PrecompileTools: @compile_workload

@compile_workload begin
    try
        mktempdir() do dir
            csv_path = joinpath(dir, "_precompile_demo.csv")
            demo = generate_synthetic(n_days = 90, seed = 1)
            CSV.write(csv_path, demo)
            run_pipeline(csv_path; horizon = 3, outdir = joinpath(dir, "laporan"), seed = 1)
        end
    catch
        # best effort only; do not fail precompilation
    end
end

end # module Augur
