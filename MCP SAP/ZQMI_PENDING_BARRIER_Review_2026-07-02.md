# Code Review: ZQMI_PENDING_BARRIER (ZQM004)
**Date:** 2026-07-02  
**Reviewer:** Claude — SAP ABAP Consultant  
**Source:** Sandbox New Company (TRS / 192.168.6.243)  
**Line Count:** ~1900+ baris (119,286 chars)  
**Author:** William (11-06-2026), edits by Antigravity

---

## Deskripsi Program

ZQMI_PENDING_BARRIER adalah program untuk mengelola inspeksi barrier (MVTR/OTR) pada Slitt Roll. Program memiliki 2 mode utama:
- **Pending List mode**: Menampilkan daftar SR yang memerlukan inspeksi barrier (dari QM inspection lot)
- **Upload mode**: Upload hasil inspeksi barrier dari file tab-delimited, kemudian melakukan Result Recording dan Usage Decision otomatis ke SAP QM

---

## Update vs Sesi Review Sebelumnya

| Issue Sebelumnya | Status Saat Ini |
|---|---|
| Hardcoded roll `C1 RPA 018 001` di PBO_0100 | ✅ **SUDAH DIHAPUS** — tidak ada di kode saat ini |
| DO 80000 TIMES busy-wait di PROCESS_DELAYING | ✅ **SUDAH DIPERBAIKI** — sekarang hanya `WAIT UP TO 1 SECONDS.` |
| FORM CONFIRMATION truncated/incomplete | ✅ **SUDAH LENGKAP** — ada placeholder comment di tengah tapi kode tetap berlanjut |

---

## Strengths

1. **Arsitektur alur data yang solid**: GET_INITIAL_DATA → POPULATE_INSPECTION_DATA → CONFIRMATION → RESULT_RECORDING → USAGE_DECISION — tanggung jawab tiap form jelas.
2. **Batch cache ZQM_GET_BATCH_JR_BY_SR** — `LT_BATCH_CACHE` mencegah panggilan FM berulang untuk JR yang sama.
3. **LAST_VALUE logic benar** — Ambil VALUE4→3→2→1 sudah sesuai requirement "last cycle".
4. **Validasi sekuensial di CONFIRMATION** — VALUE harus diisi berurutan (VALUE1 → VALUE2 → dst), disertai pesan error yang jelas.
5. **Validasi previous TIMES di CONFIRMATION** — Cek apakah times sebelumnya sudah diinspeksi dan tidak dalam status NO/NG/PASS sebelum allow times baru.
6. **Cek cross-MIC closure** — Jika WVTR sudah FAIL, OTR otomatis tertutup (dan sebaliknya). Sesuai business rule.
7. **CANCEL_UD via BDC** — Memanggil QA12 dengan BDC, membaca MESSTAB untuk deteksi error.
8. **Error handling RESULT_RECORDING** — Menggunakan RETURNTABLE_BAPI (lebih lengkap dari BAPIRET2 saja), dengan pengabaian Q5/026 yang tepat.
9. **Rollback on error** — `BAPI_TRANSACTION_ROLLBACK` dipanggil jika RESULT_RECORDING gagal.
10. **Progress Indicator** — SAPGUI_PROGRESS_INDICATOR di setiap fase proses (collecting, uploading, UD).
11. **Penggunaan FOR ALL ENTRIES** — Bulk read dari QALS, QAMV, QASE, MCH1/AUSP sudah menggunakan FOR ALL ENTRIES dengan benar.
12. **ZMAP_TYPE untuk estimasi tanggal** — Konfigurasi hari estimasi per type inspeksi fleksibel dari tabel ZMAP_TYPE.

---

## Issues

### 🔴 Critical (Must Fix)

---

#### ~~C1. USAGE_DECISION: Filter `HAS_UD NE 'X'`~~ — Desain Sudah Benar ✅

**Form:** `USAGE_DECISION`  
**Kode:**
```abap
DELETE IT_INSPECTION WHERE ERR EQ 'X' OR BOX EQ '' OR PRUEFLOS IS INITIAL OR HAS_UD NE 'X'.
```

**Klarifikasi (user feedback):** Filter `HAS_UD NE 'X'` ini **by design dan benar**. Alurnya adalah:
- Jika lot sudah punya UD sebelumnya → Cancel UD → re-apply UD berdasarkan nilai cycle terbaru
- Jika lot belum pernah punya UD → tidak perlu proses UD di sini (Result Recording saja sudah cukup untuk tahap ini)

UD hanya diproses ulang ketika ada UD sebelumnya yang perlu di-override. Ini sesuai dengan alur bisnis barrier inspection. **Issue ini dicabut dari daftar Critical.**

---

#### C1. Operator `&&` Tidak Valid di ABAP 7.31 (Potential Compile Error)

**Forms:** `GET_DATA_PREVIEW`, `CONFIRMATION`, dan beberapa form lain  
**Kode bermasalah:**
```abap
V_CODEWVTR = 'S' && ITAB-MATNR+2(3) && 'WVTR'.
V_CODEOTR  = 'S' && ITAB-MATNR+2(3) && 'OTR'.
V_POSISI = '|' && ITAB-POSISI && '|'.
LV_ROLL_JR_TEMP = LV_ROLL_JR_TEMP && ' ' && LV_STR.
```

**Jumlah penggunaan:** 28 occurrence `&&` di seluruh program.

**Masalah:** Operator `&&` untuk string concatenation tersedia mulai **ABAP 7.40**. Di ABAP 7.31 (sistem TRD/TRS), ini adalah **syntax error**. Program seharusnya tidak bisa diaktivasi.

> Jika program ini ternyata sudah aktif di Sandbox, kemungkinan besar SP level spesifik NW 7.31 di sana memiliki backport tertentu. Namun ini tetap berisiko karena **behavior production mungkin berbeda** jika transport ke sistem 7.31 lain.

**Fix:** Ganti semua `&&` dengan `CONCATENATE`:
```abap
" Ganti:
V_CODEWVTR = 'S' && ITAB-MATNR+2(3) && 'WVTR'.
" Jadi:
CONCATENATE 'S' ITAB-MATNR+2(3) 'WVTR' INTO V_CODEWVTR.

" Ganti:
V_POSISI = '|' && ITAB-POSISI && '|'.
" Jadi:
CONCATENATE '|' ITAB-POSISI '|' INTO V_POSISI.
```

---

#### C2. Konflik Multi-Sampel Barrier Per JR — Tidak Ada Deteksi

**COA Project.md Requirement:**  
> "Jika terdapat lebih dari satu hasil inspeksi barrier pada sampel yang berbeda dalam satu Jumbo Roll yang sama, sistem harus mendeteksi kondisi tersebut dan menampilkan validasi."

**Status:** ❌ **Belum diimplementasi sama sekali.**

**Analisis Kode:**  
Dalam `USAGE_DECISION`, program DELETE ADJACENT DUPLICATES berdasarkan PRUEFLOS saja, artinya hanya mengambil 1 record per lot. Tidak ada pengecekan apakah 1 JR memiliki >1 sampel SR dengan barrier lot berbeda.

Dalam `GET_DATA_PREVIEW`, saat `ZQM_GET_BATCH_SR_BY_JR` dipanggil, program mengambil semua SR dari JR yang sama (di `LT_SR_ALL`). Tapi tidak ada logika untuk mendeteksi konflik jika dua SR dari JR yang sama keduanya punya inspection lot aktif.

**Dampak:** Jika QA menginspeksi 2 SR berbeda dari JR yang sama sebagai sampel, kedua hasil akan diproses **tanpa warning**. Nilai yang "menang" adalah yang terakhir diproses (urutan file/LOOP), bukan berdasarkan pilihan QA.

**Fix:** Di `CONFIRMATION` atau `GET_DATA_PREVIEW`, tambahkan:
```abap
" Deteksi: untuk setiap JR, apakah ada >1 PRUEFLOS yang berbeda?
DATA: LT_CONFLICT TYPE TABLE OF TY_JR_PRUEFLOS,
      LS_CONFLICT LIKE LINE OF LT_CONFLICT.
LOOP AT ITAB WHERE BOX = 'X' AND ERR <> 'X'.
  " Collect CHARGJR → PRUEFLOS mapping
ENDLOOP.
" Sort by CHARGJR
" Delete duplicates by CHARGJR
" Check if any CHARGJR remains with >1 PRUEFLOS → popup warning
IF conflict found:
  CALL FUNCTION 'POPUP_TO_CONFIRM'
    EXPORTING TEXT_QUESTION = 'JR XXX has multiple barrier samples. Select one:'
```

---

#### C3. Overwrite ke Semua SR Sibling Tidak Diimplementasi

**COA Project.md Requirement:**  
> "Setelah hasil dipilih, seluruh Slitt Roll dalam Jumbo Roll yang sama akan menggunakan nilai baru tersebut, dan sistem secara otomatis memperbarui (overwrite) hasil inspeksi sebelumnya."

**Status:** ❌ **Belum diimplementasi.**

**Analisis Kode:**  
`RESULT_RECORDING` hanya memproses lot yang ada di `IT_RECORD` (lot yang dipilih user di grid). `USAGE_DECISION` hanya memproses `IT_INSPECTION` yang berasal dari ITAB yang sama.

Tidak ada FORM atau logika yang:
1. Mencari semua SR sibling dari JR yang sama via `ZQM_GET_BATCH_SR_BY_JR`
2. Menemukan inspection lot masing-masing sibling
3. Meng-overwrite value dan UD ke semua sibling

**Dampak:** Setelah QA mengupload 1 SR sebagai sampel, **SR lain dari JR yang sama tidak mendapat nilai barrier**. COA untuk SR lain tersebut akan kosong di kolom barrier.

**Fix:** Setelah RESULT_RECORDING dan USAGE_DECISION selesai untuk sampel yang dipilih, tambahkan FORM PROPAGATE_TO_SIBLINGS:
```abap
FORM PROPAGATE_TO_SIBLINGS.
  LOOP AT ITAB WHERE BOX = 'X' AND ERR <> 'X'.
    " 1. Ambil semua SR dari JR yang sama
    CALL FUNCTION 'ZQM_GET_BATCH_SR_BY_JR'
      EXPORTING CHARGJR = ITAB-CHARGJR
      TABLES T_SR = LT_SIBLING_SR.
    " 2. Untuk setiap sibling (bukan sampel yang sudah diproses)
    LOOP AT LT_SIBLING_SR WHERE CHARG NE ITAB-CHARG.
      " 3. Cari inspection lot sibling
      " 4. CANCEL_UD, RESULT_RECORDING, USAGE_DECISION dengan nilai yang sama
    ENDLOOP.
  ENDLOOP.
ENDFORM.
```

---

### 🟡 Important (Should Fix)

---

#### I1. SELECT dalam LOOP di POPULATE_INSPECTION_DATA dan FORM REFRESH

**Form:** `POPULATE_INSPECTION_DATA` dan `REFRESH`  
**Kode bermasalah:**
```abap
" POPULATE_INSPECTION_DATA:
LOOP AT IT_INSP_DAT INTO WA_INSP_DAT WHERE ...
  SELECT QASE~PRUEFLOS MERKNR ... APPENDING CORRESPONDING FIELDS OF TABLE IT_COMPARE
  FROM QASE JOIN QALS ON ...
  WHERE QASE~PRUEFLOS EQ WA_INSP_DAT-INSPLOT.   " <-- SELECT DALAM LOOP
ENDLOOP.

" REFRESH (sama polanya):
LOOP AT IT_INSP_DAT INTO WA_INSP_DAT.
  SELECT QASE~... APPENDING CORRESPONDING FIELDS OF TABLE IT_COMPARE
  FROM QASE JOIN QALS ON ...
  WHERE QASE~PRUEFLOS EQ WA_INSP_DAT-INSPLOT.   " <-- SELECT DALAM LOOP
ENDLOOP.
```

**Masalah:** REFRESH dipanggil setelah setiap operasi (setelah RESULT_RECORDING dan USAGE_DECISION). Dengan N rows di IT_INSP_DAT, ini menghasilkan N×2 SELECT ke QASE tiap kali REFRESH. Untuk 100 SR, itu 200 DB queries per satu tombol SUBMIT.

**Fix:** Pre-fetch IT_COMPARE menggunakan FOR ALL ENTRIES sebelum loop:
```abap
IF IT_INSP_DAT[] IS NOT INITIAL.
  SELECT QASE~PRUEFLOS MERKNR PROBENR ...
    APPENDING CORRESPONDING FIELDS OF TABLE IT_COMPARE
    FROM QASE
    JOIN QALS ON QALS~PRUEFLOS = QASE~PRUEFLOS
    FOR ALL ENTRIES IN IT_INSP_DAT
   WHERE QASE~PRUEFLOS = IT_INSP_DAT-INSPLOT.
ENDIF.
```

---

#### I2. FORM GET_INSPECTION Menggunakan SELECT...ENDSELECT (Cursor-Based Loop)

**Form:** `GET_INSPECTION`  
**Kode bermasalah:**
```abap
SELECT QALS~PRUEFLOS QALS~KTEXTLOS ... INTO (WA_INSP_DAT-INSPLOT, ...)
  FROM QALS
  JOIN QAMV ON ...
  JOIN QASE ON ...
  JOIN QASR ON ...
  JOIN QAPP ON ...
 WHERE QALS~CHARG = P_CHARGSR
   AND QALS~KTEXTLOS <> ''.
  " ... processing per row ...
  APPEND WA_INSP_DAT TO IT_INSP_DAT.
ENDSELECT.
```

**Masalah:** `SELECT...ENDSELECT` adalah cursor-based loop yang deprecated dan buruk performanya di SAP. Ini juga dipanggil DARI DALAM LOOP (di `POPULATE_INSPECTION_DATA` dan `REFRESH`), menjadikannya nested DB cursor.

**Fix:** Ubah ke `SELECT INTO TABLE` kemudian loop internal:
```abap
DATA: LT_INSP_RAW TYPE TABLE OF TY_INSP_RAW.
SELECT QALS~PRUEFLOS QALS~KTEXTLOS ...
  INTO TABLE LT_INSP_RAW
  FROM QALS JOIN QAMV ...
 WHERE QALS~CHARG = P_CHARGSR.

LOOP AT LT_INSP_RAW INTO LW_INSP_RAW.
  " ... processing ...
ENDLOOP.
```

Kemudian, ubah pemanggilan GET_INSPECTION dari LOOP menjadi bulk: kumpulkan semua CHARGSR dulu, baru panggil 1x GET_INSPECTION dengan FOR ALL ENTRIES.

---

#### I3. CONFIRMATION: Employee Number Hardcoded Plant 'TTE' + Workcenter 'QA-Z04'

**Form:** `CONFIRMATION`  
**Kode bermasalah:**
```abap
CALL FUNCTION 'CR_PERSONS_OF_WORKCENTER'
  EXPORTING
    ARBPL = 'QA-Z04'
    WERKS = 'TTE'
    DATE  = SY-DATUM
  TABLES
    OUT_PERSONS = PERSONNEL.
```

**Masalah:** Plant `TTE` dan workcenter `QA-Z04` hardcoded. Jika program digunakan untuk plant lain, atau nama workcenter berubah, validasi employee number akan selalu gagal (semua NIK ditolak) dan upload tidak bisa dilakukan.

**Fix:** Ambil dari parameter program atau dari ZMAP_TYPE:
```abap
" Di selection screen atau ZMAP_TYPE:
" ARBPL dan WERKS bisa dikonfigurasi
SELECT SINGLE ... FROM ZMAP_TYPE WHERE PROG = SY-REPID AND TYPE = 'BARRIER' AND OPT = 'WORKCENTER'.
CALL FUNCTION 'CR_PERSONS_OF_WORKCENTER'
  EXPORTING
    ARBPL = WA_ZMAP_TYPE-VALUE   " Dari config
    WERKS = WA_ZMAP_TYPE-TEXT1   " Dari config
```

---

#### I4. FORM GET_DATA_PREVIEW: Ekstraksi POSISI dan TIMES dari Roll Name via String Parse — Fragile

**Form:** `GET_DATA_PREVIEW`  
**Kode bermasalah:**
```abap
SPLIT ITAB-ROLL AT SPACE INTO TABLE LT_ROLL_PARTS.
DESCRIBE TABLE LT_ROLL_PARTS LINES LV_PART_COUNT.
IF LV_PART_COUNT >= 7.
  READ TABLE LT_ROLL_PARTS INTO LV_ROLL_PART INDEX 5.  " POSISI di word ke-5
  LV_LEN = STRLEN( LV_ROLL_PART ) - 1.
  IF LV_LEN >= 0.
    ITAB-POSISI = LV_ROLL_PART+LV_LEN(1).             " Karakter terakhir word ke-5
  ENDIF.
  READ TABLE LT_ROLL_PARTS INTO LV_ROLL_PART INDEX 7.  " TIMES di word ke-7
ENDIF.
```

**Masalah:** Logic ini mengasumsikan format spesifik nama roll (kata ke-5 mengandung posisi, kata ke-7 adalah TIMES). Jika format nama roll berubah atau ada data tidak konsisten, posisi dan times tidak akan ter-parse dengan benar → data diam-diam salah.

**Dampak:** POSISI yang salah menyebabkan salah mapping ke inspection lot → nilai diupload ke lot yang salah → kerusakan data.

**Fix:** Ambil POSISI dari AUSP (batch characteristics ZZNOMORROLL) yang sudah ada, atau validasi lebih ketat bahwa format roll sudah sesuai sebelum parsing.

---

#### I5. `STRLEN()` Tidak Valid di ABAP 7.31

**Form:** `GET_DATA_PREVIEW`  
**Kode bermasalah:**
```abap
LV_LEN = STRLEN( LV_ROLL_PART ) - 1.
```

**Masalah:** `STRLEN()` dengan tanda kurung adalah syntax ABAP 7.40+. Di ABAP 7.31, harus menggunakan:
```abap
CALL FUNCTION 'STRING_LENGTH'
  EXPORTING TEXT = LV_ROLL_PART
  IMPORTING STRLEN = LV_LEN.
LV_LEN = LV_LEN - 1.
```
Atau menggunakan `DESCRIBE FIELD LV_ROLL_PART LENGTH LV_LEN IN CHARACTER MODE.`

---

#### I6. DATA Declarations Inline dalam FORM (7.31 Risk)

**Forms:** `RESULT_RECORDING`, `CONFIRMATION`  
**Kode bermasalah:**
```abap
FORM RESULT_RECORDING.
  "Collect Data Result Recording
  DATA : V_NEXT_TIMES TYPE I.
  DATA : RETURNTABLE_BAPI TYPE TABLE OF BAPIRET2 WITH HEADER LINE.
  ...
  LOOP AT ITAB WHERE ...
    CLEAR: V_COLUMN,V_NEXT_TIMES.
    DATA L_TMP_MERKNR TYPE QMERKNR.   " <-- DATA di dalam LOOP
    L_TMP_MERKNR = ITAB-MERKNR.
```

**Masalah:** `DATA L_TMP_MERKNR` di dalam LOOP. Meskipun di ABAP semua DATA declarations diekspansi ke awal FORM (compile-time), mendeklarasikan DATA di dalam LOOP adalah practice buruk yang bisa menyebabkan confusion dan variable tidak ter-CLEAR antar iterasi.

**Fix:** Pindahkan semua DATA declarations ke awal FORM, sebelum LOOP pertama.

---

### 🔵 Minor (Nice to Have)

---

#### M1. FORM CONFIRMATION: Placeholder Comment di Tengah Kode

**Kode:**
```abap
      " --- Set nilai CYCLE berdasarkan value tertinggi ---
      " ... [Sisa kode FORM CONFIRMATION di bawahnya tetap sama seperti sebelumnya] ...
      IF ITAB-TIMES GT 1. "Check previous times
```

Comment ini adalah sisa dari sesi editing sebelumnya. Kode yang sebenarnya ada dan berjalan (logic CYCLE-nya absen — ternyata CYCLE diambil dari LT_CYCLE di GET_INITIAL_DATA, bukan di CONFIRMATION). Tapi comment ini membingungkan maintainer dan sebaiknya dihapus atau diganti dengan comment yang informatif.

---

#### M2. FORM CONFIRMATION: Kondisi Double-IF Identik

**Kode:**
```abap
IF V_STATUS EQ 'FAIL'.
  IF V_STATUS EQ 'FAIL'.   " <-- Nested IF identik
    ITAB-ZSTAT = ERROR.
  ENDIF.
ENDIF.
```

Hapus salah satu IF yang duplikat.

---

#### M3. Inkonsistensi Nama MIC (WVTR vs MVTR, OTR vs O2TR)

**Forms:** Multiple  
**Kode:**
```abap
DELETE IT_OUTPUT WHERE INSPECTION CS 'MVTR' OR INSPECTION CS 'WVTR'.
DELETE IT_OUTPUT WHERE INSPECTION CS 'OTR' OR INSPECTION CS 'O2TR'.
```

Di beberapa tempat hanya menggunakan satu alias:
```abap
V_CODEWVTR = 'S' && ITAB-MATNR+2(3) && 'WVTR'.  " Hanya WVTR, tidak MVTR
```

Program mencampur penggunaan alias MVTR/WVTR dan OTR/O2TR tanpa konsistensi. Pastikan semua referensi ke MIC barrier sudah cover kedua alias.

---

#### M4. `STRLEN()` Tidak Valid dan `DATA` Inline dalam FORM

Sudah dicakup di I5 dan I6.

---

## GAP Analysis vs COA Project.md

| Business Requirement | Status | Catatan |
|---|---|---|
| Barrier inspection pending list | ✅ Done | Mode Pending List (GET_INITIAL_DATA + DISPLAY_DATA) |
| Upload hasil barrier dari file | ✅ Done | Mode Upload (GET_DATA_PREVIEW) |
| Cycle terakhir sebagai nilai akhir (LAST_VALUE) | ✅ Done | VALUE4→3→2→1 di REFRESH |
| Validasi nilai harus berurutan | ✅ Done | CONFIRMATION: sequential validation |
| Validasi previous TIMES | ✅ Done | CONFIRMATION: cek APRV_STATUS times sebelumnya |
| WVTR/OTR cross-closure validation | ✅ Done | CONFIRMATION: cek jika MIC pasangan sudah FAIL |
| Result Recording ke SAP QM via BAPI | ✅ Done | FORM RESULT_RECORDING |
| Usage Decision otomatis (worst value) | ✅ Done | Cancel UD → re-apply berdasarkan nilai cycle terbaru — by design benar |
| Deteksi konflik >1 sampel barrier per JR | ❌ Missing | **Belum ada** — (C2) |
| Overwrite nilai ke semua SR sibling | ❌ Missing | **Belum ada** — (C3) |
| Employee validation saat submit | ✅ Done | Popup NIK + CR_PERSONS_OF_WORKCENTER |
| Estimasi tanggal inspeksi selanjutnya | ✅ Done | ZMAP_TYPE ESTDATE per inspection type |
| ABAP 7.31 syntax compliance | ⚠️ Risk | `&&` dan `STRLEN()` perlu diverifikasi |

---

## Risk Assessment

| Risk | Severity | Probability | Impact |
|---|---|---|---|
| Tidak ada conflict resolution multi-sampel | 🔴 High | High (jika >1 SR per JR diinspeksi) | Nilai yang masuk tidak terkontrol — salah satu nilai "menang" secara acak |
| Sibling SR tidak dioverwrite | 🔴 High | Certain (fitur belum ada) | COA barrier hanya valid untuk 1 SR per JR, sisanya kosong |
| `&&` operator di ABAP 7.31 | 🟡 Medium | Perlu verifikasi di DEV | Jika SP level DEV lebih rendah, program tidak bisa diaktivasi/transport |
| Hardcoded `ARBPL = 'QA-Z04'` `WERKS = 'TTE'` | 🟡 Medium | High (jika multi-plant) | Semua user di plant lain ditolak saat submit — upload tidak bisa dilakukan |
| SELECT dalam LOOP (REFRESH + POPULATE) | 🟡 Medium | High (data besar) | Timeout saat submit dengan banyak SR |
| POSISI parse dari string roll fragile | 🟡 Medium | Possible | Salah POSISI → nilai diupload ke inspection lot yang salah |

---

## Recommendations

**Prioritas 1 — Fix sebelum go-live (Business Critical):**
1. Implementasi conflict resolution popup untuk >1 sampel per JR (C2)
2. Implementasi PROPAGATE_TO_SIBLINGS setelah RESULT_RECORDING sukses (C3)

**Prioritas 2 — Fix sebelum transport ke DEV/QAS:**
3. Ganti semua `&&` dengan `CONCATENATE` untuk ABAP 7.31 compliance (C1)
4. Ganti `STRLEN()` dengan cara ABAP 7.31 yang valid (I5)
5. Hapus hardcoded `ARBPL='QA-Z04'` dan `WERKS='TTE'`, ambil dari ZMAP_TYPE (I3)

**Prioritas 3 — Perbaikan performa:**
6. Refactor SELECT dalam LOOP di POPULATE_INSPECTION_DATA dan REFRESH ke FOR ALL ENTRIES (I1)
7. Refactor GET_INSPECTION dari SELECT...ENDSELECT ke SELECT INTO TABLE (I2)

**Prioritas 4 — Code quality:**
9. Hapus placeholder comment di CONFIRMATION (M1)
10. Fix nested IF ganda di CONFIRMATION (M2)
11. Pindahkan DATA declarations ke awal FORM (I6)

---

## Assessment

**Ready to deploy?** ❌ **No — Critical Business Gaps**

**Reasoning:** Program sudah punya fondasi yang kuat (alur data, validasi sequential, BAPI integration, error handling). Namun 3 bug/gap critical yang langsung mempengaruhi kelengkapan business flow COA barrier: (1) Usage Decision tidak diset untuk lot baru, (2) tidak ada conflict resolution untuk multi-sampel, (3) nilai tidak dipropagasi ke sibling SR. Tanpa ketiga ini, COA barrier hanya akan benar untuk 1 SR sampel per JR dan salah/kosong untuk semua SR lainnya.

Selain itu, perlu verifikasi syntax `&&` dan `STRLEN()` di environment DEV 7.31 sebelum transport.
