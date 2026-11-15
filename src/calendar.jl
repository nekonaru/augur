"""
    default_holidays_path() -> String

Path to the bundled Indonesian national holiday list (`data/libur_nasional.csv`).
"""
function default_holidays_path()
    p = joinpath(pkgdir(Augur), "data", "libur_nasional.csv")
    isfile(p) && return p
    p2 = joinpath(@__DIR__, "..", "data", "libur_nasional.csv")
    return p2
end

"""
    load_holidays(path=default_holidays_path()) -> DataFrame

Read `tanggal,keterangan` holiday CSV. Missing file returns an empty holiday
table (with a warning printed by the caller if desired).
Columns: `tanggal::Date`, `keterangan::String`.
"""
function load_holidays(path::AbstractString = default_holidays_path())
    isfile(path) || return DataFrame(tanggal = Date[], keterangan = String[])
    raw = CSV.read(path, DataFrame)
    names_lower = Dict(Symbol(lowercase(String(n))) => n for n in names(raw))
    haskey(names_lower, :tanggal) || return DataFrame(tanggal = Date[], keterangan = String[])
    tc = names_lower[:tanggal]
    kc = get(names_lower, :keterangan, nothing)
    dates = [parse_date_value(v) for v in raw[:, tc]]
    keep = findall(d -> d !== missing, dates)
    keterangan = kc === nothing ? fill("", length(keep)) : String.(raw[keep, kc])
    return DataFrame(tanggal = Date[dates[i] for i in keep], keterangan = keterangan)
end

"""
    is_payday(d::Date) -> Bool

Indonesian payday effect: sales typically rise around the 25th through the 2nd
(gajian period for most salaried workers).
"""
is_payday(d::Date) = day(d) >= 25 || day(d) <= 2

"""
    calendar_features(dates; holidays, promo) -> (X, names)

Feature matrix for the calendar regression model:
intercept, linear trend (scaled), 6 day-of-week dummies (reference: Senin),
payday flag, holiday flag, promo (only when `promo` is given).
"""
function calendar_features(dates::AbstractVector{Date};
                           holidays::DataFrame = DataFrame(tanggal = Date[], keterangan = String[]),
                           promo::Union{Nothing, AbstractVector} = nothing,
                           trend_offset::Int = 0,
                           trend_scale::Union{Nothing, Int} = nothing)
    n = length(dates)
    trend_scale = trend_scale === nothing ? max(trend_offset + n, 1) : trend_scale
    holiday_set = Set(holidays.tanggal)
    cols = Matrix{Float64}(undef, n, 0)
    names_ = String[]

    push!(names_, "intercept"); cols = hcat(cols, ones(n))

    trend = ((trend_offset + 1):(trend_offset + n)) ./ trend_scale
    push!(names_, "tren"); cols = hcat(cols, collect(Float64, trend))

    # Day-of-week dummies; Senin (dayofweek==1) is the reference level
    for dow in 2:7
        push!(names_, "hari_$(lowercase(WEEKDAY_ID[dow]))")
        cols = hcat(cols, Float64.(dayofweek.(dates) .== dow))
    end

    push!(names_, "gajian"); cols = hcat(cols, Float64.(is_payday.(dates)))
    push!(names_, "libur");  cols = hcat(cols, Float64.(in.(dates, Ref(holiday_set))))

    if promo !== nothing
        push!(names_, "promo")
        cols = hcat(cols, Float64.(promo))
    end

    return cols, names_
end
