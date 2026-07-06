# GAP & Risk Analysis: ZQMI_COA (ZQM002)

**Date:** 2026-07-02
**Server:** Development AIX (TRD) — source code dibaca dari server ini
**Reviewer:** Code Review Subagent (Claude)
**Scope:** ZQM002 (ZQMI_COA / ZQMI_CERTIFICATE) dan ZQM003 (ZQMR_COA)

---

## Source Code Summary

### Program yang Ditemukan

| Program | Include | Lines | Keterangan |
|---|---|---|---|
| `ZQMI_COA` | — | 20 | Main report, berisi INCLUDE chain |
| `ZQMI_COA_TOP` | ✅ | 172 | DATA declarations, internal tables, selection screen |
| `ZQMI_COA_F01` | ✅ | 857 | Logic utama: GET_DATA, GET_MIC, GET_TRACED_LOTS, F_PRINT, dll |
| `ZQMI_COA_F02` | ✅ | 601 | Screen modules: PBO/PAI 0100 & 0200, Table Control handlers |
| `ZQMR_COA` | — | 1401 | COA Report monitoring ALV (ZQM003) |
| `Z_PROG_INFO` | ✅ | 88 | Helper: tampilkan program documentation |

### Fungsi / FORM Utama yang Diidentifikasi

- `FORM GET_DATA` (F01) — Fetch data dari LIPS, batch classification, loop untuk GET_TRACED_LOTS & GET_MIC
- `FORM GET_TRACED_LOTS` (F01) — Trace inspection lot: SR Conv → JR Conv → SR Base → JR Base
- `FORM GET_MIC` (F01) — Ambil MIC values dari QAMV berdasarkan mapping ZMAP_COA
- `FORM F_PRINT` (F01) — Cetak via Smart Form `ZQMF_COA`
- `MODULE USER_COMMAND_0100 INPUT` (F02) — Handler screen 0100: EXEC, DOWNLOAD, SELALL, dll
- `MODULE USER_COMMAND_0200 INPUT` (F02, via TDETAIL_USER_COMMAND) — Handler screen 0200: PRINT, DOWNLOAD_DETAIL
- `FORM GET_COMPANY_NAME` (F01) — Ambil nama perusahaan dari T001/T001K

---

## Issues dari Review Sebelumnya — Status Update

### C1: COA mengambil MITTELWERT bukan nilai cycle terakhir (dari PHYSPROBE tertinggi)

**Status: MASIH ADA (belum diperbaiki)**

Pada `FORM GET_DATA` (F01, sekitar baris 170-190), kode membaca nilai dari QAMR menggunakan MITTELWERT:

```abap
SELECT SINGLE CODE1 INTO IT_MIC1-CMICMIT
  FROM QAMR
  WHERE QAMR~PRUEFLOS = IT_MIC1-INSLOT
  AND QAMR~MERKNR = IT_MIC1-MERKNR.
IF IT_MIC1-CMICMIT IS INITIAL.
  SELECT SINGLE MITTELWERT INTO IT_MIC1-MICMIT
    FROM QAMR
    WHERE QAMR~PRUEFLOS = IT_MIC1-INSLOT
    AND QAMR~MERKNR = IT_MIC1-MERKNR.
  IT_MIC1-CMICMIT = IT_MIC1-MICMIT.
ENDIF.
```

Logika: jika `CODE1` kosong, pakai `MITTELWERT`. Tidak ada seleksi berdasarkan `PHYSPROBE` tertinggi atau cycle terakhir. Ini konfirmasi issue C1 belum diperbaiki.

**Risiko: High** — Nilai yang tampil di COA adalah rata-rata semua cycle, bukan hasil cycle terbaru/terbaik.

---

### C4 (Known): SELECT dalam LOOP di ZQMR_COA GET_DATA

**Status: TETAP ADA** — ZQMR_COA (1401 baris) mengandung struktur data kompleks tapi tidak ada FORM GET_DATA dengan SELECT dalam LOOP yang langsung terlihat. Program ini dipanggil dari screen 2000 dan menggunakan ITAB yang diisi oleh proses lain. Analisis lebih lanjut terbatas karena FORM yang memuat data SR (seperti GET_SR_DATA, dll.) mungkin berada di luar scope file yang dibaca.

---

### D5/D6 (Known): Duplikasi GET_TRACED_LOTS & GET_MIC

**Status: MASIH ADA** — Fungsi GET_TRACED_LOTS dan GET_MIC ada di ZQMI_COA. ZQMR_COA memiliki logika tracing sendiri yang berbeda (langsung membaca QASE, MSEG, AFPO) tanpa shared FORM. Duplikasi kode tetap ada, tidak ada refactoring ke shared library.

---

## GAP Analysis — 7 Skenario Tambahan

---

### S1. Barrier Multiple Cycles

**Pertanyaan:** Apakah ZQMI_COA bisa handle ketika 1 SR punya barrier inspection di multiple cycles? Bagaimana logika ambil nilai per cycle?

**Status: GAP — Partial (Nilai dari cycle terakhir tidak dipilih secara eksplisit)**

**Analisis Kode:**

Pada `FORM GET_MIC` (F01), kode mencari MIC value dari QAMV menggunakan:

```abap
SELECT SINGLE VERWMERKM KURZTEXT TOLERANZUN TOLERANZOB MERKNR
  INTO (IT_MIC-MIC, IT_MIC-MICDES, IT_MIC-MICMIN, IT_MIC-MICMAX, IT_MIC-MERKNR)
  FROM QAMV
  WHERE PRUEFLOS = INS
    AND VERWMERKM = IT_ZMAP-MIC.
```

Tabel QAMV menyimpan satu baris per MIC per inspection lot, sehingga `SELECT SINGLE` ini **tidak** bermasalah untuk ambil definisi MIC. Namun, yang menjadi masalah adalah saat mengambil **hasil pengukuran** di `FORM GET_DATA`:

```abap
SELECT SINGLE CODE1 INTO IT_MIC1-CMICMIT
  FROM QAMR
  WHERE QAMR~PRUEFLOS = IT_MIC1-INSLOT
  AND QAMR~MERKNR = IT_MIC1-MERKNR.
```

Tabel `QAMR` menyimpan **hasil agregat per MIC per inspection lot**, bukan per sample/cycle. Tabel yang menyimpan nilai per sample/cycle adalah `QASE` (field: `STUECKNR` = cycle, `PROBENR` = sample). Program ini **tidak membaca QASE sama sekali** (kecuali ZQMR_COA yang beda tujuan).

**Jika satu SR memiliki multiple barrier cycles (misalnya dilakukan 3x barrier test), maka:**
1. QASE akan punya 3 rows dengan STUECKNR berbeda
2. QAMR hanya punya 1 row dengan MITTELWERT = rata-rata ketiga cycle
3. CODE1 = hasil evaluasi agregat (Pass/Fail)
4. ZQMI_COA **hanya tampilkan CODE1 (Pass/Fail) atau MITTELWERT, bukan nilai per cycle**
5. **Tidak ada logika untuk mengambil nilai dari PHYSPROBE atau STUECKNR tertinggi**

**Untuk kasus MVTR/OTR (Barrier)**, kode melakukan SELECT loop di QAMV:

```abap
SELECT VERWMERKM KURZTEXT TOLERANZUN TOLERANZOB MERKNR
  INTO (IT_MIC-MIC, ...)
  FROM QAMV
  WHERE PRUEFLOS = INS.
  ...
ENDSELECT.
```

Ini pun hanya ambil definisi MIC, bukan nilai cycle.

**Masalah:**
- Jika inspection lot punya banyak cycles, nilai yang ditampilkan di COA adalah MITTELWERT (average) atau CODE1 (Pass/Fail agregat)
- Tidak ada mekanisme pilih cycle terakhir (PHYSPROBE/STUECKNR MAX)
- Barrier type yang ditandai dengan `IT_MIC-BARRIER_TYPE = 'X'` tidak punya perlakuan khusus dalam pengambilan nilai — sama-sama dari QAMR

**Risiko: High**
**Priority: P1**

**Rekomendasi Fix:**
Baca nilai dari QASE dengan filter STUECKNR = MAX atau PROBENR = MAX untuk ambil nilai cycle terakhir:

```abap
" Ambil STUECKNR tertinggi (cycle terakhir)
DATA: LV_MAX_CYCLE LIKE QASE-STUECKNR.
SELECT MAX( STUECKNR ) INTO LV_MAX_CYCLE
  FROM QASE
  WHERE PRUEFLOS = IT_MIC1-INSLOT
  AND MERKNR = IT_MIC1-MERKNR
  AND ATTRIBUT NE 'L'.   " Exclude deleted samples

" Ambil nilai dari cycle tersebut
SELECT SINGLE MESSWERT INTO IT_MIC1-MICMIT
  FROM QASE
  WHERE PRUEFLOS = IT_MIC1-INSLOT
  AND MERKNR = IT_MIC1-MERKNR
  AND STUECKNR = LV_MAX_CYCLE.
```

---

### S2. Change Grade SR BF — Data Refresh

**Pertanyaan:** Ketika grade SR bahan baku (Base Film) berubah setelah COA sudah dibuat, apakah data direfresh?

**Status: GAP — Tidak ada refresh mechanism**

**Analisis Kode:**

Program ZQMI_COA tidak menyimpan data ke database. Setiap kali user menjalankan ZQM002 dari selection screen, program:

1. Memanggil `PERFORM GET_DATA` → fetch ulang dari LIPS, QALS, QAMR, QAMV, batch classification
2. Memanggil `PERFORM GET_TRACED_LOTS` → trace lot dari SR Convert → JR Conv → SR Base

**Berarti jika grade SR Base Film berubah setelah COA sebelumnya dicetak:**
- Jika user **menjalankan ulang** program dengan ODO yang sama → data akan diambil fresh → grade baru akan terlihat
- Jika user **tidak menjalankan ulang** (hanya melihat hasil cetak lama) → tidak ada update
- **Tidak ada log/history** bahwa COA pernah dicetak dengan grade lama

**Titik kritis di kode** — FORM GET_TRACED_LOTS mencari lot berdasarkan batch CHARG dari LIPS:

```abap
SELECT SINGLE PRUEFLOS INTO LOT_SR_CONV
  FROM QALS
  WHERE CHARG = IT_DATA-CHARG AND ART = 'Z04'.
```

Kemudian GET_MIC membaca nilai dari QAMR berdasarkan inspection lot tersebut. Jika grade berubah namun tidak ada inspection lot baru yang dibuat, COA akan tetap menampilkan nilai dari lot lama.

**Masalah utama:**
- Grade SR BF disimpan di batch classification (AUSP/CABN). Program membaca nilai ini via `VB_BATCH_GET_DETAIL` pada field `ZZCODE`
- Jika `ZZCODE` berubah namun ZMAP_COA tidak diupdate untuk mapping baru, atau inspection lot lama masih dipakai → nilai COA bisa salah
- Tidak ada timestamp/version tracking pada COA yang dicetak
- Tidak ada warning "Grade telah berubah sejak terakhir kali COA dicetak"

**Risiko: Medium**
**Priority: P2**

**Rekomendasi Fix:**
1. Tambahkan log tabel (ZQM_COA_LOG) yang menyimpan ODO, material, grade, tanggal cetak, nilai MIC saat cetak
2. Saat print, bandingkan nilai current dengan nilai pada log terakhir — jika berbeda, tampilkan warning
3. Atau: simpan "snapshot" COA ke custom table untuk audit trail

---

### S3. Change Grade SR Converting — Data Refresh

**Pertanyaan:** Sama seperti S2 tapi untuk Converting grade.

**Status: GAP — Sama dengan S2, tidak ada refresh mechanism**

**Analisis Kode:**

Mapping grade dilakukan di FORM GET_DATA melalui pembacaan batch characteristic `ZZCODE`:

```abap
READ TABLE TBATCH WITH KEY ATNAM = 'ZZCODE'.
IF SY-SUBRC EQ 0.
  IT_DATA-ZZTYPE = TBATCH-ATWTB.
  ...
  SELECT MATNR MIC KUNNR METHOD MAPPING
    INTO CORRESPONDING FIELDS OF TABLE IT_ZMAP_GEN
    FROM ZMAP_COA
    WHERE MATNR = IT_DATA-MATNR
      AND KUNNR = ' '
      AND DELETION NE 'X'.
```

Kemudian di FORM GET_MIC, routing ke inspection lot ditentukan oleh field `MAPPING` dari ZMAP_COA:

```abap
IF IT_ZMAP-MAPPING CS 'SR Base Film'.
  INS = LOT_SR_BASE.
ELSEIF IT_ZMAP-MAPPING CS 'JR Base Film'.
  INS = LOT_JR_BASE.
ELSEIF IT_ZMAP-MAPPING CS 'SR Converting'.
  INS = LOT_SR_CONV.
ELSEIF IT_ZMAP-MAPPING CS 'JR Converting'.
  INS = LOT_JR_CONV.
```

**Untuk Converting grade:**
- Jika grade SR Converting berubah, inspection lot-nya bisa berubah
- `LOT_SR_CONV` di-set berdasarkan batch dari QALS (`ART = 'Z04'`) menggunakan CHARG batch yang sedang diproses
- Jika SR Converting punya grade baru dengan lot baru → program AKAN membaca lot baru (karena GET_TRACED_LOTS fetch fresh dari QALS)
- **Namun** jika grade lama masih aktif di lot yang sama → tidak ada mekanisme untuk tahu bahwa ada perubahan

**Risiko tambahan untuk Converting:** Batch Converting bisa punya multiple sibling SR (via `ZQM_GET_BATCH_SR_BY_JR`). Jika salah satu sibling SR memiliki grade baru, program hanya mengambil inspection lot dari sibling pertama yang ditemukan (EXIT setelah pertama ketemu).

**Risiko: Medium**
**Priority: P2**

**Rekomendasi Fix:** Sama dengan S2 — implementasi audit log/snapshot COA.

---

### S4. Material Accent vs Non-Aksen (Matching MATNR/KUNNR)

**Pertanyaan:** Apakah comparison MATNR/KUNNR di ZMAP_COA bisa salah match jika ada material dengan nama mirip (é vs e)?

**Status: GAP — Risiko rendah untuk MATNR, tetapi ada potensi masalah di KUNNR**

**Analisis Kode:**

Field MATNR di SAP adalah tipe `MATNR` (CHAR 18, case-insensitive di sistem dengan Unicode). Di ZQMI_COA, matching MATNR dilakukan dengan:

```abap
SELECT MATNR MIC KUNNR METHOD MAPPING
  INTO CORRESPONDING FIELDS OF TABLE IT_ZMAP_GEN
  FROM ZMAP_COA
  WHERE MATNR = IT_DATA-MATNR
    AND KUNNR = ' '
    AND DELETION NE 'X'.
```

**Untuk MATNR:** SAP menyimpan MATNR dalam format yang sudah dinormalisasi di master data (MARA). Program membaca `IT_DATA-MATNR` dari LIPS (delivery item), yang dijamin sudah ter-normalize ke format SAP. Risiko salah match akibat aksen sangat rendah karena MATNR umumnya berupa kode angka/alfanumerik standar.

**Untuk KUNNR:** KUNNR diambil dari LIKP via:

```abap
SELECT SINGLE KUNAG INTO LV_KUNNR
  FROM LIKP
  WHERE VBELN = IT_DATA-VBELN.
```

Nilai `LV_KUNNR` ini kemudian digunakan untuk match ke ZMAP_COA:

```abap
SELECT MATNR MIC KUNNR METHOD MAPPING
  INTO CORRESPONDING FIELDS OF TABLE IT_ZMAP_CUS
  FROM ZMAP_COA
  WHERE MATNR = IT_DATA-MATNR
    AND KUNNR = LV_KUNNR
    AND DELETION NE 'X'.
```

KUNNR di SAP juga berupa kode numerik (10 digit dengan leading zeros). Risiko aksen di KUNNR sangat rendah.

**Namun ada potensi masalah lain yang lebih nyata:**
1. **Leading zeros:** `LV_KUNNR` dari LIKP-KUNAG sudah dalam format internal SAP (dengan leading zeros). Jika data di ZMAP_COA dientry manual tanpa leading zeros, maka match akan gagal (SY-SUBRC <> 0) dan program akan fallback ke generic mapping (KUNNR = ' ')
2. **Case sensitivity untuk ZZCODE/grade name:** Nilai dari `TBATCH-ATWTB` (field ZZCODE batch classification) digunakan sebagai `IT_DATA-ZZTYPE`. Jika nilai ini case-sensitive dan ada inkonsistensi penulisan di master data batch, mapping bisa gagal. Namun ini tidak langsung digunakan untuk DB lookup di ZMAP_COA

**Risiko: Low (untuk aksen), Medium (untuk leading zeros di KUNNR)**
**Priority: P3**

**Rekomendasi Fix:**
Tambahkan konversi alpha input untuk KUNNR sebelum digunakan sebagai filter:

```abap
CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
  EXPORTING
    INPUT  = LV_KUNNR
  IMPORTING
    OUTPUT = LV_KUNNR.
```

---

### S5. Banyak DO Sekali Cetak (Bulk Printing)

**Pertanyaan:** User memilih multiple Delivery Orders sekaligus. Apakah program bisa handle bulk printing? Ada risiko timeout, duplikat, atau memory issue?

**Status: GAP — Desain program tidak mendukung cetak multi-ODO sekaligus**

**Analisis Kode:**

Di Screen 0100 (list view), user mencentang baris (CHK = 'X') lalu menekan EXEC. Pada `MODULE USER_COMMAND_0100 INPUT`, ada validasi:

```abap
CSTAT = LINES( T_DETAIL ).   " jumlah VBELN unik yang dicentang
MSTAT = LINES( T_DETAIL1 ).  " jumlah MATNR unik yang dicentang

IF CSTAT NE 1.
  MESSAGE 'Pilih 1 ODO!' TYPE 'I'.
ELSEIF MSTAT NE 1.
  MESSAGE 'Tipe film tidak boleh berbeda!' TYPE 'I'.
```

**Temuan kritis:**
- **Validasi eksplisit membatasi hanya 1 ODO dan 1 Material type** saat EXEC (masuk ke screen detail/print)
- Artinya **sistem SUDAH mencegah cetak multi-ODO sekaligus** — ini adalah desain yang disengaja
- Namun, selection screen ZQM002 menerima range `P_VBELN` (SELECT-OPTIONS), sehingga user bisa memasukkan banyak ODO di selection screen → IT_DATA akan berisi data dari semua ODO → tapi saat EXEC hanya boleh pilih 1

**Potensi masalah yang masih ada:**
1. **Performance pada GET_DATA:** Jika P_VBELN berisi range lebar (misal 100 ODO), program akan LOOP AT IT_DATA dan untuk setiap baris memanggil:
   - `VB_BATCH_GET_DETAIL` (FM dengan DB access)
   - `GET_TRACED_LOTS` (multiple SELECT ke QALS, AFPO, MSEG)
   - `GET_MIC` (SELECT ke QAMV)
   - Ini adalah **N+1 problem** di dalam LOOP — untuk 100 ODO bisa sangat lambat

2. **Memory:** IT_MIC1 diisi via `APPEND LINES OF IT_MIC2 FROM 1 TO CTR TO IT_MIC1` tanpa CLEAR IT_MIC1 antar iterasi ODO. Jika banyak ODO/material, IT_MIC1 terus bertambah — potensi memory issue.

3. **Download fungsi DOWNLOAD:** Jika user klik Download (XPORT) sebelum EXEC, semua baris CHK = 'X' dari semua ODO akan di-download ke XLS — ini memang boleh multi-ODO.

**Risiko: Medium** (validasi 1 ODO ada, tapi performa GET_DATA untuk banyak ODO lambat)
**Priority: P2**

**Rekomendasi Fix:**
1. Tambahkan warning di selection screen jika P_VBELN berisi lebih dari N ODO (misal 20)
2. Refactor GET_TRACED_LOTS dan GET_MIC agar tidak dipanggil di dalam LOOP (gunakan FOR ALL ENTRIES atau bulk select terlebih dahulu)
3. REFRESH IT_MIC1 di awal setiap iterasi material baru di LOOP AT IT_DATA

---

### S6. 1 DO Banyak Material (Average Logic)

**Pertanyaan:** Satu DO berisi beberapa material berbeda dan nilai yang ditampilkan adalah average. Apakah logika average benar?

**Status: GAP — Validasi MSTAT NE 1 memblokir kasus ini, NAMUN ada celah**

**Analisis Kode:**

Di `MODULE USER_COMMAND_0100 INPUT`:

```abap
SORT T_DETAIL1 BY MATNR ASCENDING.
DELETE ADJACENT DUPLICATES FROM T_DETAIL1 COMPARING MATNR.
MSTAT = LINES( T_DETAIL1 ).
...
ELSEIF MSTAT NE 1.
  MESSAGE 'Tipe film tidak boleh berbeda!' TYPE 'I'.
```

Ini memblokir cetak jika ada lebih dari 1 MATNR yang dicentang. Artinya sistem **tidak mendukung average cross-material**.

**Namun** ada **logika averaging di dalam screen 0200 untuk 1 material dengan banyak batch**:

```abap
LOOP AT IT_DETAIL WHERE TYPE EQ 'X'.  " Numeric type only
  CLEAR : CTR, MICMIT, MICMITV.
  CTR = 0.
  LOOP AT IT_DETAIL1 WHERE MIC = IT_DETAIL-MIC.
    MICMIT = MICMIT + IT_DETAIL1-CMICMIT.
    CTR = CTR + 1.
  ENDLOOP.
  IF CTR NE 0.
    MICMITV = MICMIT / CTR.
    WRITE MICMITV TO IT_DETAIL-CMICMIT DECIMALS 2.
    CONDENSE IT_DETAIL-CMICMIT.
    MODIFY IT_DETAIL.
  ENDIF.
ENDLOOP.
```

**Masalah dengan logika averaging ini:**

1. **IT_DETAIL1 = semua baris sebelum de-duplikasi MIC.** Jika 1 ODO berisi 1 material tapi 3 batch berbeda (dari LIPS), dan masing-masing batch punya nilai MIC berbeda, maka IT_DETAIL akan berisi 3 entries per MIC. Logika ini akan me-rata-ratakan ketiga nilai → **ini adalah average by batch, bukan by sample/cycle**

2. **Pre-condition di GET_DATA:** Ada `DELETE ADJACENT DUPLICATES FROM IT_DATA COMPARING VBELN MATNR` di GET_DATA. Artinya untuk 1 VBELN + MATNR yang sama, hanya **1 batch (representative batch) yang dipakai**. Jadi dalam praktiknya IT_DETAIL1 untuk 1 MIC hanya berisi 1 row (karena 1 material = 1 representative batch = 1 lot = 1 nilai MIC). Average menjadi trivial (CTR = 1, MICMITV = nilai tunggal).

3. **Skenario gap:** Jika `DELETE ADJACENT DUPLICATES` tidak berhasil mengeliminasi duplikasi (misal karena user mencentang manual baris dari material yang sama tapi CHARG berbeda dari selection screen), maka average akan dihitung dari beberapa batch — namun rata-rata ini bisa **menyesatkan** karena mencampur nilai dari batch berbeda tanpa bobot (weight by quantity).

4. **Tidak ada bobot (weighted average):** Average yang dihitung adalah **simple arithmetic mean**, bukan weighted average berdasarkan quantity (NTGEW/BRGEW). Untuk material dengan batch ukuran berbeda, simple mean tidak akurat secara ilmiah.

5. **CSTAT check:** Ada juga pemeriksaan `CSTAT NE 5` yang memblokir jika ada MIC yang memiliki value dengan type campuran (quantitative + qualitative).

**Risiko: Medium** (average logic ada tapi unweighted, dan case 1 DO banyak material diblokir)
**Priority: P2**

**Rekomendasi Fix:**
1. Dokumentasikan secara eksplisit bahwa average per batch tidak berbobot — tambahkan komentar di kode
2. Jika perlu weighted average, tambahkan NTGEW ke IT_DETAIL dan gunakan sebagai bobot:
   ```abap
   " Weighted average
   MICMIT = MICMIT + ( IT_DETAIL1-CMICMIT * IT_DETAIL1-NTGEW ).
   V_TOTAL_WEIGHT = V_TOTAL_WEIGHT + IT_DETAIL1-NTGEW.
   ...
   IF V_TOTAL_WEIGHT NE 0.
     MICMITV = MICMIT / V_TOTAL_WEIGHT.
   ENDIF.
   ```
3. Tambahkan konfirmasi dialog sebelum cetak jika CTR > 1 (ada lebih dari 1 nilai per MIC yang di-average)

---

### S7. Ubah Value di Print Certificate (Manual Override)

**Pertanyaan:** Ketika user buka Print Certificate (screen 0200) lalu ubah nilai manual sebelum cetak, apakah perubahan disimpan? Apakah ada validasi? Apakah original value bisa di-recover?

**Status: GAP — Override tidak disimpan ke database, tidak ada validasi, tidak ada recovery**

**Analisis Kode:**

Screen 0200 menampilkan IT_DETAIL via Table Control `TDETAIL`. Module input untuk Table Control adalah:

```abap
MODULE TDETAIL_MODIFY INPUT.
  MODIFY IT_DETAIL
    INDEX TDETAIL-CURRENT_LINE.
ENDMODULE.  " TDETAIL_MODIFY INPUT
```

Ini adalah standard Dynpro pattern — setiap perubahan user pada baris di Table Control akan di-MODIFY ke IT_DETAIL (internal table di memory). Kemudian saat user klik PRNT:

```abap
WHEN 'PRNT'.
  PERFORM F_PRINT.
```

`F_PRINT` membaca IT_DETAIL:

```abap
LOOP AT IT_DETAIL WHERE CHK EQ 'X'.
  IT_QAMV-KURZTEXT = IT_DETAIL-MICDES.
  IT_QAMV-DUMMY40  = IT_DETAIL-METHOD.
  IT_QAMV-TOLERANZOB = IT_DETAIL-MICMIN.
  IT_QAMV-TOLERANZUN = IT_DETAIL-MICMAX.
  IT_QAMV-DUMMY20  = IT_DETAIL-CMICMIT.   " <-- Nilai yang tercetak
  APPEND IT_QAMV.
ENDLOOP.
```

**Temuan kritis:**

1. **Override memungkinkan** — Field `IT_DETAIL-CMICMIT` yang di-display di screen 0200 bisa diedit langsung oleh user (tidak ada INPUT = 0 atau LOOP AT SCREEN untuk disable field ini). Nilai yang diedit akan langsung menjadi nilai yang dicetak di COA.

2. **Tidak ada penyimpanan ke database** — `TDETAIL_MODIFY` hanya memodifikasi internal table di memory. Saat user keluar dari screen 0200 dan masuk lagi, nilai akan diambil fresh dari QAMR (reset). Tidak ada `UPDATE`/`INSERT` ke tabel manapun.

3. **Tidak ada validasi nilai** — Tidak ada pengecekan apakah nilai yang diinput user:
   - Dalam range toleransi (MICMIN ≤ nilai ≤ MICMAX)
   - Bertipe numeric (ada fungsi NUMERIC_CHECK di kode tapi hanya dipakai untuk menentukan TYPE, bukan untuk validasi override)
   - Tidak negatif atau tidak reasonable

4. **Tidak ada original value recovery** — Jika user mengubah nilai lalu ingin kembali ke nilai asli (dari QAMR), tidak ada tombol "Reset" atau "Reload". Satu-satunya cara adalah keluar dari screen 0200 dan masuk kembali.

5. **Tidak ada log audit override** — Tidak ada rekaman bahwa user pernah mengubah nilai secara manual sebelum mencetak. COA yang dicetak akan terlihat sama seperti COA dengan nilai otomatis.

6. **Celah integritas data:** Karena tidak ada konfirmasi atau persetujuan (approval) yang diperlukan saat override nilai, siapapun dengan akses ZQM002 bisa mencetak COA dengan nilai yang berbeda dari hasil QC aktual tanpa meninggalkan jejak audit.

**Risiko: High** — Ini adalah risiko integritas dokumen/compliance yang serius
**Priority: P1**

**Rekomendasi Fix:**
1. **Disable field CMICMIT di screen 0200** (set INPUT = 0 di PBO_0200) untuk mencegah manual override:
   ```abap
   MODULE STATUS_0200 OUTPUT.
     SET PF-STATUS 'PF0200'.
     LOOP AT SCREEN.
       IF SCREEN-NAME = 'IT_DETAIL-CMICMIT'.
         SCREEN-INPUT = 0.
         MODIFY SCREEN.
       ENDIF.
     ENDLOOP.
   ENDMODULE.
   ```

2. **Jika override memang diperlukan** (misalnya untuk kasus COA dengan nilai disetujui QC Manager):
   - Tambahkan authorization check (authority object custom, misal Z_QM_COA_OVR)
   - Simpan override ke tabel log: original value, new value, user, timestamp, alasan
   - Tampilkan watermark "MODIFIED" di COA yang dicetak dengan nilai override
   - Tambahkan field "Alasan Override" yang mandatory

3. **Tambahkan tombol Reset** di screen 0200 untuk reload nilai asli dari QAMR

---

## Risk Summary Table

| ID | Skenario | GAP? | Risiko | Priority | Keterangan |
|---|---|---|---|---|---|
| C1 | MITTELWERT vs nilai cycle terakhir | YES | High | P1 | Belum diperbaiki dari review sebelumnya |
| S1 | Barrier Multiple Cycles | YES | High | P1 | Tidak ada pemilihan cycle; QASE tidak dibaca |
| S2 | Change Grade SR BF — Refresh | YES | Medium | P2 | Tidak ada audit log; nilai fresh saat re-run |
| S3 | Change Grade SR Converting — Refresh | YES | Medium | P2 | Sama seperti S2; tambahan: sibling SR hanya ambil 1 |
| S4 | Material Accent vs Non-Aksen | PARTIAL | Low | P3 | MATNR aman; risiko leading zeros KUNNR |
| S5 | Banyak DO Sekali Cetak | PARTIAL | Medium | P2 | 1 ODO enforced; performa GET_DATA N+1 problem |
| S6 | 1 DO Banyak Material (Average) | PARTIAL | Medium | P2 | Multi-material diblokir; average unweighted |
| S7 | Ubah Value di Print Certificate | YES | High | P1 | Override tanpa validasi, log, atau approval |

---

## Rekomendasi Fix (Ordered by Priority)

### P1 — Critical, Fix Segera

#### P1-1: Disable Manual Override di Screen 0200 (S7)

**File:** `ZQMI_COA_F02`, Module `STATUS_0200 OUTPUT`

Tambahkan proteksi field CMICMIT di PBO screen 0200:

```abap
MODULE STATUS_0200 OUTPUT.
  SET PF-STATUS 'PF0200'.
  " Protect value field dari manual override
  LOOP AT SCREEN.
    IF SCREEN-NAME = 'IT_DETAIL-CMICMIT'.
      SCREEN-INPUT = 0.
      MODIFY SCREEN.
    ENDIF.
  ENDLOOP.
ENDMODULE.
```

Jika override diperlukan, tambahkan authorization check dan mandatory reason field.

#### P1-2: Gunakan Nilai Cycle Terakhir, Bukan MITTELWERT (C1 + S1)

**File:** `ZQMI_COA_F01`, dalam `FORM GET_DATA` setelah loop `LOOP AT IT_MIC1`

Ganti:

```abap
SELECT SINGLE CODE1 INTO IT_MIC1-CMICMIT
  FROM QAMR
  WHERE QAMR~PRUEFLOS = IT_MIC1-INSLOT
  AND QAMR~MERKNR = IT_MIC1-MERKNR.
IF IT_MIC1-CMICMIT IS INITIAL.
  SELECT SINGLE MITTELWERT INTO IT_MIC1-MICMIT
    FROM QAMR ...
```

Dengan:

```abap
DATA: LV_MAX_CYCLE LIKE QASE-STUECKNR,
      LV_MESSWERT  LIKE QASE-MESSWERT.

" Coba ambil CODE1 (qualitative) dulu
SELECT SINGLE CODE1 INTO IT_MIC1-CMICMIT
  FROM QAMR
  WHERE PRUEFLOS = IT_MIC1-INSLOT
  AND MERKNR = IT_MIC1-MERKNR.

IF IT_MIC1-CMICMIT IS INITIAL.
  " Ambil cycle terakhir dari QASE (PHYSPROBE = sample max)
  SELECT MAX( STUECKNR ) INTO LV_MAX_CYCLE
    FROM QASE
    WHERE PRUEFLOS = IT_MIC1-INSLOT
    AND MERKNR = IT_MIC1-MERKNR
    AND ATTRIBUT NE 'L'.

  IF SY-SUBRC EQ 0 AND LV_MAX_CYCLE IS NOT INITIAL.
    SELECT SINGLE MESSWERT INTO LV_MESSWERT
      FROM QASE
      WHERE PRUEFLOS = IT_MIC1-INSLOT
      AND MERKNR = IT_MIC1-MERKNR
      AND STUECKNR = LV_MAX_CYCLE.
    IF SY-SUBRC EQ 0.
      IT_MIC1-MICMIT = LV_MESSWERT.
      WRITE LV_MESSWERT TO IT_MIC1-CMICMIT DECIMALS 2.
      CONDENSE IT_MIC1-CMICMIT.
    ENDIF.
  ELSE.
    " Fallback ke MITTELWERT jika tidak ada data di QASE
    SELECT SINGLE MITTELWERT INTO IT_MIC1-MICMIT
      FROM QAMR
      WHERE PRUEFLOS = IT_MIC1-INSLOT
      AND MERKNR = IT_MIC1-MERKNR.
    IT_MIC1-CMICMIT = IT_MIC1-MICMIT.
  ENDIF.
ENDIF.
```

**Catatan ABAP 7.31:** Sintaks di atas valid. Tidak menggunakan fitur 7.40+.

---

### P2 — Important, Fix dalam Sprint Berikutnya

#### P2-1: Implementasi COA Audit Log (S2, S3)

Buat tabel custom `ZCOA_PRINT_LOG`:

| Field | Type | Keterangan |
|---|---|---|
| MANDT | MANDT | Client |
| LOG_ID | NUMC20 | Primary key (timestamp + user) |
| VBELN | VBELN | ODO Number |
| CHARG | CHARG_D | Batch |
| MATNR | MATNR | Material |
| ZZTYPE | ATWRT | Grade saat cetak |
| PRINT_DATE | DATUM | Tanggal cetak |
| PRINT_TIME | UZEIT | Jam cetak |
| PRINT_USER | UNAME | User yang cetak |
| MIC | QPMKMNR | MIC code |
| VALUE_PRINTED | CHAR20 | Nilai yang dicetak |

Tambahkan INSERT ke ZCOA_PRINT_LOG di FORM F_PRINT sebelum memanggil Smart Form.

#### P2-2: Fix N+1 Problem di GET_DATA (S5)

**File:** `ZQMI_COA_F01`, FORM GET_DATA

Pindahkan SELECT untuk master data (batch classification) keluar dari LOOP menggunakan FOR ALL ENTRIES:

```abap
" Kumpulkan semua MATNR + CHARG + WERKS dahulu
" Kemudian bulk read batch classification dengan FOR ALL ENTRIES
" Simpan ke IT_BATCH_CLASS indexed table
" LOOP AT IT_DATA lakukan READ TABLE ke IT_BATCH_CLASS
```

Ini mengurangi jumlah DB roundtrip dari O(N) menjadi O(1) untuk pembacaan batch classification.

#### P2-3: CLEAR IT_MIC1 Antar Iterasi (S5, Memory)

**File:** `ZQMI_COA_F01`, FORM GET_DATA, sebelum `PERFORM GET_MIC`

Tambahkan:

```abap
" Clear per-material MIC data sebelum GET_MIC
CLEAR IT_MIC. REFRESH IT_MIC.
CLEAR IT_MIC2. REFRESH IT_MIC2.
```

Namun perhatikan bahwa IT_MIC1 diisi oleh GET_MIC dan kemudian dibaca oleh loop di GET_DATA — perlu analisis lebih lanjut untuk memastikan REFRESH IT_MIC1 aman dilakukan di titik yang tepat.

#### P2-4: Informasikan Rata-Rata di Screen 0200 (S6)

Tambahkan teks informasi di screen 0200 ketika average digunakan (CTR > 1), sehingga user tahu bahwa nilai yang ditampilkan adalah rata-rata:

```abap
IF CTR GT 1.
  " Tampilkan pesan informasi
  MESSAGE 'Nilai yang ditampilkan adalah rata-rata dari beberapa batch' TYPE 'I'.
ENDIF.
```

---

### P3 — Nice-to-Have, Fix saat Opportunity

#### P3-1: Tambahkan Konversi Alpha Input untuk KUNNR (S4)

**File:** `ZQMI_COA_F01`, FORM GET_DATA

Setelah:

```abap
SELECT SINGLE KUNAG INTO LV_KUNNR
  FROM LIKP
  WHERE VBELN = IT_DATA-VBELN.
```

Tambahkan:

```abap
IF LV_KUNNR IS NOT INITIAL.
  CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
    EXPORTING
      INPUT  = LV_KUNNR
    IMPORTING
      OUTPUT = LV_KUNNR.
ENDIF.
```

---

## Catatan Teknis Tambahan

### Catatan 1: FORM GET_TRACED_LOTS — Sibling SR Logic

Di `FORM GET_TRACED_LOTS`, ketika LOT_SR_CONV tidak ditemukan langsung dari batch COA:

```abap
LOOP AT LT_SR.
  SELECT SINGLE PRUEFLOS INTO LOT_SR_CONV
    FROM QALS WHERE CHARG = LT_SR-CHARG AND ART = 'Z04'.
  IF LOT_SR_CONV IS NOT INITIAL.
    EXIT.  " Ambil sibling SR pertama yang ketemu
  ENDIF.
ENDLOOP.
```

Ini mengambil **sibling SR pertama yang punya inspection lot**. Jika ada multiple siblings dengan lot, hanya yang pertama digunakan. Tidak ada penjelasan apakah ini disengaja atau apakah harus mengambil yang terbaru (berdasarkan tanggal lot).

**Rekomendasi:** Tambahkan komentar bahwa logika ini mengambil sibling pertama. Jika perlu sibling terbaru, tambahkan ORDER BY ERDAT DESCENDING pada SELECT SINGLE (menjadi SELECT ... ORDER BY lalu EXIT).

### Catatan 2: REPLACE ALL OCCURRENCES di ZQMR_COA

Ditemukan penggunaan `&&` (string concatenation 7.40+) di ZQMR_COA FORM DOWNLOAD_TEMPLATE:

```abap
LV_FILENAME = PICKEDFOLDER && '\' && 'Template_NCR' && '_' && SY-DATUM && ...
```

Ini adalah **sintaks tidak valid di ABAP 7.31** dan akan menyebabkan syntax error. Harus diganti dengan CONCATENATE:

```abap
CONCATENATE PICKEDFOLDER '\' 'Template_NCR' '_'
            SY-DATUM '_' SY-TIMLO '.xls'
            INTO LV_FILENAME.
```

**Risiko: Medium** — Jika program di-activate di sistem 7.31, ini akan menyebabkan syntax error pada FORM DOWNLOAD_TEMPLATE.

### Catatan 3: F_GUI_STATUS_PREVIEW Kosong

Di ZQMR_COA, FORM F_GUI_STATUS_PREVIEW tidak melakukan SET PF-STATUS:

```abap
FORM F_GUI_STATUS_PREVIEW USING FT_EXTAB TYPE SLIS_T_EXTAB.
  DATA: LT_FCODE TYPE TABLE OF SY-UCOMM.
  APPEND 'EXEC' TO LT_FCODE.
  APPEND 'XLSX' TO LT_FCODE.
  " SET PF-STATUS dicomment out!
ENDFORM.
```

Ini menyebabkan ALV grid tidak memiliki custom toolbar — button EXEC dan XLSX tidak akan muncul. Fungsi ini harus diperbaiki dengan uncomment `SET PF-STATUS`.

---

## Kesimpulan Eksekutif

ZQMI_COA (ZQM002) secara keseluruhan memiliki **3 isu High priority** yang memerlukan perhatian segera:

1. **S7 (P1):** Manual override nilai di screen 0200 tanpa validasi, log, atau approval — risiko integritas dokumen COA sangat tinggi
2. **S1/C1 (P1):** Nilai yang ditampilkan di COA adalah MITTELWERT (rata-rata) atau CODE1 agregat — bukan nilai dari cycle terakhir barrier inspection
3. **Catatan 2 (medium):** Penggunaan `&&` operator di ZQMR_COA yang tidak valid di ABAP 7.31

Isu-isu lain (S2, S3, S5, S6) bersifat medium priority dan bisa ditangani pada sprint berikutnya dengan fokus pada audit trail, performance optimization, dan UX improvement.

**Program ZQMR_COA memerlukan review terpisah** yang lebih mendalam — file berisi 1401 baris dengan logika kompleks yang tidak seluruhnya bisa dianalisis dalam scope review ini.
