"""
OLS regression with calendar features: trend, day-of-week dummies,
payday flag (25th-2nd), holiday flag and optional promo.
Fitted with a small ridge term for numerical stability, falls back to pinv.
"""
mutable struct CalendarRegression <: AbstractForecaster
    holidays::DataFrame
    beta::Vector{Float64}
    names::Vector{String}
    n_train::Int
    fitted::Vector{Float64}
    promo_train::Vector{Float64}
end
CalendarRegression(; holidays = DataFrame(tanggal = Date[], keterangan = String[])) =
    CalendarRegression(holidays, Float64[], String[], 0, Float64[], Float64[])

Base.copy(m::CalendarRegression) = CalendarRegression(m.holidays, copy(m.beta), copy(m.names),
                                                      m.n_train, copy(m.fitted), copy(m.promo_train))

function _fit_ols(X::Matrix{Float64}, y::Vector{Float64})
    XtX = X' * X
    ridge = 1e-8 * I * size(XtX, 1)
    beta = try
        (XtX + ridge) \ (X' * y)
    catch
        pinv(XtX + ridge) * (X' * y)
    end
    return beta
end

function fit(m::CalendarRegression, y::AbstractVector{<:Real}, dates::AbstractVector{Date};
             promo = nothing, kwargs...)
    v = Float64.(y)
    promo_train = promo === nothing ? Float64[] : Float64.(promo)
    X, names = calendar_features(dates; holidays = m.holidays,
                                 promo = isempty(promo_train) ? nothing : promo_train)
    beta = _fit_ols(X, v)
    fitted = X * beta
    return CalendarRegression(m.holidays, beta, names, length(v), fitted, promo_train)
end

function forecast(m::CalendarRegression, h::Int; dates = nothing, promo = nothing, kwargs...)
    dates === nothing && throw(ArgumentError("CalendarRegression membutuhkan `dates` (tanggal masa depan) untuk forecast."))
    n = length(dates)
    promo_vec = promo === nothing ? (isempty(m.promo_train) ? nothing : zeros(Float64, n)) : Float64.(promo)
    X, names = calendar_features(dates; holidays = m.holidays, promo = promo_vec,
                                 trend_offset = m.n_train, trend_scale = max(m.n_train, 1))
    # Align columns with training: same construction, so order matches
    return X * m.beta
end

fitted_values(m::CalendarRegression) = m.fitted
