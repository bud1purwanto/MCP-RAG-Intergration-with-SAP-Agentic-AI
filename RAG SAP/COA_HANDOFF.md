# COA Automation — Handoff Document
> Dokumen ini dibuat agar LLM/developer lain dapat langsung melanjutkan pekerjaan tanpa kehilangan konteks.
> Last updated: 2026-06-28

---

## 1. Environment SAP

| Field | Value |
|---|---|
| **System Dev** | TRD — eccdevlinux — 192.168.2.8 |
| **System Sandbox** | TRS (Sandbox New Company) — 192.168.6.243 |
| **ABAP Release** | 7.31 (ECC 6.0 EHP6 / NW 7.31) |
| **DB** | Oracle / OS: Linux |

### Aturan Update Program
- **HANYA boleh push ke `sandbox-new` (TRS)**
- Mekanisme push: `RFC_ABAP_INSTALL_AND_RUN` → temp program yang memanggil `RPY_PROGRAM_UPDATE` dengan `TRANSPORT_NUMBER = ' '` dan `DEVELOPMENT_CLASS = '$TMP'`
- `Z_RFC_PROGRAM_UPDATE` **RUSAK** — parameter salah (`CORR_NUMBER` vs `TRANSPORT_NUMBER`)
- Baca dari dev (server `dev`) → edit → push ke `sandbox-new`

### MCP Tools Prefix
- MCP SAP aktif: `mcp__sap-leader-mcp__*`
- Tools: `set_active_server`, `read_program`, `call_function`, dll.

---

## 2. Project COA — Overview

**Goal:** Otomatisasi Certificate of Analysis (COA) dari modul QM SAP. Menghilangkan copy-data manual dan menambah modul Barrier (MVTR/OTR).

### Program Utama: `ZQMI_CERTIFICATE_CPY`
Include structure:
| Include | Isi |
|---|---|
| `ZQMI_CERTIFICATE_TOP_CPY` | DATA declarations, TABLES, SELECTION-SCREEN |
| `ZQMI_CERTIFICATE_F01_CPY` | Logic utama: GET_DATA, GET_MIC, screen events |
| *(screen includes lainnya)* | PBO/PAI handlers |

### Tabel Kunci
| Tabel | Kegunaan |
|---|---|
| `ZMAP_COA` | Mapping MIC → METHOD per MATNR + KUNNR |
| `ZINSPKEY` | Link Jumbo Roll → After Slitting inspection lot |
| `QALS` | Inspection lot header |
| `QAMR` | Inspection result recordings |
| `QPMK` / `QPMT` | MIC master (code, UOM, description) |
| `ZQM_LOG_GS` | Log inspeksi dengan PRUEFLOSREF |
| `LIKP` | Delivery header (untuk ambil KUNAG/customer) |

### Struktur ZMAP_COA (KEY fields)
```
MATNR + MIC + KUNNR (KEY)
METHOD, DELETION, ...
```
- `KUNNR = SPACE` → general mapping (berlaku semua customer)
- `KUNNR = filled` → customer-specific mapping (prioritas utama)

---

## 3. Enhancement Yang Dikerjakan

### 3.1 Mapping by Customer ✅ (kode sudah ada di file workspace)
**Business rule:** Saat ambil mapping dari ZMAP_COA, cek dulu apakah ada mapping khusus customer (KUNNR dari LIKP-KUNAG). Jika tidak ada, fallback ke general (KUNNR=' ').

**Alur:**
1. SELECT SINGLE KUNAG dari LIKP WHERE VBELN = IT_DATA-VBELN → simpan ke `LV_KUNNR`
2. IF LV_KUNNR NOT INITIAL → SELECT dari ZMAP_COA WHERE ... AND KUNNR = LV_KUNNR
3. IF result kosong → fallback SELECT WHERE KUNNR = ' '

### 3.2 Barrier Detection (MVTR/OTR) ✅ (kode sudah ada di file workspace)
**Business rule:** Deteksi tipe barrier dari nama MIC code menggunakan CS (Contains String):
- MIC CS 'MVTR' OR MIC CS 'WVTR' → `BARRIER_TYPE = 'MVTR'`
- MIC CS 'OTR' OR MIC CS 'O2TR' → `BARRIER_TYPE = 'OTR'`

Diterapkan di dua tempat:
1. Setelah `MOVE-CORRESPONDING IT_MIC1 TO WA_DATA.` → set `WA_DATA-BARRIER_TYPE`
2. Di dalam LOOP IT_WRONG (fallback section) → set `IT_DATA_TMP-BARRIER_TYPE`

---

## 4. File Yang Sudah Dibuat di Workspace

> Path: `C:\Users\Lenovo\Documents\Claude\RAG SAP\`

### `ZQMI_CERTIFICATE_TOP_CPY.abap` ✅ SUDAH ADA
Berisi perubahan:
1. **IT_DATA**: tambah field `BARRIER_TYPE TYPE C LENGTH 4` setelah NOREF
2. **IT_MIC1**: tambah field `BARRIER_TYPE TYPE C LENGTH 4` setelah SEQ(1)
3. **IT_ZMAP**: tambah field `KUNNR LIKE ZMAP_COA-KUNNR` setelah MIC

### `ZQMI_CERTIFICATE_F01_CPY.abap` ✅ SUDAH ADA
Berisi perubahan:
1. **FORM GET_DATA DATA declaration**: tambah `LV_KUNNR LIKE ZMAP_COA-KUNNR.` setelah `ROLL TYPE C LENGTH 10,`
2. **CLEAR statement**: `CLEAR : TEXT1, TEXT2, ROLL, LV_KUNNR.`
3. **ZMAP_COA SELECT block**: ganti single SELECT dengan customer-aware (LV_KUNNR dari LIKP)
4. **METHOD SELECT**: ganti single SELECT dengan customer-aware
5. **BARRIER detection** setelah `MOVE-CORRESPONDING IT_MIC1 TO WA_DATA.`
6. **BARRIER detection** di section IT_WRONG sebelum `APPEND IT_DATA_TMP TO IT_DATA.`

---

## 5. STATUS SAAT INI

| Item | Status |
|---|---|
| File workspace TOP | ✅ Sudah dimodifikasi |
| File workspace F01 | ✅ Sudah dimodifikasi |
| Push TOP ke SAP sandbox-new | ❌ BELUM |
| Push F01 ke SAP sandbox-new | ❌ BELUM |
| Verify di SAP | ❌ BELUM |

**TASK SELANJUTNYA: Push kedua include ke SAP sandbox-new**

---

## 6. Cara Push ke SAP (Mekanisme RFC_ABAP_INSTALL_AND_RUN)

Karena `Z_RFC_PROGRAM_UPDATE` rusak (parameter CORR_NUMBER vs TRANSPORT_NUMBER), kita pakai bootstrap:

### Step 1: Set server ke sandbox-new
```
mcp__sap-leader-mcp__set_active_server → server: "sandbox-new"
```

### Step 2: Jalankan RFC_ABAP_INSTALL_AND_RUN
Kirim temporary ABAP program yang:
1. `READ_REPORT` → baca source include dari SAP
2. Loop + patch lines yang perlu diubah
3. `RPY_PROGRAM_UPDATE` dengan `TRANSPORT_NUMBER = ' '` dan `DEVELOPMENT_CLASS = '$TMP'`

### Batasan PROGTAB
- Setiap baris program di tabel PROGRAM (PROGTAB) **maksimal 72 karakter**
- Untuk string panjang, gunakan CONCATENATE

---

## 7. Program Patch TOP (siap pakai)

Jalankan via `call_function` dengan `FUNCTION_NAME = 'RFC_ABAP_INSTALL_AND_RUN'`, parameter `PROGRAM` berisi baris-baris berikut:

```abap
REPORT <<RFC1>>.
DATA: BEGIN OF lt_src OCCURS 0,
        LINE TYPE c LENGTH 72,
      END OF lt_src.
DATA: BEGIN OF lt_out OCCURS 0,
        LINE TYPE c LENGTH 255,
      END OF lt_out.
DATA: lv_f1 TYPE c VALUE ' '.
DATA: lv_f2 TYPE c VALUE ' '.
DATA: lv_f3 TYPE c VALUE ' '.
CALL FUNCTION 'READ_REPORT'
  EXPORTING
    PROGRAM = 'ZQMI_CERTIFICATE_TOP_CPY'
  TABLES
    QTAB    = lt_src
  EXCEPTIONS
    NOT_FOUND = 1
    OTHERS    = 2.
IF SY-SUBRC <> 0.
  WRITE: / 'ERROR: read failed', SY-SUBRC.
  STOP.
ENDIF.
LOOP AT lt_src.
  lt_out-line = lt_src-line.
  APPEND lt_out. CLEAR lt_out.
  IF lv_f1 = ' '.
    IF lt_src-line CS 'NOREF LIKE ZQM_LOG_GS-NOREF,'.
      lt_out-line =
        '        BARRIER_TYPE TYPE C LENGTH 4,'.
      APPEND lt_out. CLEAR lt_out.
      lv_f1 = 'X'.
    ENDIF.
  ENDIF.
  IF lv_f2 = ' '.
    IF lt_src-line CS 'SEQ(1),'.
      lt_out-line =
        '        BARRIER_TYPE TYPE C LENGTH 4,'.
      APPEND lt_out. CLEAR lt_out.
      lv_f2 = 'X'.
    ENDIF.
  ENDIF.
  IF lv_f3 = ' '.
    IF lt_src-line CS 'MIC LIKE ZMAP_COA-MIC,'.
      lt_out-line =
        '        KUNNR LIKE ZMAP_COA-KUNNR,'.
      APPEND lt_out. CLEAR lt_out.
      lv_f3 = 'X'.
    ENDIF.
  ENDIF.
ENDLOOP.
CALL FUNCTION 'RPY_PROGRAM_UPDATE'
  EXPORTING
    PROGRAM_NAME      = 'ZQMI_CERTIFICATE_TOP_CPY'
    DEVELOPMENT_CLASS = '$TMP'
    TRANSPORT_NUMBER  = ' '
  TABLES
    SOURCE_EXTENDED   = lt_out
  EXCEPTIONS
    CANCELLED         = 1
    PERMISSION_ERROR  = 2
    NOT_FOUND         = 3
    OTHERS            = 4.
IF SY-SUBRC = 0.
  COMMIT WORK AND WAIT.
  WRITE: / 'TOP updated OK'.
ELSE.
  WRITE: / 'ERROR TOP:', SY-SUBRC.
ENDIF.
```

---

## 8. Program Patch F01 — Part A (DATA + CLEAR + ZMAP_COA SELECT)

```abap
REPORT <<RFC1>>.
DATA: BEGIN OF lt_src OCCURS 0,
        LINE TYPE c LENGTH 72,
      END OF lt_src.
DATA: BEGIN OF lt_out OCCURS 0,
        LINE TYPE c LENGTH 255,
      END OF lt_out.
DATA: lv_f1 TYPE c VALUE ' '.
DATA: lv_f1b TYPE c VALUE ' '.
DATA: lv_f2 TYPE c VALUE ' '.
DATA: lv_prev TYPE c LENGTH 72.
DATA: lv_skipz TYPE c VALUE ' '.
DATA: lv_donez TYPE c VALUE ' '.
CALL FUNCTION 'READ_REPORT'
  EXPORTING
    PROGRAM = 'ZQMI_CERTIFICATE_F01_CPY'
  TABLES
    QTAB    = lt_src
  EXCEPTIONS
    NOT_FOUND = 1
    OTHERS    = 2.
IF SY-SUBRC <> 0.
  WRITE: / 'ERROR read F01'. STOP.
ENDIF.
LOOP AT lt_src.
  " Patch 1: ROLL → add comma, prepare LV_KUNNR insert
  IF lv_f1 = ' '.
    IF lt_src-line CS 'ROLL TYPE C LENGTH 10.'.
      REPLACE '10.' WITH '10,' IN lt_src-line.
      lv_f1 = 'X'.
    ENDIF.
  ENDIF.
  " Patch 2: CLEAR statement add LV_KUNNR
  IF lv_f2 = ' '.
    IF lt_src-line CS 'CLEAR : TEXT1, TEXT2, ROLL.'.
      REPLACE 'ROLL.' WITH 'ROLL, LV_KUNNR.'
              IN lt_src-line.
      lv_f2 = 'X'.
    ENDIF.
  ENDIF.
  " Patch 3: ZMAP_COA SELECT — start skip
  IF lv_donez = ' ' AND lv_skipz = ' '.
    IF lt_src-line CS 'CLEAR IT_ZMAP.' AND
       lv_prev CS 'IT_DATA-ZZTYPE = TBATCH-ATWTB.'.
      lv_skipz = 'X'.
      " Insert new customer-aware block
      lt_out-line = '      CLEAR : IT_ZMAP, LV_KUNNR.'.
      APPEND lt_out. CLEAR lt_out.
      lt_out-line = '      REFRESH IT_ZMAP.'.
      APPEND lt_out. CLEAR lt_out.
      lt_out-line = '      SELECT SINGLE KUNAG INTO LV_KUNNR'.
      APPEND lt_out. CLEAR lt_out.
      lt_out-line = '        FROM LIKP'.
      APPEND lt_out. CLEAR lt_out.
      lt_out-line =
        '        WHERE VBELN = IT_DATA-VBELN.'.
      APPEND lt_out. CLEAR lt_out.
      lt_out-line = '      IF LV_KUNNR IS NOT INITIAL.'.
      APPEND lt_out. CLEAR lt_out.
      lt_out-line =
        '        SELECT MATNR MIC KUNNR METHOD'.
      APPEND lt_out. CLEAR lt_out.
      CONCATENATE '          INTO CORRESPONDING FIELDS'
                  ' OF TABLE IT_ZMAP' INTO lt_out-line.
      APPEND lt_out. CLEAR lt_out.
      lt_out-line = '          FROM ZMAP_COA'.
      APPEND lt_out. CLEAR lt_out.
      lt_out-line =
        '          WHERE MATNR    = IT_DATA-MATNR'.
      APPEND lt_out. CLEAR lt_out.
      lt_out-line =
        '            AND KUNNR    = LV_KUNNR'.
      APPEND lt_out. CLEAR lt_out.
      lt_out-line =
        '            AND DELETION NE ''X''.'.
      APPEND lt_out. CLEAR lt_out.
      lt_out-line = '      ENDIF.'.
      APPEND lt_out. CLEAR lt_out.
      lt_out-line = '      IF IT_ZMAP[] IS INITIAL.'.
      APPEND lt_out. CLEAR lt_out.
      lt_out-line =
        '        SELECT MATNR MIC KUNNR METHOD'.
      APPEND lt_out. CLEAR lt_out.
      CONCATENATE '          INTO CORRESPONDING FIELDS'
                  ' OF TABLE IT_ZMAP' INTO lt_out-line.
      APPEND lt_out. CLEAR lt_out.
      lt_out-line = '          FROM ZMAP_COA'.
      APPEND lt_out. CLEAR lt_out.
      lt_out-line =
        '          WHERE MATNR    = IT_DATA-MATNR'.
      APPEND lt_out. CLEAR lt_out.
      lt_out-line =
        '            AND KUNNR    = '' '''.
      APPEND lt_out. CLEAR lt_out.
      lt_out-line =
        '            AND DELETION NE ''X''.'.
      APPEND lt_out. CLEAR lt_out.
      lt_out-line = '      ENDIF.'.
      APPEND lt_out. CLEAR lt_out.
      lv_prev = lt_src-line.
      CONTINUE.
    ENDIF.
  ENDIF.
  " Patch 3: ZMAP_COA SELECT — in skip mode
  IF lv_skipz = 'X'.
    IF lt_src-line CS
       'DELETE ADJACENT DUPLICATES FROM IT_ZMAP'.
      lt_out-line =
        '      SORT IT_ZMAP BY MIC ASCENDING.'.
      APPEND lt_out. CLEAR lt_out.
      CONCATENATE '      DELETE ADJACENT DUPLICATES'
                  ' FROM IT_ZMAP COMPARING MIC.'
                  INTO lt_out-line.
      APPEND lt_out. CLEAR lt_out.
      lv_skipz = ' '. lv_donez = 'X'.
    ENDIF.
    lv_prev = lt_src-line.
    CONTINUE.
  ENDIF.
  lt_out-line = lt_src-line.
  APPEND lt_out. CLEAR lt_out.
  " Insert LV_KUNNR declaration after ROLL line
  IF lv_f1 = 'X' AND lv_f1b = ' '.
    lt_out-line =
      '         LV_KUNNR LIKE ZMAP_COA-KUNNR.'.
    APPEND lt_out. CLEAR lt_out.
    lv_f1b = 'X'.
  ENDIF.
  lv_prev = lt_src-line.
ENDLOOP.
CALL FUNCTION 'RPY_PROGRAM_UPDATE'
  EXPORTING
    PROGRAM_NAME      = 'ZQMI_CERTIFICATE_F01_CPY'
    DEVELOPMENT_CLASS = '$TMP'
    TRANSPORT_NUMBER  = ' '
  TABLES
    SOURCE_EXTENDED   = lt_out
  EXCEPTIONS
    CANCELLED         = 1
    PERMISSION_ERROR  = 2
    NOT_FOUND         = 3
    OTHERS            = 4.
IF SY-SUBRC = 0.
  COMMIT WORK AND WAIT.
  WRITE: / 'F01 Part-A OK'.
ELSE.
  WRITE: / 'ERROR F01-A:', SY-SUBRC.
ENDIF.
```

---

## 9. Program Patch F01 — Part B (METHOD SELECT + Barrier Detection)

Dijalankan SETELAH Part A berhasil. Membaca F01 yang sudah di-patch Part A lalu menambah patch sisanya.

```abap
REPORT <<RFC1>>.
DATA: BEGIN OF lt_src OCCURS 0,
        LINE TYPE c LENGTH 72,
      END OF lt_src.
DATA: BEGIN OF lt_out OCCURS 0,
        LINE TYPE c LENGTH 255,
      END OF lt_out.
DATA: lv_skipm TYPE c VALUE ' '.
DATA: lv_donem TYPE c VALUE ' '.
DATA: lv_doneb1 TYPE c VALUE ' '.
DATA: lv_skipa TYPE c VALUE ' '.
DATA: lv_donea TYPE c VALUE ' '.
CALL FUNCTION 'READ_REPORT'
  EXPORTING
    PROGRAM = 'ZQMI_CERTIFICATE_F01_CPY'
  TABLES
    QTAB    = lt_src
  EXCEPTIONS
    NOT_FOUND = 1
    OTHERS    = 2.
IF SY-SUBRC <> 0.
  WRITE: / 'ERROR read F01'. STOP.
ENDIF.
LOOP AT lt_src.
  " Patch 4: METHOD SELECT start
  IF lv_donem = ' ' AND lv_skipm = ' '.
    IF lt_src-line CS
       'SELECT SINGLE METHOD INTO IT_MIC1-METHOD'.
      lv_skipm = 'X'.
      lt_out-line = '        CLEAR IT_MIC1-METHOD.'.
      APPEND lt_out. CLEAR lt_out.
      lt_out-line =
        '        IF LV_KUNNR IS NOT INITIAL.'.
      APPEND lt_out. CLEAR lt_out.
      CONCATENATE '          SELECT SINGLE METHOD'
                  ' INTO IT_MIC1-METHOD'
                  INTO lt_out-line.
      APPEND lt_out. CLEAR lt_out.
      lt_out-line = '            FROM ZMAP_COA'.
      APPEND lt_out. CLEAR lt_out.
      lt_out-line =
        '            WHERE MATNR    = IT_LOT-MATNR'.
      APPEND lt_out. CLEAR lt_out.
      lt_out-line =
        '              AND MIC      = IT_MIC1-MIC'.
      APPEND lt_out. CLEAR lt_out.
      lt_out-line =
        '              AND KUNNR    = LV_KUNNR'.
      APPEND lt_out. CLEAR lt_out.
      lt_out-line =
        '              AND DELETION NE ''X''.'.
      APPEND lt_out. CLEAR lt_out.
      lt_out-line = '        ENDIF.'.
      APPEND lt_out. CLEAR lt_out.
      lt_out-line =
        '        IF IT_MIC1-METHOD IS INITIAL.'.
      APPEND lt_out. CLEAR lt_out.
      CONCATENATE '          SELECT SINGLE METHOD'
                  ' INTO IT_MIC1-METHOD'
                  INTO lt_out-line.
      APPEND lt_out. CLEAR lt_out.
      lt_out-line = '            FROM ZMAP_COA'.
      APPEND lt_out. CLEAR lt_out.
      lt_out-line =
        '            WHERE MATNR    = IT_LOT-MATNR'.
      APPEND lt_out. CLEAR lt_out.
      lt_out-line =
        '              AND MIC      = IT_MIC1-MIC'.
      APPEND lt_out. CLEAR lt_out.
      lt_out-line =
        '              AND KUNNR    = '' '''.
      APPEND lt_out. CLEAR lt_out.
      lt_out-line =
        '              AND DELETION NE ''X''.'.
      APPEND lt_out. CLEAR lt_out.
      lt_out-line = '        ENDIF.'.
      APPEND lt_out. CLEAR lt_out.
      CONTINUE.
    ENDIF.
  ENDIF.
  " Patch 4: skip until end of old METHOD SELECT
  IF lv_skipm = 'X'.
    IF lt_src-line CS 'AND MIC = IT_MIC1-MIC.'.
      lv_skipm = ' '. lv_donem = 'X'.
    ENDIF.
    CONTINUE.
  ENDIF.
  " Patch 5: Barrier after MOVE-CORRESPONDING
  IF lv_doneb1 = ' '.
    IF lt_src-line CS
       'MOVE-CORRESPONDING IT_MIC1 TO WA_DATA.'.
      lt_out-line = lt_src-line.
      APPEND lt_out. CLEAR lt_out.
      lt_out-line = '        CLEAR WA_DATA-BARRIER_TYPE.'.
      APPEND lt_out. CLEAR lt_out.
      lt_out-line =
        '        IF WA_DATA-MIC CS ''MVTR''.'.
      APPEND lt_out. CLEAR lt_out.
      lt_out-line =
        '          WA_DATA-BARRIER_TYPE = ''MVTR''.'.
      APPEND lt_out. CLEAR lt_out.
      lt_out-line =
        '        ELSEIF WA_DATA-MIC CS ''WVTR''.'.
      APPEND lt_out. CLEAR lt_out.
      lt_out-line =
        '          WA_DATA-BARRIER_TYPE = ''MVTR''.'.
      APPEND lt_out. CLEAR lt_out.
      lt_out-line =
        '        ELSEIF WA_DATA-MIC CS ''OTR''.'.
      APPEND lt_out. CLEAR lt_out.
      lt_out-line =
        '          WA_DATA-BARRIER_TYPE = ''OTR''.'.
      APPEND lt_out. CLEAR lt_out.
      lt_out-line =
        '        ELSEIF WA_DATA-MIC CS ''O2TR''.'.
      APPEND lt_out. CLEAR lt_out.
      lt_out-line =
        '          WA_DATA-BARRIER_TYPE = ''OTR''.'.
      APPEND lt_out. CLEAR lt_out.
      lt_out-line = '        ENDIF.'.
      APPEND lt_out. CLEAR lt_out.
      lv_doneb1 = 'X'.
      CONTINUE.
    ENDIF.
  ENDIF.
  " Patch 6: Barrier before APPEND IT_DATA_TMP
  IF lv_donea = ' ' AND lv_skipa = ' '.
    IF lt_src-line CS 'APPEND IT_DATA_TMP TO IT_DATA.'.
      lv_skipa = 'X'.
      CONCATENATE '        CLEAR '
                  'IT_DATA_TMP-BARRIER_TYPE.'
                  INTO lt_out-line.
      APPEND lt_out. CLEAR lt_out.
      lt_out-line =
        '        IF IT_DATA_TMP-MIC CS ''MVTR''.'.
      APPEND lt_out. CLEAR lt_out.
      lt_out-line =
        '          IT_DATA_TMP-BARRIER_TYPE = ''MVTR''.'.
      APPEND lt_out. CLEAR lt_out.
      lt_out-line =
        '        ELSEIF IT_DATA_TMP-MIC CS ''WVTR''.'.
      APPEND lt_out. CLEAR lt_out.
      lt_out-line =
        '          IT_DATA_TMP-BARRIER_TYPE = ''MVTR''.'.
      APPEND lt_out. CLEAR lt_out.
      lt_out-line =
        '        ELSEIF IT_DATA_TMP-MIC CS ''OTR''.'.
      APPEND lt_out. CLEAR lt_out.
      lt_out-line =
        '          IT_DATA_TMP-BARRIER_TYPE = ''OTR''.'.
      APPEND lt_out. CLEAR lt_out.
      lt_out-line =
        '        ELSEIF IT_DATA_TMP-MIC CS ''O2TR''.'.
      APPEND lt_out. CLEAR lt_out.
      lt_out-line =
        '          IT_DATA_TMP-BARRIER_TYPE = ''OTR''.'.
      APPEND lt_out. CLEAR lt_out.
      lt_out-line = '        ENDIF.'.
      APPEND lt_out. CLEAR lt_out.
      lt_out-line = '        APPEND IT_DATA_TMP TO IT_DATA.'.
      APPEND lt_out. CLEAR lt_out.
      lv_skipa = ' '. lv_donea = 'X'.
      CONTINUE.
    ENDIF.
  ENDIF.
  lt_out-line = lt_src-line.
  APPEND lt_out. CLEAR lt_out.
ENDLOOP.
CALL FUNCTION 'RPY_PROGRAM_UPDATE'
  EXPORTING
    PROGRAM_NAME      = 'ZQMI_CERTIFICATE_F01_CPY'
    DEVELOPMENT_CLASS = '$TMP'
    TRANSPORT_NUMBER  = ' '
  TABLES
    SOURCE_EXTENDED   = lt_out
  EXCEPTIONS
    CANCELLED         = 1
    PERMISSION_ERROR  = 2
    NOT_FOUND         = 3
    OTHERS            = 4.
IF SY-SUBRC = 0.
  COMMIT WORK AND WAIT.
  WRITE: / 'F01 Part-B OK'.
ELSE.
  WRITE: / 'ERROR F01-B:', SY-SUBRC.
ENDIF.
```

---

## 10. Verifikasi Setelah Push

Setelah 3 push berhasil (TOP, F01-A, F01-B), verifikasi dengan membaca kembali dari SAP:

```
mcp__sap-leader-mcp__read_program → ZQMI_CERTIFICATE_TOP_CPY
  → Cari: BARRIER_TYPE TYPE C LENGTH 4 (di IT_DATA dan IT_MIC1)
  → Cari: KUNNR LIKE ZMAP_COA-KUNNR (di IT_ZMAP)

mcp__sap-leader-mcp__read_program → ZQMI_CERTIFICATE_F01_CPY
  → Cari: LV_KUNNR LIKE ZMAP_COA-KUNNR
  → Cari: SELECT SINGLE KUNAG INTO LV_KUNNR
  → Cari: IF LV_KUNNR IS NOT INITIAL (verifikasi customer-aware)
  → Cari: CS 'MVTR' (verifikasi barrier detection)
```

---

## 11. Isu yang Diketahui & Bug Fix

- **GET_MIC bug**: Original `IF INS2 IS NOT INITIAL` yang digunakan sebagai guard untuk `INS3`/`INS4` loop → seharusnya `IF INS3/INS4 IS NOT INITIAL`. **Status**: sudah diperbaiki di workspace F01 file (periksa di bagian FORM GET_MIC)
- `Z_RFC_PROGRAM_UPDATE` broken → selalu gunakan `RFC_ABAP_INSTALL_AND_RUN` bootstrap
- Server `dev` = TRD (baca source), server `sandbox-new` = TRS (push)

---

## 12. Selanjutnya (Post-Enhancement)

Setelah TOP dan F01 berhasil di-push dan diverifikasi:
1. Test di SAP TRS dengan delivery order aktual
2. Cek apakah BARRIER_TYPE terisi dengan benar di ALV output
3. Cek apakah customer-specific mapping berfungsi (buat test data di ZMAP_COA dengan KUNNR terisi)
4. Transportasi ke QA setelah testing selesai (SE09/STMS)
