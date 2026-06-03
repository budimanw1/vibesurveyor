# Dokumen Kebutuhan (Requirements Document)

## Introduction

VibeSurveyor adalah aplikasi kamera iOS untuk profesional surveyor lapangan. Aplikasi ini menggabungkan kamera kustom berbasis AVFoundation dengan data telemetri real-time (GPS, altimeter, kompas, dan kemiringan kamera) yang ditampilkan sebagai overlay di layar. Saat tombol jepret ditekan, seluruh data telemetri dicetak secara permanen di atas foto hasil jepretan sebagai watermark. Aplikasi juga menyediakan manajemen proyek sederhana untuk mengorganisir foto berdasarkan nama proyek.

Aplikasi dibangun 100% menggunakan framework native Apple (AVFoundation, CoreLocation, CoreMotion, SwiftUI, UIKit) tanpa dependensi pihak ketiga, sehingga dapat dikompilasi melalui GitHub Actions menggunakan vanilla macOS runner.

**Target Platform:** iOS 15+  
**Bahasa & Framework:** Swift, SwiftUI  
**Prinsip Desain:** Zero-Dependency (Pure Native iOS Frameworks)

---

## Glosarium

- **VibeSurveyor**: Nama aplikasi iOS yang dikembangkan dalam dokumen ini.
- **Camera_Manager**: Komponen yang mengelola session AVFoundation, preview kamera, dan fungsi pengambilan foto.
- **Location_Manager**: Komponen yang mengelola CoreLocation untuk mendapatkan data GPS, altitude, dan heading (arah kompas).
- **Motion_Manager**: Komponen yang mengelola CoreMotion untuk mendapatkan data pitch dan roll kamera.
- **Watermark_Processor**: Komponen yang memproses gambar dengan mencetak data telemetri secara permanen di atas foto.
- **Project_Manager**: Komponen yang mengelola pembuatan, penyimpanan, dan pemilihan nama proyek.
- **Telemetry_Overlay**: Tampilan data telemetri (GPS, altitude, heading, pitch, roll, timestamp) yang ditampilkan di atas preview kamera secara real-time.
- **Crosshair**: Garis bidik (horizontal dan vertikal) yang ditampilkan di tengah layar kamera sebagai pembantu presisi bidikan.
- **Telemetry_Data**: Kumpulan data survei yang terdiri dari: koordinat GPS (latitude/longitude), altitude, heading, pitch, roll, dan timestamp.
- **Watermark**: Teks Telemetry_Data yang dicetak secara permanen di atas foto hasil jepretan.
- **Photo_File**: File foto berformat JPEG yang disimpan ke direktori dokumen aplikasi.
- **Project**: Entitas yang merepresentasikan satu sesi pekerjaan survei dengan nama unik yang diberikan pengguna.
- **AVFoundation**: Framework native Apple untuk akses kamera dan media.
- **CoreLocation**: Framework native Apple untuk akses GPS, altitude, dan kompas.
- **CoreMotion**: Framework native Apple untuk akses sensor gerak (accelerometer/gyroscope).
- **Decimal_Degrees**: Format koordinat GPS dalam angka desimal, contoh: -6.200000, 106.816666.
- **Azimuth**: Sudut arah kompas dalam derajat (0°–360°), diukur dari utara searah jarum jam.
- **Pitch**: Sudut kemiringan kamera ke depan/belakang dalam derajat.
- **Roll**: Sudut kemiringan kamera ke kiri/kanan dalam derajat.

---

## Requirements

### Requirement 1: Tampilan Kamera Kustom (Custom Camera View)

**User Story:** Sebagai surveyor lapangan, saya ingin melihat preview kamera full-screen di dalam aplikasi, agar saya dapat membidik target survei secara langsung tanpa harus keluar dari aplikasi.

#### Kriteria Penerimaan

1. THE Camera_Manager SHALL menginisialisasi AVCaptureSession dengan konfigurasi input kamera belakang (rear camera) saat aplikasi pertama kali dibuka.
2. WHEN AVCaptureSession berhasil diinisialisasi, THE Camera_Manager SHALL menampilkan preview kamera secara full-screen menggunakan AVCaptureVideoPreviewLayer.
3. WHILE preview kamera aktif, THE Camera_Manager SHALL mempertahankan orientasi preview kamera dalam mode portrait.
4. IF kamera belakang tidak tersedia di perangkat, THEN THE Camera_Manager SHALL menampilkan pesan error "Kamera tidak tersedia pada perangkat ini" kepada pengguna.
5. IF izin akses kamera ditolak oleh pengguna, THEN THE Camera_Manager SHALL menampilkan pesan "Izin kamera diperlukan. Aktifkan di Pengaturan > VibeSurveyor > Kamera." beserta tombol yang mengarahkan pengguna ke halaman pengaturan sistem.
6. WHEN aplikasi masuk ke background, THE Camera_Manager SHALL menghentikan sementara AVCaptureSession.
7. WHEN aplikasi kembali ke foreground, THE Camera_Manager SHALL melanjutkan kembali AVCaptureSession.

---

### Requirement 2: Target Grid Overlay (Crosshair)

**User Story:** Sebagai surveyor lapangan, saya ingin melihat garis bidik (crosshair) di tengah layar kamera, agar saya dapat membidik titik target survei dengan presisi.

#### Kriteria Penerimaan

1. WHILE preview kamera aktif, THE VibeSurveyor SHALL menampilkan Crosshair berupa garis horizontal dan vertikal yang berpotongan tepat di titik tengah layar.
2. THE VibeSurveyor SHALL merender Crosshair menggunakan SwiftUI overlay di atas preview kamera, bukan diproses ke dalam foto.
3. THE VibeSurveyor SHALL menampilkan Crosshair dengan warna putih semi-transparan (opacity 0.7) agar kontras terhadap berbagai kondisi latar belakang.
4. THE VibeSurveyor SHALL mempertahankan posisi dan ukuran Crosshair yang proporsional terhadap ukuran layar perangkat yang berbeda-beda (iPhone SE hingga iPhone Pro Max).

---

### Requirement 3: Data Telemetri GPS Real-time

**User Story:** Sebagai surveyor lapangan, saya ingin melihat koordinat GPS, altitude, dan arah kompas secara real-time di layar kamera, agar saya dapat mencatat posisi titik survei secara akurat.

#### Kriteria Penerimaan

1. THE Location_Manager SHALL meminta izin akses lokasi kepada pengguna dengan mode "When In Use" saat aplikasi pertama kali dijalankan.
2. IF izin akses lokasi ditolak oleh pengguna, THEN THE Location_Manager SHALL menampilkan nilai "N/A" pada semua field data lokasi di Telemetry_Overlay.
3. WHEN izin lokasi diberikan, THE Location_Manager SHALL memulai pembaruan lokasi dengan akurasi kLocationAccuracyBestForNavigation.
4. WHILE pembaruan lokasi aktif, THE Location_Manager SHALL memperbarui data latitude dalam format Decimal_Degrees dengan presisi 6 angka di belakang koma.
5. WHILE pembaruan lokasi aktif, THE Location_Manager SHALL memperbarui data longitude dalam format Decimal_Degrees dengan presisi 6 angka di belakang koma.
6. WHILE pembaruan lokasi aktif, THE Location_Manager SHALL memperbarui data altitude dalam satuan meter dengan presisi 1 angka di belakang koma.
7. THE Location_Manager SHALL mengaktifkan pembaruan heading (kompas) untuk mendapatkan nilai Azimuth dalam rentang 0.0° hingga 359.9°.
8. WHILE pembaruan heading aktif, THE Location_Manager SHALL memperbarui nilai Azimuth menggunakan trueHeading dari CLHeading.
9. IF nilai trueHeading negatif (sinyal kompas tidak valid), THEN THE Location_Manager SHALL menampilkan nilai "---°" pada field Azimuth di Telemetry_Overlay.
10. WHILE data telemetri lokasi tersedia, THE VibeSurveyor SHALL menampilkan data tersebut pada Telemetry_Overlay dengan pembaruan maksimum setiap 1 detik untuk menjaga performa UI.

---

### Requirement 4: Data Telemetri Gerak (Pitch & Roll)

**User Story:** Sebagai surveyor lapangan, saya ingin melihat sudut kemiringan kamera (pitch dan roll) secara real-time, agar saya dapat mengukur sudut elevasi dan kemiringan target survei.

#### Kriteria Penerimaan

1. THE Motion_Manager SHALL memulai pembaruan data dari DeviceMotion menggunakan CMMotionManager saat aplikasi aktif.
2. THE Motion_Manager SHALL mengatur interval pembaruan DeviceMotion sebesar 0.1 detik (10 Hz).
3. WHILE DeviceMotion aktif, THE Motion_Manager SHALL memperbarui nilai Pitch dalam satuan derajat dengan presisi 1 angka di belakang koma, dikonversi dari radian menggunakan rumus: derajat = radian × (180 / π).
4. WHILE DeviceMotion aktif, THE Motion_Manager SHALL memperbarui nilai Roll dalam satuan derajat dengan presisi 1 angka di belakang koma, dikonversi dari radian menggunakan rumus: derajat = radian × (180 / π).
5. IF DeviceMotion tidak tersedia pada perangkat, THEN THE Motion_Manager SHALL menampilkan nilai "N/A" pada field Pitch dan Roll di Telemetry_Overlay.
6. WHEN aplikasi masuk ke background, THE Motion_Manager SHALL menghentikan pembaruan DeviceMotion.
7. WHEN aplikasi kembali ke foreground, THE Motion_Manager SHALL melanjutkan kembali pembaruan DeviceMotion.

---

### Requirement 5: Telemetry Overlay pada UI

**User Story:** Sebagai surveyor lapangan, saya ingin melihat semua data telemetri ditampilkan dengan jelas di atas preview kamera, agar saya dapat membaca semua informasi survei dalam satu tampilan.

#### Kriteria Penerimaan

1. WHILE preview kamera aktif, THE VibeSurveyor SHALL menampilkan Telemetry_Overlay yang memuat: latitude, longitude, altitude, azimuth, pitch, roll, dan timestamp (tanggal, jam, menit, detik).
2. THE VibeSurveyor SHALL memposisikan Telemetry_Overlay di area bawah layar di atas tombol jepret, dengan background gelap semi-transparan agar mudah dibaca.
3. THE VibeSurveyor SHALL menampilkan timestamp pada Telemetry_Overlay dalam format: `DD/MM/YYYY HH:MM:SS` menggunakan zona waktu perangkat.
4. THE VibeSurveyor SHALL merender Telemetry_Overlay menggunakan SwiftUI dan TIDAK mencetak Telemetry_Overlay langsung ke dalam foto (pencetakan ke foto dilakukan oleh Watermark_Processor).
5. THE VibeSurveyor SHALL menampilkan label identifikasi untuk setiap field data telemetri (contoh: "LAT:", "LON:", "ALT:", "AZM:", "PITCH:", "ROLL:", "TIME:").

---

### Requirement 6: Pengambilan Foto dan Watermark Telemetri

**User Story:** Sebagai surveyor lapangan, saya ingin mengambil foto yang sudah tercetak data telemetri secara permanen, agar data survei dan foto target tidak dapat dipisahkan.

#### Kriteria Penerimaan

1. WHEN pengguna menekan tombol jepret, THE Camera_Manager SHALL mengambil foto menggunakan AVCapturePhotoOutput dengan konfigurasi format JPEG.
2. WHEN foto berhasil diambil oleh Camera_Manager, THE Watermark_Processor SHALL mengambil snapshot data Telemetry_Data terkini pada saat tombol jepret ditekan.
3. THE Watermark_Processor SHALL menggunakan UIGraphicsImageRenderer untuk menggambar teks Telemetry_Data di atas gambar asli.
4. THE Watermark_Processor SHALL mencetak Watermark di sudut kiri bawah foto dengan latar belakang hitam semi-transparan dan teks berwarna putih.
5. THE Watermark_Processor SHALL menggunakan ukuran font yang proporsional terhadap resolusi foto sehingga Watermark terbaca jelas pada resolusi foto penuh.
6. THE Watermark_Processor SHALL mencetak data berikut ke dalam Watermark secara berurutan: nama proyek, latitude, longitude, altitude, azimuth, pitch, roll, dan timestamp.
7. WHEN Watermark_Processor selesai memproses foto, THE VibeSurveyor SHALL menyimpan Photo_File ke direktori dokumen aplikasi (Application Documents Directory).
8. IF proses penyimpanan foto gagal, THEN THE VibeSurveyor SHALL menampilkan pesan error "Gagal menyimpan foto. Periksa kapasitas penyimpanan perangkat." kepada pengguna.
9. WHEN foto berhasil disimpan, THE VibeSurveyor SHALL menampilkan animasi flash singkat (durasi 0.2 detik) sebagai konfirmasi visual bahwa foto berhasil diambil.

---

### Requirement 7: Penamaan File Foto Otomatis

**User Story:** Sebagai surveyor lapangan, saya ingin setiap foto dinamai secara otomatis berdasarkan nama proyek, tanggal, dan koordinat GPS, agar saya dapat mengidentifikasi dan menyortir foto dengan mudah tanpa harus memberi nama manual.

#### Kriteria Penerimaan

1. THE VibeSurveyor SHALL memberi nama Photo_File menggunakan format: `[NamaProyek]_[Tanggal]_[Lat]_[Lon].jpg`.
2. THE VibeSurveyor SHALL memformat komponen [Tanggal] dalam format `YYYYMMDD`.
3. THE VibeSurveyor SHALL memformat komponen [Lat] dan [Lon] dengan mengganti karakter titik (`.`) dengan karakter `p` dan tanda minus (`-`) dengan karakter `m`, contoh: latitude `-6.200000` menjadi `m6p200000`.
4. IF nama proyek belum diatur oleh pengguna, THEN THE VibeSurveyor SHALL menggunakan string "Default" sebagai komponen [NamaProyek] dalam nama file.
5. THE VibeSurveyor SHALL memastikan nama file hanya mengandung karakter alfanumerik, underscore (`_`), dan huruf `p`/`m` sebagai pengganti karakter khusus koordinat, untuk kompatibilitas sistem file.

---

### Requirement 8: Manajemen Proyek

**User Story:** Sebagai surveyor lapangan, saya ingin membuat dan memilih nama proyek sebelum mengambil foto, agar semua foto dalam satu sesi survei terorganisir di bawah satu nama proyek yang sama.

#### Kriteria Penerimaan

1. THE Project_Manager SHALL menyimpan daftar nama proyek ke UserDefaults pada penyimpanan lokal perangkat.
2. WHEN aplikasi pertama kali dijalankan tanpa proyek yang tersimpan, THE VibeSurveyor SHALL menampilkan nama proyek aktif sebagai "Default".
3. THE VibeSurveyor SHALL menyediakan tombol atau area di UI utama yang menampilkan nama proyek aktif dan dapat ditekan untuk membuka layar manajemen proyek.
4. WHEN pengguna membuka layar manajemen proyek, THE VibeSurveyor SHALL menampilkan daftar semua nama proyek yang tersimpan beserta tombol untuk menambah proyek baru.
5. WHEN pengguna memasukkan nama proyek baru dan mengkonfirmasi, THE Project_Manager SHALL menyimpan nama proyek tersebut dan menjadikannya proyek aktif.
6. IF nama proyek yang dimasukkan kosong atau hanya berisi spasi, THEN THE VibeSurveyor SHALL menampilkan pesan validasi "Nama proyek tidak boleh kosong." dan tidak menyimpan proyek tersebut.
7. WHEN pengguna memilih nama proyek dari daftar, THE Project_Manager SHALL menjadikan proyek tersebut sebagai proyek aktif dan menutup layar manajemen proyek.
8. THE VibeSurveyor SHALL menampilkan indikator visual (misalnya tanda centang) pada proyek yang sedang aktif di daftar proyek.

---

### Requirement 9: Penyimpanan dan Akses File Foto

**User Story:** Sebagai surveyor lapangan, saya ingin foto yang saya ambil tersimpan di direktori dokumen aplikasi dan dapat diakses melalui aplikasi Files pada iPhone, agar saya dapat mentransfer foto ke komputer dengan mudah.

#### Kriteria Penerimaan

1. THE VibeSurveyor SHALL menyimpan semua Photo_File ke dalam subdirektori berdasarkan nama proyek aktif di dalam Application Documents Directory, contoh: `.../Documents/[NamaProyek]/`.
2. THE VibeSurveyor SHALL mengkonfigurasi Application Documents Directory agar dapat diakses melalui aplikasi Files iOS dengan menambahkan key `UIFileSharingEnabled` dan `LSSupportsOpeningDocumentsInPlace` bernilai `true` pada Info.plist.
3. IF subdirektori untuk nama proyek aktif belum ada, THEN THE VibeSurveyor SHALL membuat subdirektori tersebut secara otomatis sebelum menyimpan foto pertama dalam proyek tersebut.
4. THE VibeSurveyor SHALL menyimpan Photo_File dalam format JPEG dengan kompresi kualitas 0.9 (90%) untuk menjaga kualitas foto survei.

---

### Requirement 10: Izin Sistem (Permissions)

**User Story:** Sebagai pengguna, saya ingin aplikasi meminta izin yang diperlukan dengan jelas, agar saya mengerti mengapa izin tersebut dibutuhkan dan dapat memberikan izin dengan percaya diri.

#### Kriteria Penerimaan

1. THE VibeSurveyor SHALL menyertakan string deskripsi penggunaan kamera (`NSCameraUsageDescription`) pada Info.plist dengan teks: "VibeSurveyor memerlukan akses kamera untuk mengambil foto survei lapangan."
2. THE VibeSurveyor SHALL menyertakan string deskripsi penggunaan lokasi (`NSLocationWhenInUseUsageDescription`) pada Info.plist dengan teks: "VibeSurveyor memerlukan akses lokasi untuk mencatat koordinat GPS pada setiap foto survei."
3. WHEN izin kamera diberikan dan izin lokasi diberikan, THE VibeSurveyor SHALL mengaktifkan semua fitur secara penuh termasuk kamera, telemetri, dan penyimpanan foto.
4. IF salah satu izin (kamera atau lokasi) belum diberikan saat aplikasi dibuka, THEN THE VibeSurveyor SHALL menampilkan panel informasi yang menjelaskan fungsi masing-masing izin sebelum sistem iOS menampilkan dialog permintaan izin.

---

### Requirement 11: Kompatibilitas Build Zero-Dependency

**User Story:** Sebagai developer, saya ingin proyek dapat dikompilasi secara otomatis melalui GitHub Actions vanilla macOS runner tanpa dependensi eksternal, agar proses build dapat berjalan di lingkungan CI/CD yang bersih tanpa setup tambahan.

#### Kriteria Penerimaan

1. THE VibeSurveyor SHALL menggunakan hanya framework yang termasuk dalam Xcode SDK standar: AVFoundation, CoreLocation, CoreMotion, SwiftUI, UIKit, Foundation.
2. THE VibeSurveyor SHALL tidak mengandung referensi ke CocoaPods, Swift Package Manager pihak ketiga, Node.js, atau Go dalam konfigurasi proyek manapun.
3. THE VibeSurveyor SHALL menargetkan iOS 15.0 sebagai deployment target minimum.
4. THE VibeSurveyor SHALL menggunakan Swift sebagai satu-satunya bahasa pemrograman dalam proyek.
5. THE VibeSurveyor SHALL memiliki struktur file proyek yang dapat dibuild menggunakan perintah `xcodebuild` standar tanpa skrip pra-build tambahan.
