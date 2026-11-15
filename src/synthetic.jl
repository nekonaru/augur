"""
Synthetic daily sales generator with known ground truth:
trend, weekly seasonality, a Lebaran surge window, random promo days, lognormal noise.
Deterministic for a given seed (StableRNGs).
"""
function generate_synthetic(; n_days::Int = 730, seed::Int = 42,
                              start::Date = Date(2024, 6, 1),
                              base::Float64 = 1_000_000.0,
                              daily_trend::Float64 = 350.0,
                              noise::Float64 = 0.12,
                              lebaran_center::Int = 430,
                              lebaran_width::Int = 9,
                              lebaran_peak::Float64 = 1.9,
                              promo_rate::Float64 = 0.08)
    rng = StableRNG(seed)
    weekly = Dict(1 => 0.82, 2 => 0.78, 3 => 0.92, 4 => 1.02,
                  5 => 1.18, 6 => 1.55, 7 => 1.28)  # Senin..Minggu

    dates = start .+ Day.(0:n_days-1)
    rows = Vector{NamedTuple}(undef, n_days)
    promos = rand(rng, n_days) .< promo_rate

    for (i, d) in enumerate(dates)
        trend = base + daily_trend * (i - 1)
        wk = weekly[dayofweek(d)]
        # Lebaran surge: gaussian bump around lebaran_center, with a small post-holiday dip
        z = (i - lebaran_center) / lebaran_width
        lebaran = 1.0 + (lebaran_peak - 1.0) * exp(-0.5 * z^2)
        z_dip = (i - (lebaran_center + lebaran_width + 4)) / (lebaran_width * 0.8)
        lebaran *= 1.0 - 0.25 * exp(-0.5 * z_dip^2)
        promo = promos[i] ? 1.3 : 1.0
        y = trend * wk * lebaran * promo * exp(noise * randn(rng))
        rows[i] = (tanggal = d, penjualan = round(y; digits = 0), promo = promos[i] ? 1 : 0)
    end
    return DataFrame(rows)
end

"""Weekly seasonality multipliers used by the generator (exposed for tests)."""
const SYNTHETIC_WEEKLY = Dict(1 => 0.82, 2 => 0.78, 3 => 0.92, 4 => 1.02,
                              5 => 1.18, 6 => 1.55, 7 => 1.28)
