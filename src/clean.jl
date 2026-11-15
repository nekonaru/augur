"""
    clean_sales(df; outlier=:winsorize, method=:mad) -> (data, warnings, n_outliers)

Clean a daily sales DataFrame:
1. Drop negative sales (kept as missing, then interpolated).
2. Fill missing calendar days between min and max date.
3. Interpolate missing values linearly (edges use nearest value).
4. Detect outliers with robust statistics and handle them per `outlier`:
   - `:winsorize` (default) clamp to robust bounds
   - `:mark`      keep values, add `:outlier` boolean column
   - `:drop`      set outliers to missing and re-interpolate

`method` is `:mad` (median absolute deviation, default) or `:iqr`.
"""
function detect_outlier_bounds(x::Vector{Float64}; method::Symbol = :mad)
    med = median(x)
    if method == :mad
        mad = median(abs.(x .- med))
        mad == 0 && return (med, med)  # constant series, no outliers
        spread = 3.5 * mad / 0.6745
        return (med - spread, med + spread)
    elseif method == :iqr
        q1, q3 = quantile(x, 0.25), quantile(x, 0.75)
        iqr = q3 - q1
        iqr == 0 && return (med, med)
        return (q1 - 1.5 * iqr, q3 + 1.5 * iqr)
    else
        throw(ArgumentError("method harus :mad atau :iqr, bukan :$method"))
    end
end

function interpolate_missing(y::Vector{Union{Missing, Float64}})
    n = length(y)
    out = Vector{Float64}(undef, n)
    known = findall(!ismissing, y)
    isempty(known) && return fill(0.0, n)
    for i in 1:n
        if !ismissing(y[i])
            out[i] = y[i]
        else
            # nearest known on both sides -> linear interpolation
            left = findlast(k -> k < i, known)
            right = findfirst(k -> k > i, known)
            if left === nothing
                out[i] = y[known[1]]
            elseif right === nothing
                out[i] = y[known[end]]
            else
                l, r = known[left], known[right]
                w = (i - l) / (r - l)
                out[i] = y[l] * (1 - w) + y[r] * w
            end
        end
    end
    return out
end

function clean_sales(df::DataFrame; outlier::Symbol = :winsorize, method::Symbol = :mad)
    outlier in (:winsorize, :mark, :drop) ||
        throw(ArgumentError("outlier harus :winsorize, :mark atau :drop, bukan :$outlier"))

    warnings = String[]
    df = sort(copy(df), :tanggal)

    vals = Vector{Union{Missing, Float64}}(df.penjualan)
    n_neg = count(v -> v !== missing && !ismissing(v) && v < 0, vals)
    n_neg > 0 && push!(warnings, "$n_neg nilai penjualan negatif dianggap hilang.")
    vals = [(v === missing || ismissing(v) || v < 0) ? missing : Float64(v) for v in vals]

    # Fill missing calendar days
    full_range = collect(minimum(df.tanggal):Day(1):maximum(df.tanggal))
    n_gaps = length(full_range) - nrow(df)
    by_date = Dict(df.tanggal[i] => i for i in 1:nrow(df))
    promo_by_date = Dict(df.tanggal[i] => df.promo[i] for i in 1:nrow(df))
    full_vals = Vector{Union{Missing, Float64}}(undef, length(full_range))
    full_promo = zeros(Int, length(full_range))
    for (j, d) in enumerate(full_range)
        i = get(by_date, d, nothing)
        if i === nothing
            full_vals[j] = missing
        else
            full_vals[j] = vals[i]
            full_promo[j] = promo_by_date[d]
        end
    end
    n_missing = count(ismissing, full_vals)
    n_missing > 0 && push!(warnings, "$n_missing hari tanpa data diisi lewat interpolasi.")

    filled = interpolate_missing(full_vals)

    # Outliers
    lo, hi = detect_outlier_bounds(filled; method = method)
    outlier_mask = (filled .< lo) .| (filled .> hi)
    n_out = count(outlier_mask)
    if n_out > 0
        push!(warnings, "$n_out outlier terdeteksi (metode $(uppercase(String(method)))).")
    end
    if outlier == :winsorize && n_out > 0
        filled = clamp.(filled, lo, hi)
        push!(warnings, "Outlier dibatasi ke rentang wajar (winsorize).")
    elseif outlier == :drop && n_out > 0
        tmp = Vector{Union{Missing, Float64}}(filled)
        tmp[outlier_mask] .= missing
        filled = interpolate_missing(tmp)
        push!(warnings, "Outlier dihapus dan diisi lewat interpolasi.")
        outlier_mask = falses(length(filled))
    end

    out = DataFrame(tanggal = full_range, penjualan = filled, promo = full_promo)
    outlier == :mark && (out.outlier = outlier_mask)

    return (data = out, warnings = warnings, n_outliers = n_out)
end

"""
    aggregate_weekly(df) -> DataFrame

Aggregate daily sales to ISO weeks (weeks start on Monday).
Returns `tanggal` (Monday of the week), `penjualan` (sum), `promo` (max).
"""
function aggregate_weekly(df::DataFrame)
    monday(d) = d - Day(mod(dayofweek(d) + 6, 7))
    tmp = DataFrame(tanggal = [monday(d) for d in df.tanggal],
                    penjualan = df.penjualan,
                    promo = df.promo)
    return sort(combine(groupby(tmp, :tanggal),
                        :penjualan => sum => :penjualan,
                        :promo => maximum => :promo), :tanggal)
end

"""
    weekly_pattern(df) -> DataFrame

Average sales per day of week with Indonesian day names,
plus `pct_vs_avg` (percent above/below overall mean).
"""
const WEEKDAY_ID = ["Senin", "Selasa", "Rabu", "Kamis", "Jumat", "Sabtu", "Minggu"]

function weekly_pattern(df::DataFrame)
    avg_all = mean(df.penjualan)
    rows = map(1:7) do dow
        vals = df.penjualan[dayofweek.(df.tanggal) .== dow]
        m = isempty(vals) ? 0.0 : mean(vals)
        (hari = WEEKDAY_ID[dow], rata_rata = m, jumlah = length(vals),
         pct_vs_avg = avg_all == 0 ? 0.0 : (m - avg_all) / avg_all * 100)
    end
    return DataFrame(rows)
end
