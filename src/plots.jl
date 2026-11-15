# CairoMakie plots for the report. Every function saves a PNG and returns its path.
using CairoMakie

# Makie recipes do not all accept Date x-values; plot against day numbers and
# label ticks with real dates instead.
function _date_ticks(dates; max_ticks = 6)
    xs = Float64.(Dates.value.(dates))
    n = length(xs)
    step = max(1, ceil(Int, n / max_ticks))
    idx = 1:step:n
    return (xs, (xs[idx], Dates.format.(dates[idx], "yyyy-mm-dd")))
end

"""History + forecast with 80/95% interval bands."""
rupiah_jt_format(values) = [string(round(v / 1e6; digits = 1)) * " jt" for v in values]

function plot_forecast(hist::DataFrame, fc::DataFrame, path::AbstractString; hist_days::Int = 180)
    hist_tail = last(hist, min(hist_days, nrow(hist)))
    all_dates = vcat(hist_tail.tanggal, fc.tanggal)
    xall, xticks = _date_ticks(all_dates)
    xhist = xall[1:nrow(hist_tail)]
    xfc   = xall[(nrow(hist_tail) + 1):end]

    fig = Figure(size = (960, 540))
    ax = Axis(fig[1, 1], xlabel = "Tanggal", ylabel = "Penjualan (juta rupiah)",
              title = "Histori dan Ramalan Penjualan", xticks = xticks,
              ytickformat = rupiah_jt_format,
              xticklabelrotation = 0.6)
    band!(ax, xfc, fc.bawah_95, fc.atas_95, color = (:steelblue, 0.18), label = "Interval 95%")
    band!(ax, xfc, fc.bawah_80, fc.atas_80, color = (:steelblue, 0.32), label = "Interval 80%")
    lines!(ax, xhist, hist_tail.penjualan, color = :gray25, linewidth = 1.5, label = "Histori")
    lines!(ax, vcat(xhist[end], xfc), vcat(hist_tail.penjualan[end], fc.ramalan),
           color = :steelblue, linewidth = 2.5, linestyle = :dash, label = "Ramalan")
    axislegend(ax; position = :lt, framevisible = false)
    save(path, fig)
    return path
end

"""Bar chart of average sales per day of week."""
function plot_weekly_pattern(pattern::DataFrame, path::AbstractString)
    fig = Figure(size = (960, 420))
    ax = Axis(fig[1, 1], xticks = (1:7, pattern.hari), ylabel = "Rata-rata penjualan (juta rupiah)",
              ytickformat = rupiah_jt_format,
              title = "Pola Mingguan (hari apa yang ramai?)")
    barplot!(ax, 1:7, pattern.rata_rata, color = :steelblue)
    save(path, fig)
    return path
end

"""Bar chart comparing model MASE from backtest (fold == 0)."""
function plot_model_comparison(backtest_agg::DataFrame, path::AbstractString; champion::Union{Nothing, String} = nothing)
    agg = sort(backtest_agg[backtest_agg.fold .== 0, :], :mase)
    agg = agg[.!isnan.(agg.mase), :]
    colors = [champion !== nothing && m == champion ? :seagreen : :gray60 for m in agg.model]
    fig = Figure(size = (960, 420))
    ax = Axis(fig[1, 1], xticks = (1:nrow(agg), agg.model), xticklabelrotation = 0.5,
              ylabel = "MASE (lebih kecil lebih baik)", title = "Perbandingan Model pada Backtest")
    barplot!(ax, 1:nrow(agg), agg.mase, color = colors)
    hlines!(ax, [1.0], color = :firebrick, linestyle = :dash, linewidth = 1.5)
    save(path, fig)
    return path
end
