# Report writers: forecast CSV, Markdown report and self-contained HTML report
# (images embedded as base64 so the file can be shared as-is).
using Base64

"""Write the forecast table CSV."""
function write_forecast_csv(fc::DataFrame, path::AbstractString)
    out = copy(fc)
    out.tanggal = string.(out.tanggal)
    CSV.write(path, out)
    return path
end

_escape_html(s) = replace(replace(replace(string(s), "&" => "&amp;"), "<" => "&lt;"), ">" => "&gt;")

function _metrics_table_html(agg::DataFrame)
    rows = join(map(eachrow(agg)) do r
        err = isempty(r.error) ? "" : " <span class=\"err\">($( _escape_html(r.error)))</span>"
        "<tr><td>$( _escape_html(r.model))$err</td><td>$(_fmt_num(r.mae))</td><td>$(_fmt_num(r.rmse))</td><td>$(_fmt_num(r.smape))</td><td>$(_fmt_num(r.mase))</td></tr>"
    end, "\n")
    return """
    <table>
    <thead><tr><th>Model</th><th>MAE</th><th>RMSE</th><th>sMAPE (%)</th><th>MASE</th></tr></thead>
    <tbody>
    $rows
    </tbody></table>"""
end

function _forecast_table_html(fc::DataFrame)
    rows = join(map(eachrow(fc)) do r
        "<tr><td>$(format_date_id(r.tanggal))</td><td>$(format_rupiah(r.ramalan))</td><td>$(format_rupiah(r.bawah_80)) - $(format_rupiah(r.atas_80))</td><td>$(format_rupiah(r.bawah_95)) - $(format_rupiah(r.atas_95))</td></tr>"
    end, "\n")
    return """
    <table>
    <thead><tr><th>Tanggal</th><th>Ramalan</th><th>Interval 80%</th><th>Interval 95%</th></tr></thead>
    <tbody>
    $rows
    </tbody></table>"""
end

_fmt_num(x) = isnan(x) ? "-" : string(round(x; digits = 2))

function _img_tag(path::AbstractString, alt::AbstractString)
    isfile(path) || return "<p><em>[grafik tidak tersedia: $(basename(path))]</em></p>"
    b64 = base64encode(read(path))
    return "<img alt=\"$alt\" src=\"data:image/png;base64,$b64\" style=\"max-width:100%;border-radius:8px;\">"
end

"""Self-contained HTML report in Bahasa Indonesia."""
function write_html_report(path::AbstractString; csv_name, hist, fc, insights, agg, selection,
                           forecast_png, pattern_png, compare_png, generated_at)
    insight_items = join(["<li>$(_escape_html(i))</li>" for i in insights], "\n")
    champion = _escape_html(selection.model)
    html = """<!DOCTYPE html>
<html lang="id">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Augur - Laporan Ramalan Penjualan</title>
<style>
  :root { --ink:#1a1a1a; --accent:#c42e7f; --muted:#666; --bg:#faf8f5; --card:#ffffff; }
  body { font-family: Georgia, 'Times New Roman', serif; color: var(--ink); background: var(--bg); margin: 0; }
  main { max-width: 880px; margin: 0 auto; padding: 32px 20px 64px; }
  h1 { font-size: 2rem; margin: 0 0 4px; }
  h1 .accent { color: var(--accent); }
  h2 { font-size: 1.15rem; text-transform: uppercase; letter-spacing: 0.08em; color: var(--muted); border-bottom: 2px solid var(--accent); padding-bottom: 6px; margin-top: 36px; }
  .meta { color: var(--muted); font-size: 0.9rem; }
  .card { background: var(--card); border: 1px solid #e5e0d8; border-radius: 10px; padding: 18px 20px; margin: 14px 0; }
  ul { line-height: 1.6; }
  table { border-collapse: collapse; width: 100%; font-size: 0.9rem; }
  th, td { text-align: left; padding: 8px 10px; border-bottom: 1px solid #ece7de; }
  th { color: var(--muted); font-size: 0.78rem; text-transform: uppercase; letter-spacing: 0.06em; }
  .err { color: #b03030; font-size: 0.8em; }
  footer { color: var(--muted); font-size: 0.8rem; margin-top: 40px; border-top: 1px solid #e5e0d8; padding-top: 12px; }
</style>
</head>
<body>
<main>
  <h1>Augur <span class="accent">- Ramalan Penjualan</span></h1>
  <p class="meta">Dibuat $( _escape_html(generated_at)) - data histori $(nrow(hist)) hari - model terpilih: <strong>$champion</strong></p>

  <h2>Ringkasan untuk Pemilik</h2>
  <div class="card"><ul>$insight_items</ul></div>

  <h2>Grafik Ramalan</h2>
  <div class="card">$( _img_tag(forecast_png, "Histori dan ramalan penjualan"))</div>

  <h2>Ramalan Harian</h2>
  <div class="card">$( _forecast_table_html(fc))</div>
  <p class="meta">File CSV ramalan: $( _escape_html(csv_name))</p>

  <h2>Perbandingan Model (Backtest)</h2>
  <div class="card">$( _img_tag(compare_png, "Perbandingan MASE antar model"))
  $( _metrics_table_html(agg[agg.fold .== 0, :]))</div>

  <h2>Pola Mingguan</h2>
  <div class="card">$( _img_tag(pattern_png, "Rata-rata penjualan per hari"))</div>

  <footer>Augur - ramalan penjualan UMKM. Ramalan selalu disertai rentang ketidakpastian; semakin jauh horizon, semakin lebar rentangnya. Bukan jaminan hasil.</footer>
</main>
</body>
</html>"""
    write(path, html)
    return path
end

"""Markdown report (relative image paths)."""
function write_markdown_report(path::AbstractString; csv_name, hist, fc, insights, agg, selection,
                               forecast_png, pattern_png, compare_png, generated_at)
    insight_lines = join(["- $i" for i in insights], "\n")
    agg0 = agg[agg.fold .== 0, :]
    metric_rows = join(map(eachrow(agg0)) do r
        "| $(r.model) | $(_fmt_num(r.mae)) | $(_fmt_num(r.rmse)) | $(_fmt_num(r.smape)) | $(_fmt_num(r.mase)) |"
    end, "\n")
    fc_rows = join(map(eachrow(fc)) do r
        "| $(format_date_id(r.tanggal)) | $(format_rupiah(r.ramalan)) | $(format_rupiah(r.bawah_80)) - $(format_rupiah(r.atas_80)) | $(format_rupiah(r.bawah_95)) - $(format_rupiah(r.atas_95)) |"
    end, "\n")

    md = """# Augur - Laporan Ramalan Penjualan

Dibuat $generated_at - data histori $(nrow(hist)) hari - model terpilih: **$(selection.model)**

## Ringkasan untuk Pemilik

$insight_lines

## Grafik Ramalan

![Histori dan ramalan]($(basename(forecast_png)))

## Ramalan Harian

| Tanggal | Ramalan | Interval 80% | Interval 95% |
|---|---|---|---|
$fc_rows

File CSV ramalan: `$csv_name`

## Perbandingan Model (Backtest)

![Perbandingan model]($(basename(compare_png)))

| Model | MAE | RMSE | sMAPE (%) | MASE |
|---|---|---|---|---|
$metric_rows

## Pola Mingguan

![Pola mingguan]($(basename(pattern_png)))

---

Augur - ramalan penjualan UMKM. Ramalan selalu disertai rentang ketidakpastian. Bukan jaminan hasil.
"""
    write(path, md)
    return path
end
