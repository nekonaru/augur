#!/usr/bin/env julia
"""
Augur CLI - ramal penjualan UMKM dari CSV.

Usage:
  julia --project=. scripts/ramal.jl data.csv [--horizon 14] [--out laporan/]
                                              [--granularity harian|mingguan]
                                              [--outlier winsorize|mark|drop]
                                              [--seed 20250601]
"""
using Augur
using Dates

function print_usage()
    println("""
    Augur - ramal penjualan UMKM dari CSV

    Usage:
      julia --project=. scripts/ramal.jl data.csv [opsi]

    Opsi:
      --horizon N            Jumlah hari ke depan (default 14)
      --out DIR              Folder output (default: laporan/)
      --granularity G        harian | mingguan (default: harian)
      --outlier MODE         winsorize | mark | drop (default: winsorize)
      --seed N               Seed bootstrap (default: 20250601)
      --help                 Tampilkan bantuan ini
    """)
end

function parse_args(args)
    opts = Dict{String, String}()
    positional = String[]
    i = 1
    while i <= length(args)
        a = args[i]
        if a == "--help" || a == "-h"
            return nothing
        elseif startswith(a, "--")
            key = a[3:end]
            if i + 1 > length(args)
                error("Opsi $a membutuhkan nilai")
            end
            opts[key] = args[i + 1]
            i += 2
        else
            push!(positional, a)
            i += 1
        end
    end
    isempty(positional) && return nothing
    return (csv = positional[1], opts = opts)
end

function main()
    parsed = try
        parse_args(ARGS)
    catch e
        println("Kesalahan argumen: $(sprint(showerror, e))")
        print_usage()
        exit(2)
    end
    parsed === nothing && (print_usage(); exit(0))

    horizon = parse(Int, get(parsed.opts, "horizon", "14"))
    outdir = get(parsed.opts, "out", "laporan")
    gran = get(parsed.opts, "granularity", "harian") == "mingguan" ? :weekly : :daily
    outlier = Symbol(get(parsed.opts, "outlier", "winsorize"))
    seed = parse(Int, get(parsed.opts, "seed", "20250601"))

    println("Membaca $(parsed.csv)...")
    result = run_pipeline(parsed.csv; horizon = horizon, outdir = outdir,
                          granularity = gran, seed = seed, outlier = outlier)

    println()
    println("Selesai. Laporan tersimpan di: $(result.html)")
    println("  - CSV ramalan : $(result.csv)")
    println("  - Markdown    : $(result.markdown)")
    println("  - Model       : $(result.selection.model) (MASE $(round(result.selection.mase, digits = 2)))")
    if !isempty(result.warnings)
        println()
        println("Catatan dari pembersihan data:")
        for w in result.warnings
            println("  - $w")
        end
    end
    println()
    println("Ringkasan:")
    for insight in result.insights
        println("  - $insight")
    end
end

main()
