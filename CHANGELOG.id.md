# Changelog

## v0.1.0

Rilis publik pertama Augur, tool peramalan lokal untuk data penjualan UMKM.

## Fitur baru

- **Pipeline CSV.** Baca, bersihkan dan modelkan histori penjualan harian atau mingguan dari satu file CSV dengan format tanggal dan angka Indonesia.
- **Pustaka model.** Naive, Seasonal Naive, Moving Average, SES, Holt, Holt-Winters aditif dan multiplikatif, serta regresi kalender OLS dengan efek gajian dan libur.
- **Backtest jujur.** Backtest rolling-origin memilih model terbaik berdasarkan MASE (jika MASE seri, pemenangnya ditentukan oleh RMSE) dan melaporkan MAE, RMSE, sMAPE dan MASE per lipatan.
- **Interval bootstrap.** Setiap ramalan disertai interval ketidakpastian 80% dan 95%, reproducible lewat bootstrap dengan seed.
- **Laporan.** Laporan HTML mandiri dengan grafik tertanam, laporan Markdown, CSV ramalan, dan grafik PNG untuk histori, pola mingguan dan perbandingan model.
- **CLI.** Satu perintah mengubah CSV menjadi laporan lengkap: `julia --project=. scripts/ramal.jl data.csv --horizon 14 --out laporan/`.
- **Demo sintetis.** Dataset contoh bawaan dan generator dengan tren, musiman mingguan, lonjakan Lebaran dan hari promo.

## Peningkatan

- **Precompile workload.** Jalur panas precompile, jadi cold start turun jadi hitungan detik, bukan menit.
- **Penanganan outlier.** Deteksi MAD (default) atau IQR dengan strategi winsorize, mark atau drop, semuanya dilaporkan di peringatan akhir.

## Perbaikan bug

- **Regresi kalender.** Perbaikan import `LinearAlgebra` yang membuat OLS gagal di dalam backtest.
- **Grafik Makie.** Perbaikan penanganan sumbu x tanggal pada grafik; sumbu y sekarang memakai satuan juta rupiah yang mudah dibaca.
