# Review & Summary: Scenario Test Barrier
**File:** Scenario Test Barrier.xlsm  
**Tanggal Review:** 2026-07-08  
**Reviewer:** Continuity Master AI (Claude)  
**Referensi:** RAG SAP QM Blueprint, COA Project Knowledge Base

---

## 1. Struktur File

File berisi **10 sheet** yang mencakup dua kelompok besar pengujian:

| Sheet | Isi |
|---|---|
| Template | Blank template test script |
| Tabular List | Daftar 8 skenario ZQM004 (barrier inspection dasar) |
| Flow List | Index 22 flow PP01–PP05 |
| PP01.A | Happy path: Approval Lurus PASS/NCR (10 test steps) |
| PP05.A–PP05.F | Complex path: FAIL OTR 3x → WVTR berlanjut FAIL (~50 test steps, 6 sheet) |

---

## 2. Program yang Terlibat dalam Test

| TCode | Program | Status Dev | Keterangan |
|---|---|---|---|
| ZQM004 | ZQMI_PENDING_BARRIER | ✅ Exists (patch pending upload) | Barrier inspection input & UD |
| ZQM004P | — | ❓ Belum diverifikasi | Create Inspection Lot (step terpisah) |
| ZEQM039 | — | ❌ Tidak ada di dev scope saat ini | Entry/recording inspeksi barrier WVTR/OTR |
| ZEQM040 | — | ❌ Tidak ada di dev scope saat ini | Approve barrier inspection result |
| ZEQM044 | — | ❌ Tidak ada di dev scope saat ini | Report (7 view: Inspection, Summary, Record, Pass/Fail, SR Position, Map Result, COA Data) |
| QA32 | Standard SAP | ✅ Standard | Cek inspection lot & result |

> **Critical Gap:** ZEQM039, ZEQM040, ZEQM044 muncul di hampir semua flow PP01 dan PP05, tapi program ini **belum ada di scope development saat ini**. Ini adalah gap terbesar antara test scenario dan implementasi.

---

## 3. Skenario QM01–QM08 (Sheet: Tabular List)

Semua skenario menggunakan **ZQM004** dan **QA32**. Status: **Done – Aisyah** (sudah dieksekusi cycle 1).

| Kode | Skenario | Step | Gap / Catatan |
|---|---|---|---|
| QM01 | Inspeksi Kurang dari Cycle | 2 | Menguji perilaku saat cycle belum lengkap. ✅ Seharusnya sudah handled di ZQMI_PENDING_BARRIER |
| QM02 | Inspeksi Status OK | 2 | Happy path – semua nilai dalam batas. ✅ |
| QM03 | Inspeksi Status NOT OK | 2 | Nilai di luar batas. ✅ |
| **QM04** | **MVTR OK / OTR NOT OK** | 2 | **Validasi langsung untuk P1 Fix BARRIER_TYPE.** BARRIER_TYPE harus dibedakan MVTR vs OTR. ✅ Fix sudah diimplementasi |
| QM05 | Edit Inspeksi NOT OK → OK | 3 | Ubah nilai setelah UD, re-inspect. Perlu Cancel UD → edit → re-UD |
| QM06 | SR sudah Inspeksi sebelumnya | 3 | Lot sudah punya UD. Menguji re-open & overwrite. Terkait `HAS_UD` flag di ZQMI_PENDING_BARRIER |
| **QM07** | **2 Sampel 1 JR – Delete Sampel 1 NOT OK** | 9 | **Skenario conflict C2.** Sampel 1 diinspeksi NOT OK, lalu Sampel 2 dibuat dan diinspeksi. Kemudian Sampel 1 yang NOT OK dihapus. Menguji conflict detection & resolution antar SR sibling. ⚠️ Patch ZQMI_PENDING_BARRIER (C2 detection + PROPAGATE) **belum diupload ke sandbox-new** |
| **QM08** | **2 Sampel 1 JR – Delete Beda Sampel** | 9 | **Skenario conflict C2 lebih kompleks.** Sampel berbeda (WVTR & OTR) yang NOT OK dihapus. Menguji bahwa delete 1 MIC tidak merusak decision MIC lainnya. ⚠️ Sama — patch belum upload |

---

## 4. Flow PP01.A — Happy Path: Approval Lurus PASS/NCR

**Skenario:** OTR Times 1 PASS, NCR PASS → Approved → COA OK

| Step | TCode | Deskripsi | Status |
|---|---|---|---|
| PP01.A.1 | ZEQM039 | Inspeksi OTR Times 1 – PASS NCR PASS | Template (belum diisi) |
| PP01.A.2 | ZEQM040 | Approve OTR Times 1 | Template |
| PP01.A.3 | ZEQM039 | Cek Inspeksi OTR Lock | Template |
| PP01.A.4 | ZEQM044 | Report WVTR & OTR Barrier Inspection | Template |
| PP01.A.5 | ZEQM044 | Report Summary WVTR & OTR Barrier Inspection | Template |
| PP01.A.6 | ZEQM044 | Report WVTR & OTR Inspection Record | Template |
| PP01.A.7 | ZEQM044 | Report Barrier Inspection Pass & Fail Decision | Template |
| PP01.A.8 | ZEQM044 | Report Barrier Judgement SR Position | Template |
| PP01.A.9 | ZEQM044 | Report Barrier Map Result | Template |
| PP01.A.10 | ZEQM044 | Report COA Data | Template |

> **Catatan:** Semua field masih placeholder `[Field N]` / `[Value From N]`. PP01.A **belum dieksekusi** — masih template kosong. Program ZEQM039, ZEQM040, ZEQM044 **perlu dikembangkan** sebelum test ini bisa dijalankan.

---

## 5. Flow PP05.A–F — Complex Path: FAIL OTR 3x → WVTR Berlanjut FAIL

Skenario ini adalah **sequential multi-cycle test** yang dibagi ke 6 sheet (setiap sheet 10 step, total ±50 step):

| Sheet | Step | Skenario |
|---|---|---|
| PP05.A | 1–10 | OTR Times 1 FAIL → Approve → Cek Lock → Report (7 view) |
| PP05.B | 11–20 | OTR Times 2 FAIL → Approve → Cek Lock → Report (7 view) |
| PP05.C | 21–30 | OTR Times 3 FAIL → Approve → **OTR terkunci** → Report (7 view) |
| PP05.D | 31–40 | WVTR Times 1 – NCR FAIL PASS → Approve → Cek Lock → Report |
| PP05.E | 41–50 | OTR Times 4 (C = Conditional?) FAIL → Approve → Cek Lock → Report |
| PP05.F | 50+ | WVTR Times 2 (C) – NCR → Approve → Report COA Data (final) |

**Business Logic yang diuji:**
- Setelah OTR gagal 3 kali berturut-turut → sistem harus **lock OTR** dan beralih ke WVTR
- WVTR punya jalur sendiri: NCR FAIL PASS (ada approval NCR)
- "Times C" (PP05.E, PP05.F) → kemungkinan berarti Conditional/Cancel cycle sebelumnya

> **Status:** Semua PP05 sheet masih **template kosong**. Memerlukan ZEQM039/ZEQM040/ZEQM044 yang belum ada.

---

## 6. Gap Analysis — Test vs Implementasi Saat Ini

| # | Gap | Severity | Status |
|---|---|---|---|
| G1 | ZEQM039 (recording inspeksi barrier) belum ada | 🔴 Critical | Tidak ada di dev scope |
| G2 | ZEQM040 (approval barrier) belum ada | 🔴 Critical | Tidak ada di dev scope |
| G3 | ZEQM044 (7 view reporting) belum ada | 🔴 Critical | Tidak ada di dev scope |
| G4 | ZQM004P (Create Inspection Lot) belum diverifikasi | 🟡 High | Perlu konfirmasi apakah ini program terpisah atau bagian ZQM004 |
| G5 | ZQMI_PENDING_BARRIER patch (C2 conflict + PROPAGATE) belum upload ke sandbox-new | 🟡 High | Bootstrap pending dari session sebelumnya |
| G6 | PP01.A–PP05.F seluruhnya template kosong | 🟡 High | Menunggu ZEQM039/40/44 selesai |
| G7 | Business rule "OTR lock setelah 3x FAIL" belum didokumentasikan di COA/ZQMI_PENDING_BARRIER | 🟠 Medium | Perlu requirement detail dari business |
| G8 | NCR (Non-Conformance Report) approval flow (lihat PP01.A.1 "PASS NCR PASS") belum diimplementasi | 🟠 Medium | Terlihat ada approval NCR tersendiri |
| G9 | ZQMI_COA belum handle last-cycle value untuk non-barrier MIC (P2) | 🟠 Medium | Sedang direncanakan |
| G10 | Semua PP flow baru Cycle 1 — belum ada rencana Cycle 2 | 🟢 Low | Normal untuk UAT awal |

---

## 7. Mapping Test ke Kode yang Sudah Ada

| Test Scenario | Program | Fix Sudah Ada? | Catatan |
|---|---|---|---|
| QM04 – MVTR OK/OTR NOT OK | ZQMI_PENDING_BARRIER → ZQMI_COA_F01 | ✅ P1 Fix (BARRIER_TYPE MVTR/OTR) | Fix sudah upload ke sandbox-new 2026-07-08 |
| QM06 – SR sudah ada UD | ZQMI_PENDING_BARRIER | ✅ HAS_UD flag | Sudah ada di versi dev |
| QM07 – Conflict 2 Sampel delete 1 | ZQMI_PENDING_BARRIER | ⚠️ Ada tapi belum upload | C2 detection + PROPAGATE patch di `/tmp/zqmi_barrier_patched.txt` |
| QM08 – Conflict WVTR & OTR delete | ZQMI_PENDING_BARRIER | ⚠️ Ada tapi belum upload | Sama dengan QM07 |
| PP01.A.10 – COA Data dari ZEQM044 | ZQMI_COA (ZQM002) | ✅ Partial | ZQM002 sudah ada, tapi Method SELECT dan BARRIER_TYPE baru difix (P1) |
| PP05 – Multi-cycle OTR 3x fail | ZEQM039/040 | ❌ Belum ada | Program baru perlu dibuat |

---

## 8. Rekomendasi Prioritas

**Segera (Blocker sebelum PP flow bisa ditest):**
1. Upload ZQMI_PENDING_BARRIER patch ke sandbox-new (Task #7 dari session sebelumnya) — ini unlock QM07, QM08
2. Konfirmasi scope ZEQM039/ZEQM040/ZEQM044 — apakah program ini sudah ada di system lain atau perlu dibuat dari nol?
3. Clarifikasi ZQM004P — apakah terpisah dari ZQM004 atau fitur di dalam ZQM004?

**Jangka Menengah:**
4. Dokumentasikan business rule "lock OTR setelah N kali FAIL" ke dalam ZMAP_TYPE atau hardcode logika
5. Implement P2 fix di ZQMI_COA (last-cycle value untuk non-barrier MIC)
6. Isi test data PP01.A dan PP05.A terlebih dahulu setelah ZEQM039/40/44 ready

**Jangka Panjang:**
7. Jadwalkan Cycle 2 setelah semua Cycle 1 PP flow selesai
8. Cleanup developer comments di ZQMI_COA_F01 sebelum transport ke QAS

---

## 9. Kesimpulan

Test scenario dari tim sudah **well-structured** — mencakup happy path, edge cases (multi-cycle fail), dan conflict resolution (multi-sampel). Namun ada **gap fundamental**: program ZEQM039, ZEQM040, ZEQM044 yang menjadi backbone dari seluruh PP flow **belum ada**. Tanpa ketiga program ini, **36 dari ~52 total test step** di PP01 dan PP05 tidak bisa dieksekusi.

Skenario ZQM004 (QM01–QM08) lebih siap — sudah ada program, sudah Cycle 1 Done, tinggal upload patch C2 conflict untuk unlock QM07 dan QM08.

Dari sisi ZQMI_COA, fix P1 yang baru selesai (2026-07-08) langsung menjawab kebutuhan QM04 (BARRIER_TYPE MVTR/OTR) dan PP01.A.10 (COA Data dengan method yang customer-aware).
