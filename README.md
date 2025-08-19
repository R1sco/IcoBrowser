# IcoBrowser

Browser desktop minimalis berbasis Zig dengan fokus pada kecepatan, keamanan, dan kemampuan kustomisasi.

## Tentang IcoBrowser

IcoBrowser adalah browser desktop yang minimalis, cepat, dan dapat diprogram oleh pengguna. Fokus utamanya adalah memberikan kontrol penuh kepada pengguna untuk memodifikasi pengalaman browsing mereka.

## Teknologi

- **Bahasa Utama**: Zig
- **Rendering Engine & GUI (Windows)**: Microsoft Edge WebView2
- **Sistem Build**: Zig Build System

## Fitur Inti

- **Kinerja Tinggi & Ringan**: Waktu startup cepat dan penggunaan RAM yang rendah
- **Pemblokir Konten Internal**: Menyembunyikan iklan dan elemen pengganggu secara default
- **Keamanan Browser**:
  - Pembaruan WebView2 otomatis
  - Pembatasan akses ke sistem file lokal
  - Penanganan HTTPS dan sertifikat yang ketat
  - Pemblokiran konten berbahaya (termasuk situs judi online)
  - Perlindungan data pribadi
  - Manajemen izin
  - Keamanan JavaScript
  - Penanganan download yang aman
  - Pemantauan dan pembaruan keamanan
- **Kustomisasi Tema**: Pilihan tema bawaan (Dark dan Light)
- **Fungsionalitas Browser Dasar**: Sistem tab dan navigasi dasar

## Struktur Proyek

```
IcoBrowser/
├── build.zig                        # Zig build system
├── assets/
│   └── themes/                      # File tema JSON
│       ├── light.json              # Tema terang
│       └── dark.json               # Tema gelap
├── src/
│   ├── main.zig                    # Entry point aplikasi
│   ├── security.zig                # Modul keamanan dasar
│   ├── platform/
│   │   └── windows/               # Implementasi spesifik Windows
│   │       ├── webview2.zig       # Binding WebView2
│   │       └── win32.zig          # Binding Win32 API
│   ├── ui/
│   │   ├── windows.zig           # Integrasi Windows dan WebView2
│   │   ├── browser_ui.zig        # Komponen UI browser
│   │   ├── theme.zig             # Sistem tema UI
│   │   └── rules_manager.zig     # Pengelola aturan browser
│   └── core/
│       ├── theming.zig           # Sistem tema inti
│       ├── rules.zig             # Aturan browser
│       └── security/             # Modul keamanan
│           ├── content_blocker.zig  # Pemblokir konten
│           └── enhanced_security.zig # Keamanan lanjutan
└── README.md                       # Dokumentasi proyek
```

## Memulai Pengembangan

### Prasyarat

- [Zig](https://ziglang.org/download/) (versi terbaru)
- [WebView2 Runtime](https://developer.microsoft.com/en-us/microsoft-edge/webview2/) (untuk Windows)

### Membangun Proyek

```bash
# Clone repositori
git clone [url-repositori]
cd IcoBrowser

# Build proyek
zig build

# Jalankan aplikasi
zig build run
```

## Peta Jalan (Roadmap)

### Milestone 1: Browser Inti
- Aplikasi GUI Zig dasar untuk Windows
- Integrasi Microsoft Edge WebView2
- Bar alamat dan tombol navigasi dasar
- Implementasi dasar untuk pembaruan WebView2 otomatis

### Milestone 2: Implementasi Fitur Khas & Keamanan Dasar
- Modul Pemblokir Konten termasuk pemblokiran situs judi online
- Sistem Tema (Dark/Light)
- Sistem Tab dasar
- Fitur keamanan dasar

### Milestone 3: Keamanan Lanjutan & Stabilitas
- Fitur keamanan lanjutan
- Perbaikan bug dan optimalisasi
- Fitur standar seperti Bookmark

### Milestone 4: Peningkatan & Perluasan
- Peningkatan aspek keamanan
- Fitur keamanan lanjutan
- Perluasan kemampuan pemblokiran konten berbahaya
- Optimalisasi performa dan penggunaan memori

## Lisensi
