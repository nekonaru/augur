"""
End-to-end pipeline: CSV -> cleaned series -> backtest -> model selection ->
forecast with bootstrap intervals -> insights -> CSV/PNG/HTML/MD report.
"""
function _champion_template(name::AbstractString, season::Int, holidays::DataFrame)
    name == "Naive" && return Naive()
    name == "SeasonalNaive" && return SeasonalNaive(season)
    name == "MovingAverage" && return MovingAverage(season)
    name == "SES" && return SES()
    name == "Holt" && return Holt()
    name == "HoltWinters" && return HoltWinters(season, :additive)
    name == "HoltWinters-Multi" && return HoltWinters(season, :multiplicative)
    name == "CalendarRegression" && return CalendarRegression(holidays = holidays)
    return SeasonalNaive(season)  # safe fallback
end

function _champion_from_backtest(agg::DataFrame, season::Int, holidays::DataFrame)
    agg0 = agg[agg.fold .== 0 .&& .!isnan.(agg.mase), :]
    isempty(agg0) && return (SeasonalNaive(season), "SeasonalNaive")
    sort!(agg0, [:mase, :rmse])
    best = agg0[1, :]
    return (_champion_template(best.model, season, holidays), best.model)
end

"""
    run_pipeline(csv_path; horizon=14, outdir="laporan", granularity=:daily,
                 seed=42, outlier=:winsorize, write_all=true) -> NamedTuple
"""
function run_pipeline(csv_path::AbstractString; horizon::Int = 14, outdir::AbstractString = "laporan",
                      granularity::Symbol = :daily, seed::Int = 20250601,
                      outlier::Symbol = :winsorize, hist_days::Int = 180)
    mkpath(outdir)
    all_warnings = String[]

    # 1. Read & clean
    rd = read_sales_csv(csv_path)
    append!(all_warnings, rd.warnings)
    cl = clean_sales(rd.data; outlier = outlier)
    append!(all_warnings, cl.warnings)
    df = cl.data

    weekly = granularity == :weekly
    if weekly
        df = aggregate_weekly(df)
    end
    season = weekly ? 4 : 7

    n = nrow(df)
    if n < season * 4
        push!(all_warnings, "Data hanya $n titik; minimal $(season * 4) titik lebih direkomendasikan untuk hasil yang stabil.")
    end

    y = df.penjualan
    dates = df.tanggal
    promo = df.promo

    holidays = load_holidays()
    h = horizon
    future_dates = (maximum(dates) + Day(1)):Day(1):(maximum(dates) + Day(h))
    if weekly
        future_dates = (maximum(dates) + Day(7)):Day(7):(maximum(dates) + Day(7 * h))
    end
    future_dates = collect(future_dates)
    future_promo = fill(0, h)

    # 2. Backtest & selection
    bt = rolling_origin_backtest(y, dates; h = h, season = season, folds = 3,
                                 promo = promo, holidays = holidays)
    agg0 = bt[bt.fold .== 0, :]
    selection = select_best_model(bt)

    # 3. Champion fit + bootstrap intervals
    champion, champion_name = _champion_from_backtest(bt, season, holidays)
    fitted = fit(champion, y, dates; promo = promo, holidays = holidays)
    iv = bootstrap_intervals(fitted, y, h; n_boot = 300, seed = seed,
                             dates = future_dates, promo = future_promo)
    fc = DataFrame(tanggal = future_dates,
                   ramalan = iv.ramalan,
                   bawah_80 = iv.bawah_80, atas_80 = iv.atas_80,
                   bawah_95 = iv.bawah_95, atas_95 = iv.atas_95)

    # 4. Insights
    insights = generate_insights(df, fc, selection, agg0)

    # 5. Outputs
    csv_out = joinpath(outdir, "ramalan.csv")
    write_forecast_csv(fc, csv_out)
    forecast_png = joinpath(outdir, "grafik_ramalan.png")
    pattern_png  = joinpath(outdir, "pola_mingguan.png")
    compare_png  = joinpath(outdir, "perbandingan_model.png")
    plot_forecast(df, fc, forecast_png; hist_days = hist_days)
    plot_weekly_pattern(weekly_pattern(df), pattern_png)
    plot_model_comparison(bt, compare_png; champion = champion_name)

    generated_at = Dates.format(now(), "yyyy-mm-dd HH:MM")
    html_out = joinpath(outdir, "laporan.html")
    md_out   = joinpath(outdir, "laporan.md")
    write_html_report(html_out; csv_name = "ramalan.csv", hist = df, fc = fc,
                      insights = insights, agg = bt, selection = selection,
                      forecast_png = forecast_png, pattern_png = pattern_png,
                      compare_png = compare_png, generated_at = generated_at)
    write_markdown_report(md_out; csv_name = "ramalan.csv", hist = df, fc = fc,
                          insights = insights, agg = bt, selection = selection,
                          forecast_png = forecast_png, pattern_png = pattern_png,
                          compare_png = compare_png, generated_at = generated_at)

    return (outdir = outdir, html = html_out, markdown = md_out, csv = csv_out,
            forecast = fc, insights = insights, selection = selection,
            backtest = bt, warnings = all_warnings)
end
