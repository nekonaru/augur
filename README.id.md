<div align="center">
  <img src="assets/logo-light.svg" alt="Logo Augur" width="140" />
  <h1>Augur: Forecasting untuk UMKM</h1>
  <p><b>Ubah data penjualan CSV menjadi ramalan yang jujur dan insight bahasa sehari-hari<br/>
  untuk warung dan UMKM. Sepenuhnya offline, tanpa akun.</b></p>

  <a href="https://github.com/nekonaru/augur/releases"><img src="https://img.shields.io/github/v/release/nekonaru/augur?style=flat-square&color=blue" alt="Rilis" /></a>
  <a href="https://github.com/nekonaru/augur/actions/workflows/ci.yml"><img src="https://github.com/nekonaru/augur/actions/workflows/ci.yml/badge.svg" alt="CI" /></a>
  <img src="https://img.shields.io/badge/julia-1.10%2B-9558B2?style=flat-square&logo=julia&logoColor=white" alt="Julia" />
  <img src="https://img.shields.io/badge/Platform-Linux%20%7C%20macOS%20%7C%20Windows-2f2f2f?style=flat-square" alt="Platform" />
  <img src="https://img.shields.io/badge/License-MIT-green?style=flat-square" alt="Lisensi" />
  <img src="https://img.shields.io/badge/Status-Active-brightgreen?style=flat-square" alt="Status" />
</div>

<br />

[English](README.md) | **Bahasa Indonesia**

> [!NOTE]
> Augur berjalan sepenuhnya di komputermu. Data penjualan tidak pernah keluar dari komputer, dan tidak perlu akun maupun koneksi internet setelah instalasi.

---

## Daftar Isi

- [Tentang](#tentang)
- [Fitur](#fitur)
- [Kebutuhan](#kebutuhan)
- [Instalasi](#instalasi)
- [Penggunaan](#penggunaan)
- [Sumber Data](#sumber-data)
- [Struktur Proyek](#struktur-proyek)
- [Pengembangan](#pengembangan)
- [Pengujian](#pengujian)
- [Continuous Integration](#continuous-integration)
- [FAQ](#faq)
- [Penulis](#penulis)
- [Penafian](#penafian)
- [Lisensi](#lisensi)

---

## Tentang

**Augur** membaca histori penjualan harian atau mingguan dari file CSV, membersihkannya, membandingkan beberapa model peramalan pada data milikmu sendiri, lalu menghasilkan ramalan 7, 14 atau 30 hari ke depan lengkap dengan interval ketidakpastian, grafik, dan ringkasan bahasa Indonesia yang mudah dipahami. Augur dibuat untuk pemilik UMKM (warung makan, toko kelontong, kedai kopi, toko online kecil) dan untuk mahasiswa yang ingin contoh peramalan terapan yang transparan dan jujur.

> _"Ramalkan penjualan dengan data, bukan tebakan."_

---

## Fitur

### Mesin peramalan

| Fitur | Deskripsi |
|---------|-------------|
| **Banyak model** | Naive, Seasonal Naive (7 hari), Moving Average, SES, Holt, Holt-Winters aditif dan multiplikatif, regresi kalender OLS. Semua diimplementasikan dari nol. |
| **Fitur kalender** | Efek hari dalam seminggu, penanda gajian (tanggal 25 sampai 2), libur nasional Indonesia dari CSV yang bisa diperbarui, dan penanda promo. |
| **Pemilihan model otomatis** | Backtest rolling-origin memilih model terbaik berdasarkan MASE (jika MASE seri, pemenangnya ditentukan oleh RMSE) dan menjelaskan pilihannya dengan bahasa sehari-hari. |
| **Interval bootstrap** | Interval prediksi 80% dan 95% dari residual bootstrap, reproducible lewat seed eksplisit. |
| **Data contoh sintetis** | Generator bawaan dengan tren, musiman mingguan, lonjakan Lebaran, hari promo dan noise, untuk mencoba Augur tanpa data sendiri. |

### Evaluasi yang jujur

| Fitur | Deskripsi |
|---------|-------------|
| **Backtest rolling-origin** | Tidak ada model yang melihat data uji miliknya sendiri; metrik dihitung per lipatan lalu dirata-ratakan. |
| **Pelaporan MASE** | Model dibandingkan dengan baseline seasonal naive (MASE di bawah 1,0 berarti mengalahkan baseline). |
| **Ketidakpastian didahulukan** | Tidak ada angka ramalan tunggal tanpa rentang; data kurang dari 8 minggu memunculkan peringatan eksplisit. |
| **Penanganan outlier** | Deteksi robust z-score (MAD) atau IQR, dengan pilihan winsorize (default), mark atau drop. |

### Input dan output

| Fitur | Deskripsi |
|---------|-------------|
| **Input CSV fleksibel** | `tanggal`, `penjualan`, opsional `promo` (0/1) dan `produk`. Format tanggal dan angka Indonesia diterima; tanggal duplikat dijumlahkan. |
| **Pengisian gap** | Hari kalender yang hilang diisi dengan interpolasi linear; nilai negatif dianggap hilang. |
| **Ekspor laporan** | Laporan HTML mandiri (grafik tertanam), laporan Markdown, CSV ramalan, dan grafik PNG (histori + ramalan, pola mingguan, perbandingan model). |
| **Insight Bahasa Indonesia** | Total ramalan, perubahan dibanding periode sebelumnya, hari puncak dan paling sepi, pola mingguan, alasan pemilihan model, semuanya dalam bahasa sehari-hari. |

---

## Kebutuhan

| Dependency | Versi Minimum | Catatan |
|------------|-----------------|-------|
| **Julia** | 1.10 | Lingkungan terkunci lewat `Project.toml` dan `Manifest.toml` |
| **Git** | 2.x | Untuk clone repository |

> [!TIP]
> Belum punya Julia? Contoh `data/contoh_penjualan.csv` tersedia untuk mencoba seluruh pipeline setelah instalasi satu perintah. Membangun dari source adalah satu-satunya cara menjalankan tool ini.

### Belum pernah pakai terminal? Mulai dari sini

<details>
<summary><b>Cara membuka terminal</b></summary>

1. **Windows**: tekan `Win + R`, ketik `powershell`, tekan Enter. Atau cari "Terminal" di menu Start.
2. **macOS**: tekan `Cmd + Space`, ketik `terminal`, tekan Enter.
3. **Linux**: tekan `Ctrl + Alt + T` di sebagian besar desktop.

</details>

---

## Instalasi

### Opsi A: Clone dan jalankan (disarankan)

#### 1. Ambil source code

<details>
<summary><b>Saya punya Git</b></summary>

```bash
git clone https://github.com/nekonaru/augur.git
cd augur
```

</details>

<details>
<summary><b>Saya tidak punya Git</b></summary>

Download ZIP dari tombol hijau "Code" di halaman repository, ekstrak, lalu buka terminal di folder hasil ekstrak.

</details>

#### 2. Install dependency dan verifikasi

Install [Julia 1.10 atau lebih baru](https://julialang.org/downloads/), pastikan `julia` ada di PATH, lalu jalankan:

```bash
julia --project=. -e "using Pkg; Pkg.instantiate()"
```

> [!IMPORTANT]
> Download package mencapai ratusan MB (CairoMakie). Gunakan koneksi stabil dan biarkan precompilation selesai; jangan interrupt run pertama.

#### 3. Jalankan contoh

```bash
julia --project=. scripts/ramal.jl data/contoh_penjualan.csv --horizon 14 --out laporan/
```

Buka `laporan/laporan.html` di browser. Itu laporan lengkapnya.

---

## Penggunaan

### Peluncuran pertama

1. Siapkan CSV penjualanmu (lihat format di bawah), atau pakai contoh bawaan.
2. Jalankan `julia --project=. scripts/ramal.jl filemu.csv --horizon 14 --out laporan/`.
3. Buka `laporan/laporan.html` dan baca bagian "Ringkasan untuk Pemilik" terlebih dahulu.
4. Pakai `ramalan.csv` untuk diimpor ke spreadsheet milikmu.

### Format CSV kamu

```csv
tanggal,penjualan,promo
2026-01-01,1250000,0
2026-01-02,980000,0
2026-01-03,1670000,1
```

| Kolom | Wajib | Catatan |
|--------|----------|-------|
| `tanggal` | ya | `yyyy-mm-dd`, `yyyy/mm/dd`, `dd/mm/yyyy` atau `dd-mm-yyyy` |
| `penjualan` | ya | Angka; menerima format `1.250.000` dan `1250000,50`; nilai negatif dibuang |
| `promo` | tidak | `0` atau `1`; kosong berarti `0` |
| `produk` | tidak | Disimpan apa adanya; ramalan per produk belum didukung |

Tanggal duplikat dijumlahkan. Satuan penjualan bebas (rupiah atau unit); Augur memperlakukannya sebagai angka biasa.

### Pemakaian sehari-hari

- **Ramalan lebih panjang**: `--horizon 30` (7 atau 14 biasanya paling masuk akal).
- **Agregasi mingguan**: `--granularity mingguan` untuk data lebih pendek dan kasar.
- **Tangani outlier lebih tegas**: ganti `--outlier mark` atau `--outlier drop`.
- **Run yang reproducible**: tetapkan `--seed 20250601` (default) supaya interval bootstrap persis sama.
- **Perbarui libur**: edit `data/libur_nasional.csv` (format `tanggal,keterangan`); tidak perlu ubah kode.

### Opsi

| Flag | Default | Arti |
|------|---------|---------|
| `--horizon N` | `14` | Berapa hari ke depan |
| `--out DIR` | `laporan/` | Folder output (dibuat otomatis jika belum ada) |
| `--granularity G` | `harian` | `harian` atau `mingguan` |
| `--outlier MODE` | `winsorize` | `winsorize`, `mark` atau `drop` |
| `--seed N` | `20250601` | Seed bootstrap |

---

## Sumber Data

| Tujuan | Sumber |
|---------|--------|
| Libur nasional Indonesia | SKB 3 Menteri (Hari Libur Nasional dan Cuti Bersama), disimpan di `data/libur_nasional.csv` (2025 sampai 2027) |
| Data contoh penjualan | Sintetis, dibuat oleh `generate_synthetic` dengan seed tetap; bukan transaksi nyata |

> [!NOTE]
> Perbarui `libur_nasional.csv` setiap tahun setelah SKB terbit. Cuti bersama bisa ditambahkan sebagai baris tambahan jika tokomu tutup pada hari-hari itu.

---

## Struktur Proyek

```
augur/
  assets/             # logo dan icon (SVG)
  data/
    contoh_penjualan.csv   # contoh sintetis, 365 hari
    libur_nasional.csv     # libur Indonesia 2025-2027
  docs/
    model.md          # keputusan pemodelan dan catatan evaluasi
  scripts/
    ramal.jl          # entry point CLI
  src/
    Augur.jl          # module dan ekspor
    io.jl             # pembacaan dan validasi CSV
    clean.jl          # pengisian gap, outlier, agregasi mingguan
    calendar.jl       # fitur libur dan gajian
    models/           # naive, seasonal naive, moving average,
                      # SES, Holt, Holt-Winters, regresi kalender, ensemble
    backtest.jl       # backtest rolling-origin, metrik, pemilihan model
    intervals.jl      # interval prediksi bootstrap
    insights.jl       # template insight Bahasa Indonesia
    plots.jl          # grafik CairoMakie
    report.jl         # penulis laporan CSV/HTML/Markdown
    pipeline.jl       # orkestrasi end-to-end
    synthetic.jl      # generator data sintetis
  test/
    runtests.jl       # test suite (67 tes)
  README.md           # English (sumber)
  README.id.md        # Bahasa Indonesia
```

---

## Pengembangan

### Menambahkan model baru

1. Buat `src/models/modelmu.jl` mengikuti interface `AbstractForecaster` di `src/models/common.jl` (`fit`, `forecast`, `fitted_values`).
2. Include di `src/Augur.jl` dan ekspor typenya.
3. Tambahkan ke `default_models` di `src/backtest.jl` dan ke `_champion_template` di `src/pipeline.jl`.
4. Tambahkan tes di `test/runtests.jl` (fit pada deret yang diketahui, kalahkan baseline pada data sintetis).

### Memperbarui data contoh

```bash
julia --project=. -e "using Augur, CSV, DataFrames; CSV.write(\"data/contoh_penjualan.csv\", generate_synthetic(n_days = 365, seed = 20260601))"
```

### Rilis

1. Perbarui `version` di `Project.toml` dan kedua file changelog.
2. Tag `vX.Y.Z` setelah CI hijau.
3. Publikasikan GitHub release dari entri changelog.

> [!WARNING]
> `Manifest.toml` sengaja di-commit. Jangan menghapus atau me-regenerate-nya sembarangan; environment reproducible adalah bagian dari desain. Laporan hasil generate (`laporan/`) dan file kerja `SECURITY_*.md` tidak boleh di-commit.

---

## Pengujian

```bash
julia --project=. -e "using Pkg; Pkg.test()"
```

| Cek | Syarat |
|-------|-------------|
| Test suite | 67 tes, semuanya hijau |
| CI | Hijau pada push dan PR ke `main` |
| Analyzer | Tidak ada linter yang dikonfigurasi; test suite adalah gerbangnya |

---

## Continuous Integration

| Workflow | Tujuan |
|----------|---------|
| `ci.yml` | Install Julia 1.10, instantiate, jalankan test suite pada push dan PR ke `main` |

CI berjalan pada setiap push ke branch utama. Tag rilis hanya setelah CI hijau.

---

## FAQ

<details>
<summary><b>Apakah saya butuh data penjualan sendiri untuk mencoba Augur?</b></summary>

Tidak. `data/contoh_penjualan.csv` bawaan bersifat sintetis dan realistis (tren, musiman mingguan, lonjakan Lebaran, hari promo). Jalankan satu perintah dan kamu langsung dapat laporan lengkap.

</details>

<details>
<summary><b>Data saya lebih pendek dari 8 minggu. Masih bisa dipakai?</b></summary>

Bisa, tapi Augur akan memperingatkan bahwa ramalan kurang stabil. Anggap sebagai gambaran kasar, bukan angka untuk dijadikan dasar belanja stok.

</details>

<details>
<summary><b>Model apa saja yang dipakai Augur?</b></summary>

Naive, Seasonal Naive, Moving Average, SES, Holt, Holt-Winters (aditif dan multiplikatif) dan regresi kalender OLS. Model terbaik dipilih otomatis lewat MASE pada backtest rolling-origin data milikmu. Lihat `docs/model.md`.

</details>

<details>
<summary><b>Apakah Augur mendukung banyak produk?</b></summary>

Belum. Kolom `produk` dibaca dan disimpan, tapi ramalan dibuat untuk deret total harian. Ramalan per produk direncanakan untuk v0.2.

</details>

<details>
<summary><b>Apakah angka penjualan saya dikirim ke mana pun?</b></summary>

Tidak. Augur berjalan sepenuhnya offline setelah package terinstall. Tidak ada telemetri, tidak ada akun, dan tidak ada panggilan jaringan saat meramal.

</details>

---

## Penulis

<div align="center">
  <table>
    <tr>
      <td align="center"><a href="https://github.com/nekonaru"><img src="https://github.com/nekonaru.png?size=100" alt="Nicolas Dwi Dharma" /></a></td>
    </tr>
    <tr>
      <td align="center"><b>Nicolas Dwi Dharma</b><br/><a href="https://github.com/nekonaru">github.com/nekonaru</a></td>
    </tr>
  </table>
</div>

---

## Penafian

Augur menghasilkan estimasi statistik, bukan jaminan. Penjualan nyata juga dipengaruhi cuaca, kompetitor, dan kejadian lokal yang tidak bisa dilihat model mana pun. Gunakan interval, bukan angka tunggal, saat membuat keputusan stok. Daftar libur disusun dari SKB 3 Menteri 2025 sampai 2027 dan harus diperbarui setiap tahun.

---

## Lisensi

Didistribusikan di bawah **MIT License**. Lihat [`LICENSE`](LICENSE) untuk informasi lebih lanjut.
