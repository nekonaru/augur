"""
    read_sales_csv(path; datecol, valuecol, promocol) -> (data, warnings)

Read a sales CSV into a normalized DataFrame with columns
`tanggal::Date`, `penjualan::Float64`, `promo::Int`.

Required columns (default names): `tanggal`, `penjualan`.
Optional columns: `promo` (0/1, default 0), `produk` (kept if present).

Accepted date formats: ISO (yyyy-mm-dd), dd/mm/yyyy, dd-mm-yyyy, yyyy/mm/dd.
Numbers accept Indonesian thousands separators ("1.250.000") and decimal commas.
Duplicate dates are summed. All problems are reported as Indonesian warnings.
"""
function parse_number(s)
    s = strip(string(s))
    isempty(s) && return missing
    s = replace(s, r"(?i)rp\.?\s*" => "")
    s = replace(s, " " => "")
    has_dot = occursin(".", s)
    has_comma = occursin(",", s)
    if has_dot && has_comma
        # Assume '.' thousands and ',' decimal (Indonesian convention)
        s = replace(s, "." => "")
        s = replace(s, "," => ".")
    elseif has_comma
        if occursin(r",[0-9]{1,2}$", s) && count(==(','), s) == 1
            s = replace(s, "," => ".")
        else
            s = replace(s, "," => "")
        end
    elseif has_dot && count(==('.'), s) > 1
        s = replace(s, "." => "")
    end
    v = tryparse(Float64, s)
    return v === nothing ? missing : v
end

function parse_date_value(s)
    s = strip(string(s))
    isempty(s) && return missing
    for fmt in (dateformat"yyyy-mm-dd", dateformat"yyyy/mm/dd",
                dateformat"dd/mm/yyyy", dateformat"dd-mm-yyyy",
                dateformat"dd.mm.yyyy", dateformat"d/m/yyyy")
        d = try
            Date(s, fmt)
        catch
            nothing
        end
        d isa Date && return d
    end
    # Last resort: Julia's default parser (ISO)
    d = try
        Date(s)
    catch
        nothing
    end
    return d isa Date ? d : missing
end

function read_sales_csv(path::AbstractString;
                        datecol::Symbol = :tanggal,
                        valuecol::Symbol = :penjualan,
                        promocol::Symbol = :promo)
    isfile(path) || throw(ArgumentError("File tidak ditemukan: $path"))
    warnings = String[]

    raw = try
        CSV.read(path, DataFrame; missingstring = ["", "NA", "NaN", "null", "-"])
    catch e
        throw(ArgumentError("Gagal membaca CSV $path: $(sprint(showerror, e))"))
    end

    names_lower = Dict(Symbol(lowercase(String(n))) => n for n in names(raw))
    resolve(sym) = get(names_lower, Symbol(lowercase(String(sym))), nothing)

    date_src = resolve(datecol)
    value_src = resolve(valuecol)
    promo_src = resolve(promocol)

    problems = String[]
    date_src === nothing && push!(problems, "kolom wajib '$datecol' tidak ditemukan (kolom ada: $(join(names(raw), ", ")))")
    value_src === nothing && push!(problems, "kolom wajib '$valuecol' tidak ditemukan (kolom ada: $(join(names(raw), ", ")))")
    isempty(problems) || throw(ArgumentError("CSV tidak valid:\n- " * join(problems, "\n- ")))

    n = nrow(raw)
    tanggal = Vector{Union{Missing, Date}}(undef, n)
    penjualan = Vector{Union{Missing, Float64}}(undef, n)
    promo = zeros(Int, n)
    bad_date_rows = Int[]
    bad_value_rows = Int[]

    for i in 1:n
        tanggal[i] = parse_date_value(raw[i, date_src])
        tanggal[i] === missing && push!(bad_date_rows, i)

        v = raw[i, value_src]
        penjualan[i] = v isa Real ? Float64(v) : parse_number(v)
        (penjualan[i] === missing || ismissing(penjualan[i])) && push!(bad_value_rows, i)

        if promo_src !== nothing
            p = raw[i, promo_src]
            pv = p isa Real ? Float64(p) : parse_number(p)
            promo[i] = (pv === missing || ismissing(pv) || pv == 0) ? 0 : 1
        end
    end

    if !isempty(bad_date_rows)
        throw(ArgumentError("Tanggal tidak valid pada $(length(bad_date_rows)) baris (misal baris $(bad_date_rows[1]): '$(raw[bad_date_rows[1], date_src])'). Gunakan format yyyy-mm-dd atau dd/mm/yyyy."))
    end
    if length(bad_value_rows) == n
        throw(ArgumentError("Kolom '$valuecol' tidak berisi angka yang bisa dibaca. Contoh nilai: '$(raw[1, value_src])'."))
    elseif !isempty(bad_value_rows)
        push!(warnings, "$(length(bad_value_rows)) baris dengan nilai '$valuecol' tidak valid diabaikan.")
    end

    keep = [i for i in 1:n if penjualan[i] !== missing && !ismissing(penjualan[i])]
    df = DataFrame(tanggal = Date[tanggal[i] for i in keep],
                   penjualan = Float64[penjualan[i] for i in keep],
                   promo = promo[keep])

    # Duplicate dates: sum sales, promo = 1 if any row had promo
    if length(unique(df.tanggal)) != nrow(df)
        grouped = combine(groupby(df, :tanggal),
                          :penjualan => sum => :penjualan,
                          :promo => maximum => :promo)
        push!(warnings, "Tanggal duplikat dijumlahkan ($(nrow(df) - nrow(grouped)) baris digabung).")
        df = sort(grouped, :tanggal)
    else
        df = sort(df, :tanggal)
    end

    isempty(df) && throw(ArgumentError("Tidak ada baris data yang valid di $path."))
    return (data = df, warnings = warnings)
end
