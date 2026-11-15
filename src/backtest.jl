"""
Rolling-origin backtesting and automatic model selection.
"""

"""Default model set, in a stable order."""
function default_models(; season::Int = 7)
    return AbstractForecaster[
        Naive(),
        SeasonalNaive(season),
        MovingAverage(season),
        SES(),
        Holt(),
        HoltWinters(season, :additive),
        HoltWinters(season, :multiplicative),
    ]
end

function _metrics(actual, forecast_vals, y_train; season)
    return (mae = mae(actual, forecast_vals),
            rmse = rmse(actual, forecast_vals),
            smape = smape(actual, forecast_vals),
            mase = mase(actual, forecast_vals, y_train; season = season))
end

"""
    rolling_origin_backtest(y, dates; h=14, season=7, folds=4, models=nothing,
                            promo=nothing, holidays=DataFrame()) -> DataFrame

Rolling-origin evaluation: for each fold, train on all data before the fold,
forecast `h` steps, score against the actuals. Returns one row per
(model, fold) plus one row per model with `fold == 0` holding the mean.
"""
function rolling_origin_backtest(y::AbstractVector{<:Real}, dates::AbstractVector{Date};
                                 h::Int = 14, season::Int = 7, folds::Int = 4,
                                 models::Union{Nothing, Vector{<:AbstractForecaster}} = nothing,
                                 promo::Union{Nothing, AbstractVector} = nothing,
                                 holidays::DataFrame = load_holidays())
    v = Float64.(y)
    n = length(v)
    min_train = max(2 * season, 28)
    available = (n - min_train) ÷ h
    if available < 1
        throw(ArgumentError("Data terlalu pendek untuk backtest ($n titik, butuh minimal $(min_train + h))."))
    end
    folds = min(folds, available)

    if models === nothing
        models = default_models(season = season)
        reg = CalendarRegression(holidays = holidays)
        push!(models, reg)
    end

    rows = NamedTuple[]
    for i in 1:folds
        cut = n - (folds - i + 1) * h
        y_train = v[1:cut]
        d_train = dates[1:cut]
        actual = v[(cut + 1):(cut + h)]
        d_test = dates[(cut + 1):(cut + h)]
        promo_train = promo === nothing ? nothing : promo[1:cut]
        promo_test = promo === nothing ? nothing : promo[(cut + 1):(cut + h)]

        for m in models
            name = model_name(m)
            stats = try
                fitted_m = fit(m, y_train, d_train; promo = promo_train, holidays = holidays)
                fc = forecast(fitted_m, h; dates = d_test, promo = promo_test)
                _metrics(actual, fc, y_train; season = season)
            catch e
                (mae = NaN, rmse = NaN, smape = NaN, mase = NaN, error = sprint(showerror, e))
            end
            err = haskey(stats, :error) ? stats.error : ""
            push!(rows, (model = name, fold = i, mae = stats.mae, rmse = stats.rmse,
                         smape = stats.smape, mase = stats.mase, error = err))
        end
    end

    per_fold = DataFrame(rows)

    # Aggregate rows (fold == 0)
    _nanmean(x) = (xs = filter(!isnan, x); isempty(xs) ? NaN : mean(xs))
    agg = combine(groupby(per_fold, :model),
                  :mae => (x -> _nanmean(x)) => :mae,
                  :rmse => (x -> _nanmean(x)) => :rmse,
                  :smape => (x -> _nanmean(x)) => :smape,
                  :mase => (x -> _nanmean(x)) => :mase,
                  :error => (x -> join(unique(filter(!isempty, x)), "; ")) => :error)
    agg.fold = zeros(Int, nrow(agg))
    agg = agg[:, [:model, :fold, :mae, :rmse, :smape, :mase, :error]]

    return vcat(per_fold, agg)
end

"""
    select_best_model(backtest_df) -> (model, mase, reason)

Select the model with the lowest aggregated MASE (fold == 0 rows). Ties broken by RMSE.
Produces an Indonesian explanation string.
"""
function select_best_model(backtest_df::DataFrame)
    agg = backtest_df[backtest_df.fold .== 0, :]
    valid = agg[.!isnan.(agg.mase), :]
    isempty(valid) && return (model = "SeasonalNaive", mase = NaN,
                              reason = "Tidak ada model yang berhasil diuji; memakai Seasonal Naive sebagai fallback.")
    sort!(valid, [:mase, :rmse])
    best = valid[1, :]
    sn = agg[agg.model .== "SeasonalNaive", :]
    sn_mase = isempty(sn) ? NaN : sn.mase[1]
    better_txt = if isnan(sn_mase)
        "Seasonal Naive tidak tersedia sebagai pembanding."
    elseif best.model == "SeasonalNaive"
        "setara dengan baseline Seasonal Naive (MASE $(round(sn_mase, digits = 2)))."
    elseif best.mase < sn_mase
        "lebih baik dari baseline Seasonal Naive (MASE $(round(best.mase, digits = 2)) vs $(round(sn_mase, digits = 2)))."
    else
        "lebih buruk dari baseline Seasonal Naive (MASE $(round(best.mase, digits = 2)) vs $(round(sn_mase, digits = 2))), dipilih karena tetap yang terbaik di antara kandidat."
    end
    reason = "Model $(best.model) dipilih karena rata-rata MASE terendah pada backtest ($(round(best.mase, digits = 2))), $better_txt"
    return (model = best.model, mase = best.mase, reason = reason)
end
