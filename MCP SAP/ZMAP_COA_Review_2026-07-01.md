# Code Review: ZMAP_COA (Program ZMAP)
**Date:** 2026-07-01  
**Reviewer:** Claude — SAP ABAP Consultant  
**Source:** Sandbox New Company (TRS / 192.168.6.243)  
**Line Count:** 1239 baris  

---

## Deskripsi Program

ZMAP_COA adalah program maintenance untuk tabel konfigurasi `ZMAP_COA` (mapping formula COA). Program ini menentukan **MIC mana dari inspection lot mana** yang akan ditarik untuk setiap kombinasi Material + Customer dalam pembuatan COA otomatis.

**Mode operasi:**
- `R_UPL` — Upload dari file tab-delimited
- `R_CRT` — Create (input manual via ALV grid 100 baris kosong)
- `R_EDT` — Edit data existing
- `R_DSP` — Display / Browse dengan filter

---

## Struktur Tabel ZMAP_COA (SE11)

| Field | Key | Type | Len | Keterangan |
|---|---|---|---|---|
| MATNR | ✅ PK | CHAR | 18 | Material Number |
| MIC | ✅ PK | CHAR | 8 | MIC (QPMK-MKMNR) |
| KUNNR | ✅ PK | CHAR | 10 | Customer Number |
| METHOD | ❌ | CHAR | 43 | Test Method (free text) |
| MAPPING | ❌ | CHAR | 43 | Formula mapping (free text) |
| CPUDT | ❌ | DATS | 8 | Created Date |
| CPUTM | ❌ | TIMS | 6 | Created Time |
| USNAM | ❌ | CHAR | 12 | Created By |
| TERM1 | ❌ | CHAR | 36 | Terminal Created |
| AEDAT | ❌ | DATS | 8 | Changed Date |
| PSOTM | ❌ | TIMS | 6 | Changed Time |
| AENAM | ❌ | CHAR | 12 | Changed By |
| TERM2 | ❌ | CHAR | 36 | Terminal Changed |
| DELETION | ❌ | CHAR | 1 | Soft-delete flag |

> ⚠️ **CRITICAL**: METHOD **bukan key field**. Hanya 1 record per kombinasi MATNR+MIC+KUNNR. Ini berdampak besar ke logic F_CHANGE_DATA.

---

## Strengths

1. **Soft-delete design** — DELETION flag + UNDELETE functionality mencegah accidental permanent delete.
2. **Audit trail lengkap** — CPUDT/CPUTM/USNAM/TERM1 (create) dan AEDAT/PSOTM/AENAM/TERM2 (change) sudah ada.
3. **Validasi berlapis di F_CREATE_DATA** — Cek MARA → QPMK → KNA1 sebelum INSERT sudah solid.
4. **GRID1 IS BOUND check** — Mencegah dump saat F_CREATE_DATA dipanggil dari Upload (sebelum ALV dirender).
5. **CONVERSION_EXIT_MATN1_INPUT** — Leading-zero formatting untuk MATNR saat upload sudah ditangani.
6. **Mode-aware field catalog** — Kolom DELETION/audit hanya tampil di Display mode, edit columns sesuai mode.
7. **POPUP_TO_CONFIRM** di Delete/Undelete — Mencegah operasi tidak sengaja.
8. **F4 help inline ALV** — Event-driven F4 via LCL_EVENT_RECEIVER untuk MATNR, MIC, KUNNR, METHOD, MAPPING.

---

## Issues

### 🔴 Critical (Must Fix)

---

#### C1. F_CHANGE_DATA: Logic Perbandingan Terbalik — Update TIDAK Pernah Berjalan

**Form:** `F_CHANGE_DATA`  
**Kode bermasalah:**
```abap
READ TABLE ITAB_TEMP WITH KEY MATNR = ITAB-MATNR
                              MIC   = ITAB-MIC
                              KUNNR = ITAB-KUNNR
                              METHOD  = ITAB-METHOD
                              MAPPING = ITAB-MAPPING.   " <-- kunci termasuk MAPPING (nilai BARU)

IF ITAB_TEMP-MAPPING <> ITAB-MAPPING.    " <-- Kondisi ini SELALU FALSE jika found
ELSE.
  " 'No update' message + CONTINUE (skip UPDATE)
ENDIF.

UPDATE ZMAP_COA SET MAPPING = ... WHERE MATNR = ... AND METHOD = ITAB-METHOD.
```

**Analisis:**
- `ITAB_TEMP` berisi data **original** (diload saat GET_DATA, sebelum user edit).
- READ TABLE menggunakan `MAPPING = ITAB-MAPPING` (nilai **baru** setelah user edit).
- **Skenario 1 — User MENGUBAH mapping**: ITAB-MAPPING = nilai baru. READ mencari di ITAB_TEMP dengan nilai baru → **NOT FOUND**. Work area ITAB_TEMP **tidak di-CLEAR**, sehingga berisi sisa iterasi sebelumnya → hasil tidak deterministik (bisa update atau tidak, tergantung data iterasi sebelumnya).
- **Skenario 2 — User TIDAK MENGUBAH**: ITAB-MAPPING = nilai lama = nilai di ITAB_TEMP → FOUND → `IF FALSE` → ELSE → "No update" ✅ (benar, tapi karena alasan yang salah).

**Dampak:** User klik tombol CHANGE → semua perubahan MAPPING **diabaikan**. Data tidak berubah. User tidak tahu ada yang salah karena program menampilkan pesan "Successfully updated" untuk record yang sebenarnya tidak diupdate.

**Fix:**
```abap
" Baca berdasarkan PK saja (tanpa METHOD dan MAPPING)
READ TABLE ITAB_TEMP WITH KEY MATNR = ITAB-MATNR
                              MIC   = ITAB-MIC
                              KUNNR = ITAB-KUNNR.

IF SY-SUBRC EQ 0.
  IF ITAB_TEMP-MAPPING NE ITAB-MAPPING OR ITAB_TEMP-METHOD NE ITAB-METHOD.
    " Ada perubahan → lanjut ke UPDATE
  ELSE.
    CONCATENATE 'No update on Material' ITAB-MATNR ... INTO V_MSG SEPARATED BY SPACE.
    CONTINUE.
  ENDIF.
ELSE.
  " Record tidak ditemukan di temp → error
  CONTINUE.
ENDIF.
```

---

#### C2. UPDATE WHERE Clause Menggunakan METHOD (Non-Key Field) — Silent Data Loss

**Form:** `F_CHANGE_DATA`  
**Kode bermasalah:**
```abap
UPDATE ZMAP_COA
SET MAPPING = ITAB-MAPPING  AEDAT = ...  PSOTM = ...  AENAM = ...  TERM2 = ...
WHERE MATNR = ITAB-MATNR AND MIC = ITAB-MIC AND KUNNR = ITAB-KUNNR AND METHOD = ITAB-METHOD.
```

**Masalah:**
- METHOD **bukan key field** di tabel ZMAP_COA (dikonfirmasi SE11).
- UPDATE WHERE menggunakan `METHOD = ITAB-METHOD` (nilai BARU dari grid).
- Jika user mengubah METHOD, DB masih punya METHOD lama → WHERE tidak match → **0 rows updated, SY-SUBRC ≠ 0, tidak ada error message**.
- Field METHOD **tidak ada dalam SET clause** → bahkan jika UPDATE berhasil (METHOD tidak diubah), nilai METHOD di DB tidak pernah bisa diupdate. METHOD yang diubah user di grid tidak pernah tersimpan.

**Dampak:** User bisa edit METHOD di grid, klik Save/Change, terlihat sukses, tapi METHOD di DB tidak berubah. Perubahan METHOD **hilang secara diam-diam**.

**Fix:**
```abap
UPDATE ZMAP_COA
SET MAPPING = ITAB-MAPPING
    METHOD  = ITAB-METHOD    " <-- Tambahkan METHOD ke SET
    AEDAT   = ITAB-AEDAT
    PSOTM   = ITAB-PSOTM
    AENAM   = ITAB-AENAM
    TERM2   = ITAB-TERM2
WHERE MATNR = ITAB-MATNR     " PK saja, tanpa METHOD
  AND MIC   = ITAB-MIC
  AND KUNNR = ITAB-KUNNR.    " <-- Hapus AND METHOD = ITAB-METHOD
```

---

#### C3. Tidak Ada COMMIT WORK Setelah DML

**Forms:** `F_CREATE_DATA`, `F_CHANGE_DATA`, `F_DELETE_DATA`, `F_UNDELETE_DATA`  
**Masalah:** Setiap form melakukan `INSERT`/`UPDATE` ke ZMAP_COA **tanpa `COMMIT WORK`** eksplisit setelahnya.

Di SAP dialog program, LUW (Logical Unit of Work) otomatis di-commit pada saat **CALL SCREEN** atau **SET SCREEN berikutnya**. Namun jika:
- User melakukan beberapa operasi berturutan dalam satu LUW
- Program diakhiri dengan `SET SCREEN 0` (EXIT)
- Ada error di tengah jalan

...data bisa rollback secara tidak terduga, atau perubahan dari beberapa operasi ter-bundle dalam 1 commit yang tidak terkontrol.

**Fix:** Tambahkan setelah setiap INSERT/UPDATE yang sukses:
```abap
COMMIT WORK AND WAIT.
IF SY-SUBRC <> 0.
  MESSAGE 'Commit gagal!' TYPE 'E'.
ENDIF.
```

---

#### C4. F_UPLOAD_DATA: Tidak Ada Skip Header Row

**Form:** `F_UPLOAD_DATA`  
**Kode bermasalah:**
```abap
CALL FUNCTION 'GUI_UPLOAD'
  EXPORTING
    FILENAME            = LV_FILENAME
    FILETYPE            = 'ASC'
    HAS_FIELD_SEPARATOR = 'X'    " Tab-delimited
  TABLES
    DATA_TAB            = IT_UPLOAD.

LOOP AT IT_UPLOAD.
  ITAB-MATNR   = IT_UPLOAD-MATNR.
  ITAB-MIC     = IT_UPLOAD-MIC.
  " ...
ENDLOOP.
```

**Masalah:** Jika file upload berasal dari Excel/Notepad dengan **baris header** (MATNR, MIC, NAME1, METHOD, MAPPING), baris pertama tersebut akan diperlakukan sebagai data. Validasi di F_CREATE_DATA akan menampilkan error "Material MATNR is not valid" untuk baris header.

**Dampak:** User kebingungan melihat error di baris pertama. Upload partial (baris header ter-error, baris data diproses).

**Fix:**
```abap
DATA: LV_FIRST TYPE C VALUE 'X'.
LOOP AT IT_UPLOAD.
  IF LV_FIRST EQ 'X'.   " Skip header row
    CLEAR LV_FIRST.
    CONTINUE.
  ENDIF.
  " ... populate ITAB
ENDLOOP.
```

Atau tambahkan parameter/checkbox "File has header row" di selection screen.

---

### 🟡 Important (Should Fix)

---

#### I1. F_HELP: SELECT * Tanpa WHERE — Full Table Scan

**Form:** `F_HELP`  
**Kode bermasalah:**
```abap
DATA: IT_MAPPING LIKE ZMAP_COA OCCURS 0.
SELECT * INTO CORRESPONDING FIELDS OF TABLE IT_MAPPING FROM ZMAP_COA.
```

**Masalah:** Setiap kali user menekan F4 di selection screen (P_MATNR, P_MIC, P_NAME1, P_METH, P_MAP), **seluruh tabel ZMAP_COA** dibaca ke memori. Tidak ada filter apapun, termasuk tidak memfilter `DELETION = ''`.

**Dampak:** Semakin besar ZMAP_COA, semakin lama F4 help muncul. Record yang sudah di-soft-delete juga tampil di F4 help, membingungkan user.

**Fix:**
```abap
SELECT * INTO CORRESPONDING FIELDS OF TABLE IT_MAPPING
  FROM ZMAP_COA
  WHERE DELETION NE 'X'.   " Minimal filter deleted records
```

Idealnya tambahkan filter sesuai context (misal: untuk P_MATNR, hanya tampilkan MATNR unik yang aktif).

---

#### I2. V_POS Tidak Di-Increment — Semua Kolom COL_POS = 1

**Form:** `PREPARE_FIELD_CATALOG`  
**Kode bermasalah:**
```abap
DATA: V_POS LIKE SY-TABIX.
DATA M_FIELDCAT TYPE LVC_S_FCAT.

CLEAR M_FIELDCAT.
M_FIELDCAT-COL_POS = V_POS + 1.   " = 0 + 1 = 1
...
APPEND M_FIELDCAT TO P_FCAT.
" V_POS tidak pernah di-ADD
CLEAR M_FIELDCAT.
M_FIELDCAT-COL_POS = V_POS + 1.   " = 0 + 1 = 1 (lagi)
```

**Masalah:** `V_POS` selalu bernilai 0 karena tidak pernah di-increment. Semua kolom mendapat `COL_POS = 1`. ALV Grid tetap bekerja karena urutan kolom ditentukan oleh urutan APPEND, tapi layout save/restore bisa berperilaku tidak konsisten.

**Fix:** Tambahkan `ADD 1 TO V_POS.` setelah setiap `APPEND M_FIELDCAT TO P_FCAT.`

---

#### I3. MAPPING Tidak Divalidasi Terhadap Nilai yang Diizinkan

**Forms:** `F_CREATE_DATA`, `F_UPLOAD_DATA`  
**Masalah:** Field MAPPING di ZMAP_COA adalah **free text** tanpa validasi apapun selain "tidak boleh kosong". Namun MAPPING dikonsumsi oleh ZQM002 dan ZQM003 dengan logika:

```abap
" Di ZQM002 GET_MIC:
IF IT_ZMAP-MAPPING CS 'SR Base Film'.
  " Ambil dari SR lot
ELSEIF IT_ZMAP-MAPPING CS 'JR Base Film'.
  " Ambil dari JR lot
ELSEIF IT_ZMAP-MAPPING CS 'SR Converting'.
ELSEIF IT_ZMAP-MAPPING CS 'JR Converting'.
ENDIF.
```

Nilai MAPPING yang tidak mengandung salah satu string di atas → **MIC value tidak pernah diisi** → kolom COA kosong → tidak ada error, tidak ada warning.

**Dampak:** Typo kecil seperti "SR Base film" (lowercase f) atau "SR BaseFilm" → COA kosong untuk MIC tersebut. Bug ini sangat sulit ditemukan karena tidak ada error.

**Fix:** Tambahkan validasi di F_CREATE_DATA dan F_CHANGE_DATA:
```abap
" Daftar nilai MAPPING yang valid
IF NOT ( ITAB-MAPPING CS 'SR Base Film'
      OR ITAB-MAPPING CS 'JR Base Film'
      OR ITAB-MAPPING CS 'SR Converting'
      OR ITAB-MAPPING CS 'JR Converting' ).
  ITAB-REMARK = 'MAPPING value tidak dikenal. Gunakan: SR/JR Base Film atau SR/JR Converting'.
  ITAB-LINE_COLOR = V_ERR.
  MODIFY ITAB.
  CONTINUE.
ENDIF.
```

Atau gunakan **Domain dengan Fixed Values** untuk field MAPPING di SE11.

---

#### I4. F_CREATE_DATA: Duplicate Check Tidak Menyertakan METHOD

**Form:** `F_CREATE_DATA`  
**Kode bermasalah:**
```abap
SELECT SINGLE MATNR DELETION INTO (ITAB-MATNR, ITAB-DELETION)
  FROM ZMAP_COA
 WHERE MATNR = ITAB-MATNR
   AND MIC   = ITAB-MIC
   AND KUNNR = ITAB-KUNNR.
```

**Analisis:** Ini sebenarnya **sudah benar** karena PK ZMAP_COA memang MATNR+MIC+KUNNR (tanpa METHOD). Namun pesan error yang muncul menyebut "Mapping [value] is exist!" — ini menyesatkan karena seolah MAPPING yang duplikat, padahal yang duplikat adalah kombinasi MATNR+MIC+KUNNR.

**Fix:** Perbaiki pesan error:
```abap
" Ganti dari:
CONCATENATE ITAB-MATNR ': Mapping' ITAB-MAPPING 'is exist...!' INTO V_MSG ...
" Menjadi:
CONCATENATE 'Record already exists for Material' ITAB-MATNR 'MIC' ITAB-MIC 'Customer' ITAB-KUNNR INTO V_MSG ...
```

---

#### I5. GET_DATA: Filter P_NAME1 via DELETE ITAB — Tidak Efisien

**Form:** `GET_DATA`  
**Kode bermasalah:**
```abap
SELECT * INTO CORRESPONDING FIELDS OF TABLE ITAB
  FROM ZMAP_COA
  LEFT OUTER JOIN KNA1 ON KNA1~KUNNR EQ ZMAP_COA~KUNNR
 WHERE MATNR IN P_MATNR AND MIC IN P_MIC AND METHOD IN P_METH AND MAPPING IN P_MAP.

IF P_NAME1[] IS NOT INITIAL.
  DELETE ITAB WHERE NAME1 NOT IN P_NAME1.
ENDIF.
```

**Masalah:** Filter P_NAME1 dilakukan **setelah SELECT** dengan DELETE di memori. Semua record diambil ke ITAB dulu, baru difilter. Untuk tabel ZMAP_COA besar, ini membebani memori dan network.

Selain itu, LEFT OUTER JOIN berarti record dengan KUNNR=' ' (general, tanpa customer) juga ter-ambil dengan NAME1 = INITIAL. Jika user filter NAME1, record general ini akan ter-hapus dari hasil, padahal mungkin ingin ditampilkan.

**Fix:** Pisahkan query untuk general vs customer-specific, atau dokumentasikan behavior ini ke user.

---

### 🔵 Minor (Nice to Have)

---

#### M1. CREATED2 Block: ELSEIF Cek TERM1 (Seharusnya TERM2)

**Form:** `GET_DATA`  
**Kode bermasalah:**
```abap
IF ITAB-AENAM IS NOT INITIAL AND ITAB-TERM2 IS NOT INITIAL.
  CONCATENATE ITAB-AENAM '-' ITAB-TERM2 INTO ITAB-CREATED2.
ELSE.
  IF ITAB-AENAM IS NOT INITIAL.
    ITAB-CREATED2 = ITAB-AENAM.
  ELSEIF ITAB-TERM1 IS NOT INITIAL.   " <-- BUG: TERM1, harusnya TERM2
    ITAB-CREATED2 = ITAB-TERM2.
  ENDIF.
ENDIF.
```

Kolom "Changed By" tidak tampil jika AENAM kosong tapi TERM2 ada, karena pengecekan `ITAB-TERM1` (milik "Created By") bukan `ITAB-TERM2`.

---

#### M2. F_CHANGE_DATA: IF Redundan Setelah UPDATE

**Form:** `F_CHANGE_DATA`  
```abap
UPDATE ZMAP_COA SET MAPPING = ITAB-MAPPING WHERE ...

IF ITAB_TEMP-MAPPING <> ITAB-MAPPING.   " <-- IF ini redundan
  CONCATENATE V_MSG 'Mapping' ITAB-MAPPING INTO V_MSG ...
ENDIF.

CONCATENATE V_MSG 'Successfully updated ...' INTO V_MSG ...
```

IF ini setelah UPDATE tidak berguna karena kondisi sudah diperiksa sebelumnya. Hapus IF ini, langsung build success message.

---

#### M3. F_HELP_METHOD & F_HELP_MAPPING: DYNPRO Kosong

```abap
PERFORM F_HELP USING 'Method Help List' '' 'METHOD'.    " DYNPRO = ''
```

Saat digunakan sebagai inline F4 di ALV (via CATCH_F4), parameter DYNPRO memang tidak relevan karena return dilakukan via `ITAB-METHOD = IT_RETURN-FIELDVAL`. Tapi tetap sebaiknya diisi dengan value yang benar untuk konsistensi.

---

## GAP Analysis vs COA Project.md

### Requirement dari COA Project.md

| Requirement | Status ZMAP_COA | Risiko |
|---|---|---|
| Mapping per Material + Customer | ✅ Implemented | — |
| Support formula 4 kategori (SR/JR Base Film, SR/JR Converting) | ⚠️ Partial | Nilai MAPPING tidak divalidasi → typo menyebabkan COA kosong |
| Barrier (Converting) mapping untuk MVTR/OTR | ⚠️ Data Gap | Kolom tersedia, tapi **entry data** untuk MIC MVTR/OTR di material barrier belum tentu ada |
| Customer override (general + customer-specific) | ✅ Implemented | KUNNR='' untuk general, KUNNR=value untuk specific |
| Pembuatan COA berdasarkan **Tipe Film** | ❌ GAP | ZMAP_COA tidak punya kolom FILM TYPE — satu MIC per material hanya bisa punya 1 mapping |
| Audit trail perubahan mapping | ✅ Implemented | — |
| Upload bulk mapping dari file | ✅ Implemented | Ada bug header skip (C4) |
| Soft delete dengan recovery | ✅ Implemented | — |

---

### GAP Detail

#### GAP-1: Tidak Ada Dimensi Film Type (ZZTYPE) di ZMAP_COA ⚠️

**Konteks:** COA Project.md menyebut: *"mapping pembuatan COA berdasarkan Tipe Film dan Customer"*.

ZMAP_COA saat ini hanya mendukung mapping berdasarkan **MATNR + MIC + KUNNR**. Tidak ada kolom untuk Film Type (ZZTYPE dari karakteristik batch).

**Dampak:** Jika ada material yang memiliki **varian film type berbeda** (misal: Biaxial dan Monoaxial dalam MATNR yang sama), tidak bisa didefinisikan mapping formula yang berbeda per tipe.

**Contoh Skenario:**
- Material A, MIC MVTR, Customer X:
  - Jika ZZTYPE = 'BIAXIAL' → ambil dari JR lot
  - Jika ZZTYPE = 'MONOAXIAL' → ambil dari SR lot
  
Dengan struktur saat ini, hanya bisa ada 1 mapping untuk kombinasi tersebut.

**Rekomendasi:** Jika memang diperlukan diferensiasi per tipe film, tambahkan field ZTYPE ke struktur ZMAP_COA dan jadikan bagian dari primary key. Diskusikan dengan functional consultant apakah ini in-scope.

---

#### GAP-2: Entry Data Barrier MIC (MVTR/OTR) Belum Terkonfirmasi ⚠️

**Konteks:** COA Project.md: *"properti Barrier (Converting) juga belum dimaintain di dalam SAP"*.

ZMAP_COA sudah bisa menyimpan mapping untuk MIC MVTR dan OTR. Namun jika **entry data belum dibuat** untuk material-material yang memerlukan COA barrier, maka ZQM002/003 tidak akan menemukan mapping → kolom barrier di COA kosong.

**Risk:** Go-live tanpa entry data barrier = COA tanpa data barrier, tanpa error/warning apapun.

**Rekomendasi:** Buat checklist data entry barrier mapping sebelum go-live. Verifikasi dengan query:
```sql
SELECT COUNT(*) FROM ZMAP_COA
WHERE (MAPPING LIKE '%SR Converting%' OR MAPPING LIKE '%JR Converting%')
AND DELETION NE 'X'
```

---

#### GAP-3: Tidak Ada Validasi Nilai MAPPING Terhadap Enum yang Dikenali ZQM002/003

*(Sudah detail di Issue I3 di atas — ini cross-program consistency risk)*

ZQM002 menggunakan `CS 'SR Base Film'`, `CS 'JR Base Film'`, dll. Tapi ZMAP_COA tidak validasi ini. Satu typo = satu kolom COA kosong = customer complaint.

---

## Risk Assessment

| Risk | Severity | Probability | Impact |
|---|---|---|---|
| F_CHANGE_DATA tidak menyimpan perubahan MAPPING | 🔴 High | Certain (bug terkonfirmasi) | User tidak bisa update mapping → terpaksa delete + create ulang |
| METHOD tidak pernah bisa diupdate | 🔴 High | Certain (bug terkonfirmasi) | Perubahan METHOD silently lost |
| No COMMIT WORK | 🟡 Medium | Possible | Data loss pada operasi yang tidak diselesaikan |
| Header row masuk sebagai data saat upload | 🟡 Medium | High (umum terjadi) | Error baris pertama setiap upload dari Excel |
| Typo di MAPPING value → COA kosong | 🔴 High | Possible | Silent data quality issue yang sulit debug |
| GAP Film Type | 🟡 Medium | TBD (perlu konfirmasi scope) | Ketidakfleksibelan mapping per varian |
| Barrier data belum di-entry | 🟡 Medium | High | COA barrier kosong di production |

---

## Recommendations

**Prioritas 1 — Fix sebelum go-live:**
1. Perbaiki `F_CHANGE_DATA` — ganti READ TABLE key (tanpa MAPPING) dan perbaiki IF logic (Issue C1)
2. Tambahkan METHOD ke SET clause dan hapus METHOD dari WHERE clause di UPDATE (Issue C2)
3. Tambahkan `COMMIT WORK AND WAIT` setelah setiap DML yang sukses (Issue C3)
4. Tambahkan header skip di F_UPLOAD_DATA (Issue C4)

**Prioritas 2 — Kualitas data:**

5. Tambahkan validasi MAPPING value terhadap list yang diizinkan (Issue I3)
6. Lakukan data entry Barrier MIC mapping untuk semua material yang dibutuhkan (GAP-2)

**Prioritas 3 — Perbaikan teknis:**

7. Fix F_HELP dengan WHERE DELETION NE 'X' (Issue I1)
8. Increment V_POS di PREPARE_FIELD_CATALOG (Issue I2)
9. Fix error message di F_CREATE_DATA duplicate check (Issue I4)

**Prioritas 4 — Diskusi scope:**

10. Evaluasi apakah diperlukan Film Type dimension di ZMAP_COA (GAP-1) — diskusikan dengan functional consultant

---

## Assessment

**Ready to deploy?** ❌ **No — Critical Fixes Required**

**Reasoning:** ZMAP_COA memiliki 2 bug critical yang menyebabkan mode `Edit` tidak berfungsi sama sekali (F_CHANGE_DATA tidak pernah update). User yang ingin mengubah MAPPING atau METHOD terpaksa harus delete + re-create, dan jika tidak tahu ada bug ini, mereka akan mengira data sudah tersimpan padahal tidak. Selain itu, tidak ada validasi MAPPING value yang menjadi jembatan kritis antara konfigurasi ini dengan output COA di ZQM002/ZQM003.
