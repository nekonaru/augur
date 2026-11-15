"""
Indonesian-language insights for non-technical readers.
Templates stay honest: ranges and uncertainty are always mentioned.
"""

const MONTH_ID = ["Januari", "Februari", "Maret", "April", "Mei", "Juni",
                  "Juli", "Agustus", "September", "Oktober", "November", "Desember"]

format_date_id(d::Date) = "$(WEEKDAY_ID[dayofweek(d)]), $(day(d)) $(MONTH_ID[month(d)]) $(year(d))"

function format_rupiah(x::Real)
    v = round(Int, x)
    s = string(abs(v))
    parts = String[]
    while length(s) > 3
        pushfirst!(parts, s[end-2:end])
        s = s[1:end-3]
    end
    pushfirst!(parts, s)
    sign = v < 0 ? "-" : ""
    return "Rp " * sign * join(parts, ".")
end

function format_pct(x::Real; digits::Int = 1)
    return string(round(x; digits = digits)) * "%"
end

"""
    generate_insights(df, forecast_df, selection, backtest_agg) -> Vector{String}

`df` is the cleaned history (tanggal, penjualan), `forecast_df` has columns
`tanggal`, `ramalan`, `bawah_80`, `atas_80`, `bawah_95`, `atas_95`.
"""
function generate_insights(df::DataFrame, forecast_df::DataFrame, selection,
                           backtest_agg::DataFrame = DataFrame())
    out = String[]
    n_hist = nrow(df)
    total = sum(forecast_df.ramalan)
    avg = mean(forecast_df.ramalan)
    h = nrow(forecast_df)

    push!(out, "Total ramalan $h hari ke depan: $(format_rupiah(total)) (rata-rata $(format_rupiah(avg)) per hari).")

    # vs previous period of equal length
    if n_hist >= h
        prev = sum(df.penjualan[(n_hist - h + 1):n_hist])
        if prev > 0
            delta = (total - prev) / prev * 100
            arah = delta > 2 ? "naik" : delta < -2 ? "turun" : "kurang lebih stabil"
            push!(out, "Dibanding $h hari terakhir, penjualan diperkirakan $arah $(format_pct(abs(delta))).")
        end
    end

    # Peak and quiet day
    i_max = argmax(forecast_df.ramalan)
    i_min = argmin(forecast_df.ramalan)
    push!(out, "Hari tersibuk diperkirakan $(format_date_id(forecast_df.tanggal[i_max])) dengan $(format_rupiah(forecast_df.ramalan[i_max])), paling sepi $(format_date_id(forecast_df.tanggal[i_min])) dengan $(format_rupiah(forecast_df.ramalan[i_min])).")

    # Weekly pattern from history
    pat = weekly_pattern(df)
    i_hi = argmax(pat.rata_rata)
    i_lo = argmin(pat.rata_rata)
    avg_all = mean(df.penjualan)
    if avg_all > 0 && nrow(df) >= 28
        hi_pct = (pat.rata_rata[i_hi] - avg_all) / avg_all * 100
        lo_pct = (pat.rata_rata[i_lo] - avg_all) / avg_all * 100
        push!(out, "Dalam data historis, $(pat.hari[i_hi]) rata-rata paling ramai (+$(format_pct(hi_pct)) dari rata-rata) dan $(pat.hari[i_lo]) paling sepi ($(format_pct(lo_pct))).")
    end

    # Uncertainty framing
    avg_width_80 = mean(forecast_df.atas_80 .- forecast_df.bawah_80)
    push!(out, "Rentang ketidakpastian rata-rata 80% sekitar $(format_rupiah(avg_width_80)) per hari; semakin jauh ke depan, semakin lebar rentangnya.")

    # Model selection
    push!(out, selection.reason)

    # Short data warning
    if n_hist < 56
        push!(out, "Peringatan: data kurang dari 8 minggu, ramalan kurang stabil. Gunakan sebagai gambaran kasar, bukan angka pasti.")
    end

    return out
end
