"""
Common interface for all forecasters.

Each model is a mutable struct. `fit(model, y, dates; kwargs...)` returns a
fitted copy of the model storing its state; `forecast(fitted, h; dates, promo)`
returns `h` point forecasts; `fitted_values(fitted)` returns one-step-ahead
in-sample fitted values (used by backtesting and residual bootstrap).
"""
abstract type AbstractForecaster end

function forecast(m::AbstractForecaster, h::Int; dates = nothing, promo = nothing)
    throw(ArgumentError("forecast belum diimplementasikan untuk $(typeof(m))"))
end

function fitted_values(m::AbstractForecaster)::Vector{Float64}
    throw(ArgumentError("fitted_values belum diimplementasikan untuk $(typeof(m))"))
end

model_name(::Type{T}) where {T <: AbstractForecaster} = String(nameof(T))
model_name(m::AbstractForecaster) = model_name(typeof(m))

"""Metrics used for model comparison."""
mae(actual, forecast)  = mean(abs.(actual .- forecast))
rmse(actual, forecast) = sqrt(mean((actual .- forecast) .^ 2))

function smape(actual, forecast)
    denom = abs.(actual) .+ abs.(forecast)
    return mean([d == 0 ? 0.0 : 2 * abs(a - f) / d for (a, f, d) in zip(actual, forecast, denom)]) * 100
end

"""MASE: MAE scaled by the in-sample MAE of a seasonal naive walk on the training set."""
function mase(actual, forecast, y_train; season::Int = 7)
    n = length(y_train)
    if n <= season
        return NaN
    end
    naive_mae = mean(abs.(y_train[(season + 1):n] .- y_train[1:(n - season)]))
    naive_mae == 0 && return NaN
    return mae(actual, forecast) / naive_mae
end
