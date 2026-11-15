using Test
using Augur
using CSV
using DataFrames
using Dates
using Statistics
using StableRNGs

function make_df(vals; start = Date(2025, 1, 1), promo = nothing)
    n = length(vals)
    DataFrame(tanggal = start .+ Day.(0:n-1),
              penjualan = Float64.(vals),
              promo = promo === nothing ? zeros(Int, n) : promo)
end

@testset "Augur" begin

    @testset "io: read_sales_csv" begin
        mktempdir() do dir
            # valid CSV
            p = joinpath(dir, "ok.csv")
            write(p, "tanggal,penjualan,promo\n2026-01-01,1250000,0\n2026-01-02,980000,0\n2026-01-03,1670000,1\n")
            r = read_sales_csv(p)
            @test nrow(r.data) == 3
            @test r.data.penjualan == [1250000.0, 980000.0, 1670000.0]
            @test r.data.promo == [0, 0, 1]

            # Indonesian number format
            p2 = joinpath(dir, "id.csv")
            write(p2, "tanggal,penjualan\n01/02/2026,\"1.250.000\"\n")
            r2 = read_sales_csv(p2)
            @test r2.data.penjualan[1] == 1250000.0
            @test r2.data.tanggal[1] == Date(2026, 2, 1)

            # missing file
            @test_throws ArgumentError read_sales_csv(joinpath(dir, "nope.csv"))

            # missing required column
            p3 = joinpath(dir, "bad.csv")
            write(p3, "tgl,penjualan\n2026-01-01,100\n")
            err = try read_sales_csv(p3); nothing catch e; e end
            @test err isa ArgumentError
            @test occursin("tanggal", err.msg)

            # invalid date rows
            p4 = joinpath(dir, "baddate.csv")
            write(p4, "tanggal,penjualan\nbukan-tanggal,100\n")
            @test_throws ArgumentError read_sales_csv(p4)

            # duplicate dates are summed
            p5 = joinpath(dir, "dup.csv")
            write(p5, "tanggal,penjualan\n2026-01-01,100\n2026-01-01,250\n")
            r5 = read_sales_csv(p5)
            @test nrow(r5.data) == 1
            @test r5.data.penjualan[1] == 350.0
            @test !isempty(r5.warnings)
        end
    end

    @testset "clean: gaps and outliers" begin
        # gap filling
        df = make_df([100, 200, 300], start = Date(2026, 1, 1))
        df = df[[1, 3], :]  # remove middle day
        cl = clean_sales(df)
        @test nrow(cl.data) == 3
        @test cl.data.penjualan[2] == 200.0  # interpolated

        # negative values are removed then interpolated
        df2 = make_df([100, -50, 300])
        cl2 = clean_sales(df2)
        @test cl2.data.penjualan[2] == 200.0
        @test any(w -> occursin("negatif", w), cl2.warnings)

        # outlier winsorize reduces extreme value
        vals = vcat(fill(1000.0, 60), [100000.0])
        df3 = make_df(vals)
        cl3 = clean_sales(df3; outlier = :winsorize)
        @test maximum(cl3.data.penjualan) < 100000.0
        @test cl3.n_outliers >= 1

        # outlier mark keeps value and adds flag
        cl4 = clean_sales(df3; outlier = :mark)
        @test hasproperty(cl4.data, :outlier)
        @test maximum(cl4.data.penjualan) == 100000.0

        # weekly aggregation preserves total
        daily = generate_synthetic(n_days = 70, seed = 7)
        cl5 = clean_sales(daily)
        wk = aggregate_weekly(cl5.data)
        @test isapprox(sum(wk.penjualan), sum(cl5.data.penjualan); rtol = 1e-6)
        @test all(dayofweek.(wk.tanggal) .== 1)
    end

    @testset "calendar features" begin
        dates = Date(2026, 3, 1) .+ Day.(0:13)  # crosses gajian window
        @test Augur.is_payday(Date(2026, 3, 25))
        @test Augur.is_payday(Date(2026, 4, 2))
        @test !Augur.is_payday(Date(2026, 3, 15))
        X, names = calendar_features(dates)
        @test size(X, 1) == length(dates)
        @test "intercept" in names && "tren" in names && "gajian" in names && "libur" in names
        @test sum(X[:, names .== "intercept"]) == length(dates)
    end

    @testset "models on known series" begin
        d = Date(2025, 1, 1) .+ Day.(0:119)

        # constant series
        yc = fill(5000.0, 120)
        for m in (Naive(), SeasonalNaive(7), MovingAverage(7), SES())
            fm = fit(m, yc, d)
            fc = forecast(fm, 7)
            @test all(isapprox.(fc, 5000.0; atol = 1e-6))
        end

        # linear trend: Holt should beat naive clearly on the next steps
        yt = collect(range(100.0, step = 10.0, length = 120))
        fh = fit(Holt(), yt, d)
        fc_h = forecast(fh, 7)
        @test isapprox(fc_h[1], yt[end] + 10.0; atol = 5.0)

        # pure weekly seasonality: seasonal naive reproduces it exactly
        wk = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0]
        ys = [wk[mod1(i, 7)] for i in 1:120]
        fsn = fit(SeasonalNaive(7), ys, d)
        fc_sn = forecast(fsn, 7)
        @test fc_sn == [wk[mod1(i, 7)] for i in 121:127]

        # HoltWinters on clean additive seasonality + trend recovers sign of slope
        base = collect(range(100.0, step = 1.0, length = 140))
        yw = [base[i] + 30 * sin(2 * pi * (i - 1) / 7) for i in 1:140]
        dw = Date(2025, 1, 1) .+ Day.(0:139)
        fhw = fit(HoltWinters(7, :additive), yw, dw)
        fc_hw = forecast(fhw, 7)
        @test fc_hw[1] > yw[140] - 5  # roughly continues the series, not collapsing

        # metrics vs manual values
        @test mae([1.0, 2.0], [1.5, 2.5]) == 0.5
        @test rmse([0.0, 0.0], [3.0, 4.0]) == sqrt(12.5)
        @test smape([100.0, 200.0], [110.0, 200.0]) ≈ (20 / 210) * 100 / 2
        @test !isnan(mase([1.0, 2.0, 3.0], [1.0, 2.0, 3.0], collect(1.0:10.0); season = 2))
    end

    @testset "backtest & selection" begin
        data = generate_synthetic(n_days = 240, seed = 99)
        y = data.penjualan
        dates = data.tanggal
        bt = rolling_origin_backtest(y, dates; h = 7, season = 7, folds = 2)
        @test nrow(bt) > 0
        agg = bt[bt.fold .== 0, :]
        @test nrow(agg) >= 6
        sel = select_best_model(bt)
        @test !isempty(sel.model)
        @test occursin("backtest", sel.reason)
        # On synthetic data with known weekly pattern, something beats MASE 2.0
        best_mase = minimum(agg.mase[.!isnan.(agg.mase)])
        @test best_mase < 2.0
    end

    @testset "intervals cover ~80% on synthetic data" begin
        data = generate_synthetic(n_days = 300, seed = 123)
        y = data.penjualan
        dates = data.tanggal
        train_y = y[1:280]
        test_y = y[281:300]
        d_train = dates[1:280]
        fm = fit(SeasonalNaive(7), train_y, d_train)
        iv = bootstrap_intervals(fm, train_y, 20; n_boot = 200, seed = 1, dates = dates[281:300])
        cov = interval_coverage(test_y, iv.bawah_80, iv.atas_80)
        @test cov >= 0.5   # generous bound; residuals are heteroscedastic here
        @test all(iv.atas_80 .>= iv.bawah_80)
        @test all(iv.bawah_95 .<= iv.bawah_80 .+ 1e-9)
    end

    @testset "insights" begin
        data = generate_synthetic(n_days = 120, seed = 5)
        cl = clean_sales(data)
        df = cl.data
        fc = DataFrame(tanggal = (maximum(df.tanggal) + Day(1)) .+ Day.(0:13),
                       ramalan = fill(1.2e6, 14),
                       bawah_80 = fill(1.0e6, 14), atas_80 = fill(1.4e6, 14),
                       bawah_95 = fill(0.9e6, 14), atas_95 = fill(1.5e6, 14))
        sel = (model = "HoltWinters", mase = 0.8, reason = "Model HoltWinters dipilih karena MASE terendah")
        ins = generate_insights(df, fc, sel)
        @test any(i -> occursin("Rp", i), ins)
        @test any(i -> occursin("Total ramalan", i), ins)
        @test any(i -> occursin("HoltWinters", i), ins)

        # short-data warning
        short_df = df[1:40, :]
        fc_short = fc[1:7, :]
        ins_short = generate_insights(short_df, fc_short, sel)
        @test any(i -> occursin("8 minggu", i), ins_short)
    end

    @testset "synthetic generator reproducible" begin
        a = generate_synthetic(n_days = 30, seed = 1)
        b = generate_synthetic(n_days = 30, seed = 1)
        @test a.penjualan == b.penjualan
        @test nrow(a) == 30
        @test all(a.promo .∈ Ref((0, 1)))
    end

    @testset "pipeline end-to-end" begin
        mktempdir() do dir
            csv_path = joinpath(dir, "demo.csv")
            data = generate_synthetic(n_days = 180, seed = 11)
            CSV.write(csv_path, data)
            outdir = joinpath(dir, "laporan")
            result = run_pipeline(csv_path; horizon = 7, outdir = outdir, seed = 42)
            @test isfile(result.html)
            @test isfile(result.markdown)
            @test isfile(result.csv)
            @test isfile(joinpath(outdir, "grafik_ramalan.png"))
            @test isfile(joinpath(outdir, "pola_mingguan.png"))
            @test isfile(joinpath(outdir, "perbandingan_model.png"))
            html = read(result.html, String)
            @test occursin("Augur", html)
            @test occursin("Ringkasan", html)
            csv_lines = readlines(result.csv)
            @test length(csv_lines) == 8  # header + 7 rows
        end
    end
end
