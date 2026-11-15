"""Simple exponential smoothing (SES), alpha fitted by grid search."""
mutable struct SES <: AbstractForecaster
    alpha::Float64
    level::Float64
    fitted::Vector{Float64}
end
SES() = SES(0.3, 0.0, Float64[])

Base.copy(m::SES) = SES(m.alpha, m.level, copy(m.fitted))

function _ses_path(v, alpha)
    level = v[1]
    fitted = Vector{Float64}(undef, length(v))
    fitted[1] = level
    for t in 2:length(v)
        fitted[t] = level
        level = alpha * v[t] + (1 - alpha) * level
    end
    return level, fitted
end

function fit(m::SES, y::AbstractVector{<:Real}, dates::AbstractVector{Date}; alpha = nothing, kwargs...)
    v = Float64.(y)
    if alpha === nothing
        best = (sse = Inf, alpha = 0.3)
        for a in 0.05:0.05:0.95
            level, fitted = _ses_path(v, a)
            sse = sum((v .- fitted) .^ 2)
            if sse < best.sse
                best = (sse = sse, alpha = a)
            end
        end
        alpha = best.alpha
    end
    level, fitted = _ses_path(v, alpha)
    return SES(alpha, level, fitted)
end

forecast(m::SES, h::Int; kwargs...) = fill(m.level, h)
fitted_values(m::SES) = m.fitted

"""Holt's linear trend method, alpha and beta fitted by grid search."""
mutable struct Holt <: AbstractForecaster
    alpha::Float64
    beta::Float64
    level::Float64
    trend::Float64
    fitted::Vector{Float64}
end
Holt() = Holt(0.3, 0.1, 0.0, 0.0, Float64[])

Base.copy(m::Holt) = Holt(m.alpha, m.beta, m.level, m.trend, copy(m.fitted))

function _holt_path(v, alpha, beta)
    level = v[1]
    trend = length(v) >= 2 ? v[2] - v[1] : 0.0
    fitted = Vector{Float64}(undef, length(v))
    fitted[1] = level
    for t in 2:length(v)
        fitted[t] = level + trend
        prev_level = level
        level = alpha * v[t] + (1 - alpha) * (level + trend)
        trend = beta * (level - prev_level) + (1 - beta) * trend
    end
    return level, trend, fitted
end

function fit(m::Holt, y::AbstractVector{<:Real}, dates::AbstractVector{Date};
             alpha = nothing, beta = nothing, kwargs...)
    v = Float64.(y)
    if alpha === nothing || beta === nothing
        best = (sse = Inf, alpha = 0.3, beta = 0.1)
        for a in 0.1:0.2:0.9, b in 0.1:0.2:0.9
            _, _, fitted = _holt_path(v, a, b)
            sse = sum((v .- fitted) .^ 2)
            if sse < best.sse
                best = (sse = sse, alpha = a, beta = b)
            end
        end
        alpha = alpha === nothing ? best.alpha : alpha
        beta  = beta  === nothing ? best.beta  : beta
    end
    level, trend, fitted = _holt_path(v, alpha, beta)
    return Holt(alpha, beta, level, trend, fitted)
end

forecast(m::Holt, h::Int; kwargs...) = [m.level + k * m.trend for k in 1:h]
fitted_values(m::Holt) = m.fitted

"""
Holt-Winters exponential smoothing with additive or multiplicative seasonality,
season length configurable (default 7 for daily data). Parameters fitted by grid search.
"""
mutable struct HoltWinters <: AbstractForecaster
    season::Int
    seasonal::Symbol          # :additive or :multiplicative
    alpha::Float64
    beta::Float64
    gamma::Float64
    level::Float64
    trend::Float64
    seasonal_components::Vector{Float64}
    fitted::Vector{Float64}
end
HoltWinters(season::Int = 7, seasonal::Symbol = :additive) =
    HoltWinters(season, seasonal, 0.3, 0.1, 0.3, 0.0, 0.0, Float64[], Float64[])

Base.copy(m::HoltWinters) = HoltWinters(m.season, m.seasonal, m.alpha, m.beta, m.gamma,
                                         m.level, m.trend, copy(m.seasonal_components), copy(m.fitted))

function _hw_init(v, season, seasonal)
    n = length(v)
    m1 = mean(v[1:season])
    trend = n >= 2 * season ? (mean(v[(season + 1):(2 * season)]) - m1) / season : 0.0
    if seasonal == :additive
        sc = v[1:season] .- m1
    else
        m1 == 0 && (m1 = eps(Float64))
        sc = v[1:season] ./ m1
    end
    return m1, trend, sc
end

function _hw_path(v, season, seasonal, alpha, beta, gamma)
    n = length(v)
    level, trend, sc = _hw_init(v, season, seasonal)
    sc = copy(sc)
    fitted = Vector{Float64}(undef, n)
    for t in 1:n
        s_idx = mod1(t, season)
        if seasonal == :additive
            fitted[t] = level + trend + sc[s_idx]
        else
            fitted[t] = (level + trend) * sc[s_idx]
        end
        prev_level = level
        if seasonal == :additive
            level = alpha * (v[t] - sc[s_idx]) + (1 - alpha) * (level + trend)
            sc[s_idx] = gamma * (v[t] - level) + (1 - gamma) * sc[s_idx]
        else
            level = alpha * (v[t] / max(sc[s_idx], eps(Float64))) + (1 - alpha) * (level + trend)
            sc[s_idx] = gamma * (v[t] / max(level, eps(Float64))) + (1 - gamma) * sc[s_idx]
        end
        trend = beta * (level - prev_level) + (1 - beta) * trend
    end
    return level, trend, sc, fitted
end

function fit(m::HoltWinters, y::AbstractVector{<:Real}, dates::AbstractVector{Date};
             alpha = nothing, beta = nothing, gamma = nothing, kwargs...)
    v = Float64.(y)
    season = m.season
    seasonal = (m.seasonal == :multiplicative && any(<=(0), v)) ? :additive : m.seasonal
    length(v) >= season || throw(ArgumentError("Data terlalu pendek untuk Holt-Winters (butuh minimal $season titik)."))

    if alpha === nothing || beta === nothing || gamma === nothing
        best = (sse = Inf, alpha = 0.3, beta = 0.1, gamma = 0.3)
        for a in 0.1:0.2:0.9, b in 0.1:0.2:0.9, g in 0.1:0.2:0.9
            _, _, _, fitted = _hw_path(v, season, seasonal, a, b, g)
            sse = sum((v .- fitted) .^ 2)
            if isfinite(sse) && sse < best.sse
                best = (sse = sse, alpha = a, beta = b, gamma = g)
            end
        end
        alpha === nothing && (alpha = best.alpha)
        beta  === nothing && (beta  = best.beta)
        gamma === nothing && (gamma = best.gamma)
    end
    level, trend, sc, fitted = _hw_path(v, season, seasonal, alpha, beta, gamma)
    return HoltWinters(season, seasonal, alpha, beta, gamma, level, trend, sc, fitted)
end

function forecast(m::HoltWinters, h::Int; kwargs...)
    n_last = length(m.fitted)
    out = Vector{Float64}(undef, h)
    for k in 1:h
        s_idx = mod1(n_last + k, m.season)
        if m.seasonal == :additive
            out[k] = m.level + k * m.trend + m.seasonal_components[s_idx]
        else
            out[k] = (m.level + k * m.trend) * m.seasonal_components[s_idx]
        end
    end
    return out
end

fitted_values(m::HoltWinters) = m.fitted
model_name(m::HoltWinters) = m.seasonal === :multiplicative ? "HoltWinters-Multi" : "HoltWinters"
