"""
Bootstrap prediction intervals from in-sample residuals.
Resamples residuals with replacement (StableRNGs, explicit seed) and adds them
to the point forecast. Additive error assumption; intervals are clipped at 0.
"""
function bootstrap_intervals(fitted_model::AbstractForecaster, y::AbstractVector{<:Real}, h::Int;
                             n_boot::Int = 500, seed::Int = 20250601,
                             dates = nothing, promo = nothing)
    v = Float64.(y)
    residuals = v .- fitted_values(fitted_model)
    residuals = residuals .- mean(residuals)  # center
    yhat = forecast(fitted_model, h; dates = dates, promo = promo)

    rng = StableRNG(seed)
    sims = Matrix{Float64}(undef, n_boot, h)
    if all(r -> r == 0, residuals)
        sims .= yhat'
    else
        for i in 1:n_boot
            draws = residuals[rand(rng, 1:length(residuals), h)]
            sims[i, :] = yhat .+ draws
        end
    end

    pct(col, p) = quantile(col, p)
    cols = eachcol(sims)
    lower80 = [pct(c, 0.10) for c in cols]
    upper80 = [pct(c, 0.90) for c in cols]
    lower95 = [pct(c, 0.025) for c in cols]
    upper95 = [pct(c, 0.975) for c in cols]

    return DataFrame(
        ramalan = yhat,
        bawah_80 = max.(0.0, lower80),
        atas_80 = upper80,
        bawah_95 = max.(0.0, lower95),
        atas_95 = upper95,
    )
end

"""
    interval_coverage(y_true, lower, upper) -> Float64

Empirical coverage of a prediction interval (used in tests and diagnostics).
"""
interval_coverage(y_true, lower, upper) = mean((y_true .>= lower) .& (y_true .<= upper))
