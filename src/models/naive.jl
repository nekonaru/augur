"""Inspect the last value and repeat it (Naive)."""
mutable struct Naive <: AbstractForecaster
    last::Float64
    fitted::Vector{Float64}
end
Naive() = Naive(0.0, Float64[])

function Base.copy(m::Naive)
    Naive(m.last, copy(m.fitted))
end

function fit(::Naive, y::AbstractVector{<:Real}, dates::AbstractVector{Date}; kwargs...)
    v = Float64.(y)
    fitted = vcat(v[1], v[1:end-1])
    return Naive(v[end], fitted)
end

forecast(m::Naive, h::Int; kwargs...) = fill(m.last, h)
fitted_values(m::Naive) = m.fitted

"""Repeat the last observed season (Seasonal Naive)."""
mutable struct SeasonalNaive <: AbstractForecaster
    season::Int
    last_season::Vector{Float64}
    fitted::Vector{Float64}
end
SeasonalNaive(season::Int = 7) = SeasonalNaive(season, Float64[], Float64[])

Base.copy(m::SeasonalNaive) = SeasonalNaive(m.season, copy(m.last_season), copy(m.fitted))

function fit(m::SeasonalNaive, y::AbstractVector{<:Real}, dates::AbstractVector{Date}; kwargs...)
    v = Float64.(y)
    s = m.season
    n = length(v)
    n >= s || throw(ArgumentError("Data terlalu pendek untuk Seasonal Naive (butuh minimal $s titik)."))
    fitted = Vector{Float64}(undef, n)
    season_mean = mean(v[1:s])
    for t in 1:n
        fitted[t] = t <= s ? season_mean : v[t - s]
    end
    return SeasonalNaive(s, v[(n - s + 1):n], fitted)
end

function forecast(m::SeasonalNaive, h::Int; kwargs...)
    return [m.last_season[mod1(k, m.season)] for k in 1:h]
end

fitted_values(m::SeasonalNaive) = m.fitted

"""Moving average of the last `window` observations."""
mutable struct MovingAverage <: AbstractForecaster
    window::Int
    avg::Float64
    fitted::Vector{Float64}
end
MovingAverage(window::Int = 7) = MovingAverage(window, 0.0, Float64[])

Base.copy(m::MovingAverage) = MovingAverage(m.window, m.avg, copy(m.fitted))

function fit(m::MovingAverage, y::AbstractVector{<:Real}, dates::AbstractVector{Date}; kwargs...)
    v = Float64.(y)
    w = min(m.window, length(v))
    fitted = Vector{Float64}(undef, length(v))
    for t in 1:length(v)
        if t == 1
            fitted[t] = v[1]
        else
            lo = max(1, t - w)
            fitted[t] = mean(v[lo:(t - 1)])
        end
    end
    return MovingAverage(m.window, mean(v[(end - w + 1):end]), fitted)
end

forecast(m::MovingAverage, h::Int; kwargs...) = fill(m.avg, h)
fitted_values(m::MovingAverage) = m.fitted
