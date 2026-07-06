*&---------------------------------------------------------------------*
*& Report     :  ZMAP_COA                                              *
*& Appl. Area :  QM / MM                                               *
*& Created by :  J. Budi                                                *
*& Created on :  23 Mei 2022 (Updated for COA Mapping)                 *
*&---------------------------------------------------------------------*

REPORT  ZMAP_COA.

TABLES: ZMAP_COA, KNA1.

CLASS LCL_EVENT_RECEIVER DEFINITION DEFERRED.  "for event handling

DATA: OK_CODE             LIKE SY-UCOMM,
      SAVE_OK             LIKE SY-UCOMM,
      DIALOG_BOX          TYPE REF TO CL_GUI_DIALOGBOX_CONTAINER,
      GRID1               TYPE REF TO CL_GUI_ALV_GRID,
      G_CUSTOM_CONTAINER  TYPE REF TO CL_GUI_CUSTOM_CONTAINER,
      GS_LAYOUT           TYPE LVC_S_LAYO,
      G_MAX               TYPE I VALUE 10,
      GT_FIELDCAT         TYPE LVC_T_FCAT,
      G_EVENT_RECEIVER    TYPE REF TO LCL_EVENT_RECEIVER,
      GS_VARIANT          TYPE DISVARIANT,
      LT_ROW_NO           TYPE LVC_T_ROID WITH HEADER LINE,
      WA_S_F4             TYPE LVC_S_F4 OCCURS 0,
      IT_S_F4             TYPE LVC_S_F4,
      IT_T_F4             TYPE LVC_T_F4.

DATA: GT_STABLE TYPE LVC_S_STBL.

DATA: BEGIN OF ITAB OCCURS 0.
        INCLUDE STRUCTURE ZMAP_COA.
DATA: NAME1 LIKE KNA1-NAME1.
DATA: ATWTB LIKE CAWNT-ATWTB.
DATA: CREATED1 TYPE C LENGTH 50.
DATA: CREATED2 TYPE C LENGTH 50.
DATA: BOX(1).
DATA: REMARK(100).
DATA: LINE_COLOR TYPE C LENGTH 4.
DATA: END OF ITAB.

DATA: IT_CHAR     TYPE STANDARD TABLE OF ZMAP_COA.
DATA: ITAB_TEMP   LIKE ITAB OCCURS 0 WITH HEADER LINE.

* >>> NEW CODE: Internal table untuk upload notepad
DATA: BEGIN OF IT_UPLOAD OCCURS 0,
        MATNR   TYPE ZMAP_COA-MATNR,
        MIC     TYPE ZMAP_COA-MIC,
        NAME1   TYPE KNA1-NAME1,
        METHOD  TYPE ZMAP_COA-METHOD,
        MAPPING TYPE ZMAP_COA-MAPPING,
      END OF IT_UPLOAD.
* <<< END OF NEW CODE

DATA: V_MSG       TYPE STRING,
      V_ANS(5)    TYPE C,
      V_ERR       TYPE C LENGTH 4 VALUE 'C600',
      V_OK        TYPE C LENGTH 4.

SELECTION-SCREEN BEGIN OF BLOCK BLK0 WITH FRAME TITLE TEXT-001.



PARAMETERS : R_UPL RADIOBUTTON GROUP R_UP USER-COMMAND AC DEFAULT 'X', " >>> NEW CODE: Radiobutton Upload
             R_CRT RADIOBUTTON GROUP R_UP,
             R_EDT RADIOBUTTON GROUP R_UP,
             R_DSP RADIOBUTTON GROUP R_UP.
SELECTION-SCREEN END OF BLOCK BLK0.

* >>> NEW CODE: Parameter untuk file upload
SELECTION-SCREEN BEGIN OF BLOCK BLK_UPL WITH FRAME TITLE TEXT-UPL.
PARAMETERS : P_FILE TYPE RLGRAP-FILENAME MODIF ID UPL.
SELECTION-SCREEN END OF BLOCK BLK_UPL.
* <<< END OF NEW CODE

SELECTION-SCREEN BEGIN OF BLOCK BLK1 WITH FRAME TITLE TEXT-002.
SELECT-OPTIONS: P_MATNR FOR ZMAP_COA-MATNR  MODIF ID PRM.
SELECT-OPTIONS: P_MIC   FOR ZMAP_COA-MIC    MODIF ID PRM.
SELECT-OPTIONS: P_NAME1 FOR KNA1-NAME1      MODIF ID PRM.
SELECT-OPTIONS: P_METH  FOR ZMAP_COA-METHOD MODIF ID PRM.
SELECT-OPTIONS: P_MAP   FOR ZMAP_COA-MAPPING MODIF ID PRM.
SELECTION-SCREEN END OF BLOCK BLK1.

SELECTION-SCREEN BEGIN OF BLOCK BLK2 WITH FRAME TITLE TEXT-003.
PARAMETER: R_MATNR RADIOBUTTON GROUP RB DEFAULT 'X' MODIF ID PRM.
PARAMETER: R_MIC   RADIOBUTTON GROUP RB MODIF ID PRM.
PARAMETER: R_NAME1 RADIOBUTTON GROUP RB MODIF ID PRM.
SELECTION-SCREEN END OF BLOCK BLK2.

SELECTION-SCREEN BEGIN OF BLOCK BLK3 WITH FRAME TITLE TEXT-004.
PARAMETER: R_DEL AS CHECKBOX DEFAULT 'X' MODIF ID DEL.
SELECTION-SCREEN END OF BLOCK BLK3.

* >>> NEW CODE: F4 Help untuk File Path
AT SELECTION-SCREEN ON VALUE-REQUEST FOR P_FILE.
  CALL FUNCTION 'F4_FILENAME'
    EXPORTING
      PROGRAM_NAME  = SY-CPROG
      DYNPRO_NUMBER = SY-DYNNR
      FIELD_NAME    = 'P_FILE'
    IMPORTING
      FILE_NAME     = P_FILE.
* <<< END OF NEW CODE

AT SELECTION-SCREEN ON VALUE-REQUEST FOR P_MATNR-LOW.
  PERFORM F_HELP USING 'Material Help List' 'P_MATNR' 'MATNR'.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR P_MIC-LOW.
  PERFORM F_HELP USING 'MIC Help List' 'P_MIC' 'MIC'.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR P_NAME1-LOW.
  PERFORM F_HELP USING 'Customer Help List' 'P_NAME1' 'NAME1'.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR P_METH-LOW.
  PERFORM F_HELP USING 'Method Help List' 'P_METH' 'METHOD'.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR P_MAP-LOW.
  PERFORM F_HELP USING 'Mapping Help List' 'P_MAP' 'MAPPING'.

*----------------------------------------------------------------------*
* CLASS LCL_EVENT_RECEIVER DEFINITION
*----------------------------------------------------------------------*
CLASS LCL_EVENT_RECEIVER DEFINITION.
  PUBLIC SECTION.
    METHODS: CATCH_F4
             FOR EVENT ONF4 OF CL_GUI_ALV_GRID
             IMPORTING
                E_FIELDNAME
                E_FIELDVALUE
                ES_ROW_NO.
ENDCLASS.                    "LCL_EVENT_RECEIVER DEFINITION

*----------------------------------------------------------------------*
* CLASS LCL_EVENT_RECEIVER IMPLEMENTATION
*----------------------------------------------------------------------*
CLASS LCL_EVENT_RECEIVER IMPLEMENTATION.
  METHOD CATCH_F4.
    IF E_FIELDNAME EQ 'MATNR'.
      PERFORM F_HELP_MATNR USING ES_ROW_NO-ROW_ID E_FIELDVALUE.
    ELSEIF E_FIELDNAME EQ 'MIC'.
      PERFORM F_HELP_MIC USING ES_ROW_NO-ROW_ID E_FIELDVALUE.
    ELSEIF E_FIELDNAME EQ 'KUNNR'.
      PERFORM F_HELP_KUNNR USING ES_ROW_NO-ROW_ID E_FIELDVALUE.
    ELSEIF E_FIELDNAME EQ 'METHOD'.
      PERFORM F_HELP_METHOD USING ES_ROW_NO-ROW_ID E_FIELDVALUE.
    ELSEIF E_FIELDNAME EQ 'MAPPING'.
      PERFORM F_HELP_MAPPING USING ES_ROW_NO-ROW_ID E_FIELDVALUE.
    ENDIF.

    CALL METHOD GRID1->REFRESH_TABLE_DISPLAY.
  ENDMETHOD.                    "CATCH_F4
ENDCLASS.                    "LCL_EVENT_RECEIVER IMPLEMENTATION

AT SELECTION-SCREEN OUTPUT.
* >>> NEW CODE: Hide/Show screen group based on radio button
  LOOP AT SCREEN.
    IF SCREEN-GROUP1 = 'UPL'.
      IF R_UPL = 'X'.
        SCREEN-INPUT = 1.
        SCREEN-ACTIVE = 1.
      ELSE.
        SCREEN-INPUT = 0.
        SCREEN-ACTIVE = 0.
      ENDIF.
      MODIFY SCREEN.
    ENDIF.

    IF SCREEN-GROUP1 = 'PRM'.
      IF R_CRT = 'X' OR R_UPL = 'X'.
        SCREEN-INPUT = 0.
        SCREEN-ACTIVE = 0.
      ELSE.
        SCREEN-INPUT = 1.
        SCREEN-ACTIVE = 1.
      ENDIF.
      MODIFY SCREEN.
    ENDIF.

    IF SCREEN-GROUP1 = 'DEL'.
      IF R_DSP EQ 'X'.
        SCREEN-INPUT = 1.
        SCREEN-ACTIVE = 1.
      ELSE.
        SCREEN-INPUT = 0.
        SCREEN-ACTIVE = 0.
      ENDIF.
      MODIFY SCREEN.
    ENDIF.
  ENDLOOP.
* <<< END OF NEW CODE

START-OF-SELECTION.
  IF R_CRT = 'X'.
    DO 100 TIMES.
      APPEND ITAB.
    ENDDO.
* >>> NEW CODE: Logic eksekusi saat Upload dipilih
  ELSEIF R_UPL = 'X'.
    IF P_FILE IS INITIAL.
      MESSAGE 'Please select a file to upload!' TYPE 'S' DISPLAY LIKE 'E'.
      EXIT.
    ENDIF.
    PERFORM F_UPLOAD_DATA.
    PERFORM F_CREATE_DATA. "Langsung run CREATE setelah upload
* <<< END OF NEW CODE
  ELSE.
    PERFORM GET_DATA.
    IF ITAB[] IS NOT INITIAL.
    ELSE.
      MESSAGE 'Data not found...!' TYPE 'S' DISPLAY LIKE 'E'.
      EXIT.
    ENDIF.
  ENDIF.

  CALL SCREEN 100.

END-OF-SELECTION.

*----------------------------------------------------------------------*
* MODULE awal OUTPUT
*----------------------------------------------------------------------*
MODULE AWAL OUTPUT.
  IF SY-UCOMM = ''.
    PERFORM DISPLAY_ALV.
  ENDIF.
ENDMODULE.                    "awal OUTPUT

*&---------------------------------------------------------------------*
*&      Form  GET_DATA
*&---------------------------------------------------------------------*
FORM GET_DATA.
  CLEAR ITAB. REFRESH: ITAB.

  SELECT *
  INTO CORRESPONDING FIELDS OF TABLE ITAB
  FROM ZMAP_COA
  LEFT OUTER JOIN KNA1 ON KNA1~KUNNR EQ ZMAP_COA~KUNNR
 WHERE MATNR   IN P_MATNR
   AND MIC     IN P_MIC
   AND METHOD  IN P_METH
   AND MAPPING IN P_MAP.

  IF P_NAME1[] IS NOT INITIAL.
    DELETE ITAB WHERE NAME1 NOT IN P_NAME1.
  ENDIF.

  IF R_EDT EQ 'X'.
    DELETE ITAB WHERE DELETION EQ 'X'.
  ELSEIF R_DSP EQ 'X'.
    IF R_DEL EQ ''.
      DELETE ITAB WHERE DELETION EQ 'X'.
    ENDIF.
  ENDIF.

  LOOP AT ITAB.
    IF ITAB-USNAM IS NOT INITIAL AND ITAB-TERM1 IS NOT INITIAL.
      CONCATENATE ITAB-USNAM '-' ITAB-TERM1 INTO ITAB-CREATED1.
    ELSE.
      IF ITAB-USNAM IS NOT INITIAL.
        ITAB-CREATED1 = ITAB-USNAM.
      ELSEIF ITAB-TERM1 IS NOT INITIAL.
        ITAB-CREATED1 = ITAB-TERM1.
      ENDIF.
    ENDIF.

    IF ITAB-AENAM IS NOT INITIAL AND ITAB-TERM2 IS NOT INITIAL.
      CONCATENATE ITAB-AENAM '-' ITAB-TERM2 INTO ITAB-CREATED2.
    ELSE.
      IF ITAB-AENAM IS NOT INITIAL.
        ITAB-CREATED2 = ITAB-AENAM.
      ELSEIF ITAB-TERM1 IS NOT INITIAL.
        ITAB-CREATED2 = ITAB-TERM2.
      ENDIF.
    ENDIF.

    IF ITAB-DELETION EQ 'X'.
      ITAB-LINE_COLOR = V_ERR.
    ENDIF.

    MODIFY ITAB.
  ENDLOOP.

  IF R_MATNR EQ 'X'.
    SORT ITAB BY MATNR MIC NAME1 METHOD MAPPING ASCENDING.
  ELSEIF R_MIC EQ 'X'.
    SORT ITAB BY MIC MATNR NAME1 METHOD MAPPING ASCENDING.
  ELSEIF R_NAME1 EQ 'X'.
    SORT ITAB BY NAME1 MATNR MIC METHOD MAPPING ASCENDING.
  ENDIF.

  ITAB_TEMP[] = ITAB[].

ENDFORM.                    "GET_DATA

*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_0100  INPUT
*&---------------------------------------------------------------------*
MODULE USER_COMMAND_0100 INPUT.

  CASE SY-UCOMM.
    WHEN 'EXIT'.
      SET SCREEN 0.

    WHEN 'CREATE'.
      PERFORM F_CREATE_DATA.
      CALL METHOD GRID1->REFRESH_TABLE_DISPLAY.

    WHEN 'CLEAR'.
      PERFORM F_CLEAR_DATA.
      CALL METHOD GRID1->REFRESH_TABLE_DISPLAY.

    WHEN 'CHANGE'.
      PERFORM F_CHANGE_DATA.
      CALL METHOD GRID1->REFRESH_TABLE_DISPLAY.

    WHEN 'RELOAD'.
      PERFORM GET_DATA.
      CALL METHOD GRID1->REFRESH_TABLE_DISPLAY.

    WHEN 'DELETE'.
      PERFORM F_DELETE_DATA.
      CALL METHOD GRID1->REFRESH_TABLE_DISPLAY.

    WHEN 'UNDELETE'.
      PERFORM F_UNDELETE_DATA.
      CALL METHOD GRID1->REFRESH_TABLE_DISPLAY.
  ENDCASE.

ENDMODULE.                 " USER_COMMAND_0100  INPUT

*&---------------------------------------------------------------------*
*&      Form  F_CREATE_DATA
*&---------------------------------------------------------------------*
FORM F_CREATE_DATA.
* >>> NEW CODE: Pengecekan GRID1 IS BOUND untuk menghindari dump
* saat form dipanggil dari proses Upload (sebelum layar ALV dirender).
  IF GRID1 IS BOUND.
    CALL METHOD GRID1->CHECK_CHANGED_DATA.
  ENDIF.
* <<< END OF NEW CODE

  DATA: LV_MATNR TYPE MARA-MATNR,
        LV_KUNNR TYPE KNA1-KUNNR,
        LV_MIC   TYPE QPMK-MKMNR.  " <--- Variabel tambahan untuk cek MIC

  LOOP AT ITAB.
    CLEAR: V_MSG, ITAB-REMARK, ITAB-DELETION.
    ITAB-LINE_COLOR = V_OK.

    "Check empty fill entirely
    IF ITAB-MATNR IS INITIAL AND ITAB-MIC IS INITIAL AND ITAB-KUNNR IS INITIAL AND ITAB-METHOD IS INITIAL AND ITAB-MAPPING IS INITIAL.
      CONTINUE.
    ENDIF.

    "Check empty fill mandatory
    IF ITAB-MATNR IS INITIAL.
      ITAB-REMARK = 'Please fill Material Number...!'.
      ITAB-LINE_COLOR = V_ERR.
      MODIFY ITAB.
      CONTINUE.
    ENDIF.

    " -----------------------------------------------------------------
    " 1. VALIDASI MATERIAL (MARA)
    " -----------------------------------------------------------------
    IF ITAB-MATNR IS NOT INITIAL.
      CLEAR LV_MATNR.
      " >>> NEW CODE: Formatting leading zero untuk Material saat upload
      CALL FUNCTION 'CONVERSION_EXIT_MATN1_INPUT'
        EXPORTING
          INPUT        = ITAB-MATNR
        IMPORTING
          OUTPUT       = ITAB-MATNR
        EXCEPTIONS
          LENGTH_ERROR = 1
          OTHERS       = 2.
      " <<< END OF NEW CODE

      SELECT SINGLE MATNR INTO LV_MATNR FROM MARA WHERE MATNR EQ ITAB-MATNR.
      IF SY-SUBRC NE 0.
        CONCATENATE 'Material: ' ITAB-MATNR 'is not valid/found!' INTO V_MSG SEPARATED BY SPACE.
        ITAB-REMARK     = V_MSG.
        ITAB-LINE_COLOR = V_ERR.
        MODIFY ITAB.
        CONTINUE.
      ENDIF.
    ENDIF.

    " -----------------------------------------------------------------
    " 2. VALIDASI MIC (Menyesuaikan dengan Material)
    " -----------------------------------------------------------------
    IF ITAB-MIC IS NOT INITIAL. " Jika kosong, validasi dilewati (aman)
      CLEAR LV_MIC.

      " 2a. Cek apakah MIC valid di Master Data (QPMK)
      SELECT SINGLE MKMNR INTO LV_MIC FROM QPMK WHERE MKMNR EQ ITAB-MIC.
      IF SY-SUBRC NE 0.
        CONCATENATE 'MIC: ' ITAB-MIC 'is not valid in master data!' INTO V_MSG SEPARATED BY SPACE.
        ITAB-REMARK     = V_MSG.
        ITAB-LINE_COLOR = V_ERR.
        MODIFY ITAB.
        CONTINUE.
      ENDIF.
    ENDIF.

    " -----------------------------------------------------------------
    " 3. VALIDASI CUSTOMER (KNA1)
    " -----------------------------------------------------------------
    IF ITAB-NAME1 IS NOT INITIAL.
      CLEAR LV_KUNNR.

      " Cari ID Customer (KUNNR) berdasarkan Nama (NAME1)
      SELECT SINGLE KUNNR INTO LV_KUNNR
        FROM KNA1
        WHERE NAME1 EQ ITAB-NAME1.

      IF SY-SUBRC EQ 0.
        ITAB-KUNNR = LV_KUNNR.
        MODIFY ITAB.
      ELSE.
        CONCATENATE 'Customer Name:' ITAB-NAME1 'is not valid/found!' INTO V_MSG SEPARATED BY SPACE.
        ITAB-REMARK     = V_MSG.
        ITAB-LINE_COLOR = V_ERR.
        MODIFY ITAB.
        CONTINUE.
      ENDIF.
    ENDIF.

    "Check empty fill mapping
    IF ITAB-MAPPING IS INITIAL.
      ITAB-REMARK = 'Please fill the mapping value...!'.
      ITAB-LINE_COLOR = V_ERR.
      MODIFY ITAB.
      CONTINUE.
    ENDIF.

    "Check data is exist (menghilangkan simbol @)
    SELECT SINGLE MATNR DELETION INTO (ITAB-MATNR, ITAB-DELETION)
      FROM ZMAP_COA
     WHERE MATNR   = ITAB-MATNR
       AND MIC     = ITAB-MIC
       AND KUNNR   = ITAB-KUNNR.

    IF SY-SUBRC EQ 0.
      IF ITAB-DELETION EQ 'X'.
        CONCATENATE ITAB-MATNR ': Mapping' ITAB-MAPPING 'is mark for deletion...!' INTO V_MSG SEPARATED BY SPACE.
        ITAB-REMARK     = V_MSG.
        ITAB-LINE_COLOR = V_ERR.
        MODIFY ITAB.
        CONTINUE.
      ELSE.
        CONCATENATE ITAB-MATNR ': Mapping' ITAB-MAPPING 'is exist...!' INTO V_MSG SEPARATED BY SPACE.
        ITAB-REMARK     = V_MSG.
        ITAB-LINE_COLOR = V_ERR.
        MODIFY ITAB.
        CONTINUE.
      ENDIF.
    ENDIF.

    ITAB-CPUDT = SY-DATUM.
    ITAB-CPUTM = SY-UZEIT.
    ITAB-USNAM = SY-UNAME.

    CALL FUNCTION 'TERMINAL_ID_GET'
      EXPORTING
        USERNAME = SY-UNAME
      IMPORTING
        TERMINAL = ITAB-TERM1.

    INSERT ZMAP_COA FROM ITAB.

    CONCATENATE ITAB-MATNR ': Mapping' ITAB-MAPPING 'Successfully added...!' INTO V_MSG SEPARATED BY SPACE.

    ITAB-REMARK = V_MSG.
    MODIFY ITAB.

  ENDLOOP.

  COMMIT WORK AND WAIT.
  IF SY-SUBRC <> 0.
    MESSAGE 'Commit gagal!' TYPE 'E'.
  ENDIF.

ENDFORM.                    "F_CREATE_DATA

* >>> NEW CODE: Form Upload Data
*&---------------------------------------------------------------------*
*&      Form  F_UPLOAD_DATA
*&---------------------------------------------------------------------*
FORM F_UPLOAD_DATA.
  DATA: LV_FILENAME TYPE STRING.
  LV_FILENAME = P_FILE.

  CLEAR IT_UPLOAD[].

  " Upload file TXT/Notepad (Tab-delimited)
  CALL FUNCTION 'GUI_UPLOAD'
    EXPORTING
      FILENAME            = LV_FILENAME
      FILETYPE            = 'ASC'
      HAS_FIELD_SEPARATOR = 'X'
    TABLES
      DATA_TAB            = IT_UPLOAD
    EXCEPTIONS
      FILE_OPEN_ERROR     = 1
      FILE_READ_ERROR     = 2
      OTHERS              = 17.

  IF SY-SUBRC <> 0.
    MESSAGE 'Error saat membaca file upload!' TYPE 'I' DISPLAY LIKE 'E'.
    EXIT.
  ENDIF.

  CLEAR ITAB[].
  DATA: LV_FIRST TYPE C VALUE 'X'.
  LOOP AT IT_UPLOAD.
    IF LV_FIRST EQ 'X'.
      CLEAR LV_FIRST.
      CONTINUE.
    ENDIF.
    CLEAR ITAB.
    ITAB-MATNR   = IT_UPLOAD-MATNR.
    ITAB-MIC     = IT_UPLOAD-MIC.
    ITAB-NAME1   = IT_UPLOAD-NAME1.
    ITAB-METHOD  = IT_UPLOAD-METHOD.
    ITAB-MAPPING = IT_UPLOAD-MAPPING.
    APPEND ITAB.
  ENDLOOP.
ENDFORM.                    "F_UPLOAD_DATA
* <<< END OF NEW CODE

*&---------------------------------------------------------------------*
*&      Form  F_CHANGE_DATA (Sisa kode ke bawah sama)
*&---------------------------------------------------------------------*
FORM F_CHANGE_DATA.
  CALL METHOD GRID1->CHECK_CHANGED_DATA.

  LOOP AT ITAB.
    CLEAR: V_MSG, ITAB-REMARK.
    ITAB-LINE_COLOR = V_OK.

    "Check empty fill mapping
    IF ITAB-MAPPING IS INITIAL.
      ITAB-REMARK = 'Please fill the mapping value...!'.
      ITAB-LINE_COLOR = V_ERR.
      MODIFY ITAB.
      CONTINUE.
    ENDIF.

    READ TABLE ITAB_TEMP WITH KEY MATNR = ITAB-MATNR MIC = ITAB-MIC KUNNR = ITAB-KUNNR.

    IF SY-SUBRC EQ 0.
      IF ITAB_TEMP-MAPPING NE ITAB-MAPPING OR ITAB_TEMP-METHOD NE ITAB-METHOD.
        " Ada perubahan -> lanjut ke UPDATE
      ELSE.
        CONCATENATE 'No update on Material' ITAB-MATNR 'and MIC' ITAB-MIC INTO V_MSG SEPARATED BY SPACE.
        ITAB-REMARK = V_MSG.
        MODIFY ITAB.
        CONTINUE.
      ENDIF.
    ELSE.
      CONTINUE.
    ENDIF.

    ITAB-AEDAT = SY-DATUM.
    ITAB-PSOTM = SY-UZEIT.
    ITAB-AENAM = SY-UNAME.

    CALL FUNCTION 'TERMINAL_ID_GET'
      EXPORTING
        USERNAME = SY-UNAME
      IMPORTING
        TERMINAL = ITAB-TERM2.

    UPDATE ZMAP_COA
    SET
    MAPPING = ITAB-MAPPING
    METHOD  = ITAB-METHOD
    AEDAT   = ITAB-AEDAT
    PSOTM   = ITAB-PSOTM
    AENAM   = ITAB-AENAM
    TERM2   = ITAB-TERM2
    WHERE MATNR = ITAB-MATNR AND MIC = ITAB-MIC AND KUNNR = ITAB-KUNNR.

    IF ITAB_TEMP-MAPPING <> ITAB-MAPPING.
      CONCATENATE V_MSG 'Mapping' ITAB-MAPPING INTO V_MSG SEPARATED BY SPACE.
    ENDIF.

    CONCATENATE V_MSG 'Successfully updated on Material' ITAB-MATNR 'and MIC' ITAB-MIC '...!' INTO V_MSG SEPARATED BY SPACE.

    ITAB-REMARK = V_MSG.
    MODIFY ITAB.

  ENDLOOP.

  COMMIT WORK AND WAIT.
  IF SY-SUBRC <> 0.
    MESSAGE 'Commit gagal!' TYPE 'E'.
  ENDIF.

  SELECT *
    INTO CORRESPONDING FIELDS OF TABLE ITAB_TEMP
    FROM ZMAP_COA
    LEFT OUTER JOIN KNA1 ON KNA1~KUNNR EQ ZMAP_COA~KUNNR
   WHERE MATNR   IN P_MATNR
     AND MIC     IN P_MIC
     AND METHOD  IN P_METH
     AND MAPPING IN P_MAP.

  IF P_NAME1[] IS NOT INITIAL.
    DELETE ITAB_TEMP WHERE NAME1 NOT IN P_NAME1.
  ENDIF.

ENDFORM.                    "F_CHANGE_DATA

*&---------------------------------------------------------------------*
*&      Form  F_DELETE_DATA
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
FORM F_DELETE_DATA.
  CALL METHOD GRID1->CHECK_CHANGED_DATA.

  PERFORM SELECT_LINES.

  READ TABLE ITAB WITH KEY BOX = 'X'.
  IF SY-SUBRC NE 0.
    EXIT.
  ENDIF.

  CLEAR: V_ANS.
  CALL FUNCTION 'POPUP_TO_CONFIRM'
    EXPORTING
      TITLEBAR              = 'Confirmation'
      TEXT_QUESTION         = 'Are you sure want to delete data?'
      TEXT_BUTTON_1         = 'Yes'
      TEXT_BUTTON_2         = 'No'
      DEFAULT_BUTTON        = '2'
      DISPLAY_CANCEL_BUTTON = ''
    IMPORTING
      ANSWER                = V_ANS.

  IF V_ANS NE 1.
    EXIT.
  ENDIF.

  LOOP AT ITAB WHERE BOX = 'X'.
    CLEAR: V_MSG, ITAB-REMARK.

    ITAB-AEDAT = SY-DATUM.
    ITAB-PSOTM = SY-UZEIT.
    ITAB-AENAM = SY-UNAME.
    ITAB-DELETION = 'X'.

    CALL FUNCTION 'TERMINAL_ID_GET'
      EXPORTING
        USERNAME = SY-UNAME
      IMPORTING
        TERMINAL = ITAB-TERM2.

    UPDATE ZMAP_COA
    SET
    AEDAT    = ITAB-AEDAT
    PSOTM    = ITAB-PSOTM
    AENAM    = ITAB-AENAM
    TERM2    = ITAB-TERM2
    DELETION = ITAB-DELETION
    WHERE MATNR = ITAB-MATNR AND MIC = ITAB-MIC AND KUNNR = ITAB-KUNNR AND METHOD = ITAB-METHOD AND MAPPING = ITAB-MAPPING.

    CONCATENATE 'Material' ITAB-MATNR 'and MIC' ITAB-MIC ':' ITAB-MAPPING 'successfully deleted...!' INTO V_MSG SEPARATED BY SPACE.

    ITAB-REMARK = V_MSG.
    MODIFY ITAB.
  ENDLOOP.

  COMMIT WORK AND WAIT.
  IF SY-SUBRC <> 0.
    MESSAGE 'Commit gagal!' TYPE 'E'.
  ENDIF.

  SELECT *
    INTO CORRESPONDING FIELDS OF TABLE ITAB_TEMP
    FROM ZMAP_COA
    LEFT OUTER JOIN KNA1 ON KNA1~KUNNR EQ ZMAP_COA~KUNNR
   WHERE MATNR   IN P_MATNR
     AND MIC     IN P_MIC
     AND METHOD  IN P_METH
     AND MAPPING IN P_MAP.

  IF P_NAME1[] IS NOT INITIAL.
    DELETE ITAB_TEMP WHERE NAME1 NOT IN P_NAME1.
  ENDIF.

ENDFORM.                    "F_DELETE_DATA

*&---------------------------------------------------------------------*
*&      Form  F_UNDELETE_DATA
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
FORM F_UNDELETE_DATA.
  CALL METHOD GRID1->CHECK_CHANGED_DATA.

  PERFORM SELECT_LINES.

  READ TABLE ITAB WITH KEY BOX = 'X'.
  IF SY-SUBRC NE 0.
    EXIT.
  ENDIF.

  READ TABLE ITAB WITH KEY BOX = 'X' DELETION = 'X'.
  IF SY-SUBRC NE 0.
    EXIT.
  ENDIF.

  CLEAR: V_ANS.
  CALL FUNCTION 'POPUP_TO_CONFIRM'
    EXPORTING
      TITLEBAR              = 'Confirmation'
      TEXT_QUESTION         = 'Are you sure want to undeletion flag?'
      TEXT_BUTTON_1         = 'Yes'
      TEXT_BUTTON_2         = 'No'
      DEFAULT_BUTTON        = '2'
      DISPLAY_CANCEL_BUTTON = ''
    IMPORTING
      ANSWER                = V_ANS.

  IF V_ANS NE 1.
    EXIT.
  ENDIF.

  LOOP AT ITAB WHERE BOX = 'X' AND DELETION EQ 'X'.
    CLEAR: V_MSG, ITAB-REMARK.

    ITAB-AEDAT = SY-DATUM.
    ITAB-PSOTM = SY-UZEIT.
    ITAB-AENAM = SY-UNAME.
    ITAB-DELETION = ''.

    CALL FUNCTION 'TERMINAL_ID_GET'
      EXPORTING
        USERNAME = SY-UNAME
      IMPORTING
        TERMINAL = ITAB-TERM2.

    UPDATE ZMAP_COA
    SET
    AEDAT    = ITAB-AEDAT
    PSOTM    = ITAB-PSOTM
    AENAM    = ITAB-AENAM
    TERM2    = ITAB-TERM2
    DELETION = ITAB-DELETION
    WHERE MATNR = ITAB-MATNR AND MIC = ITAB-MIC AND KUNNR = ITAB-KUNNR AND METHOD = ITAB-METHOD AND MAPPING = ITAB-MAPPING.

    CONCATENATE 'Material' ITAB-MATNR 'and MIC' ITAB-MIC ':' ITAB-MAPPING 'successfully undeletion flag...!' INTO V_MSG SEPARATED BY SPACE.

    ITAB-REMARK = V_MSG.
    MODIFY ITAB.
  ENDLOOP.

  COMMIT WORK AND WAIT.
  IF SY-SUBRC <> 0.
    MESSAGE 'Commit gagal!' TYPE 'E'.
  ENDIF.

  SELECT *
    INTO CORRESPONDING FIELDS OF TABLE ITAB_TEMP
    FROM ZMAP_COA
    LEFT OUTER JOIN KNA1 ON KNA1~KUNNR EQ ZMAP_COA~KUNNR
   WHERE MATNR   IN P_MATNR
     AND MIC     IN P_MIC
     AND METHOD  IN P_METH
     AND MAPPING IN P_MAP.

  IF P_NAME1[] IS NOT INITIAL.
    DELETE ITAB_TEMP WHERE NAME1 NOT IN P_NAME1.
  ENDIF.

  PERFORM GET_DATA.
ENDFORM.                    "F_UNDELETE_DATA

*&---------------------------------------------------------------------*
*&      Form  F_CLEAR_DATA
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
FORM F_CLEAR_DATA.
  DELETE ITAB WHERE MATNR IS NOT INITIAL.
ENDFORM.                    "F_CLEAR_DATA

*&---------------------------------------------------------------------*
*&      Form  DISPLAY_ALV
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
FORM DISPLAY_ALV.
  DATA: LT_EXCLUDE TYPE UI_FUNCTIONS.

  PERFORM PREPARE_LAYOUT CHANGING GS_LAYOUT .
  PERFORM PREPARE_FIELD_CATALOG CHANGING GT_FIELDCAT .
* >>> NEW CODE: Sesuaikan ekslusi toolbar ALV agar Upload mirip dengan Create
  IF R_CRT <> 'X' AND R_UPL <> 'X'.
    PERFORM EXCLUDE_TB_FUNCTIONS CHANGING LT_EXCLUDE .
  ENDIF.
* <<< END OF NEW CODE

  CREATE OBJECT GRID1
    EXPORTING
      I_PARENT = DIALOG_BOX.

  PERFORM GET_F4.

  CREATE OBJECT G_EVENT_RECEIVER.
  SET HANDLER G_EVENT_RECEIVER->CATCH_F4 FOR GRID1.

  CALL METHOD GRID1->REGISTER_F4_FOR_FIELDS
    EXPORTING
      IT_F4 = IT_T_F4.

  CALL METHOD GRID1->REGISTER_EDIT_EVENT
    EXPORTING
      I_EVENT_ID = CL_GUI_ALV_GRID=>MC_EVT_ENTER.

  CALL METHOD GRID1->REGISTER_EDIT_EVENT
    EXPORTING
      I_EVENT_ID = CL_GUI_ALV_GRID=>MC_EVT_MODIFIED.

  CALL METHOD GRID1->SET_TABLE_FOR_FIRST_DISPLAY
    EXPORTING
      IS_LAYOUT            = GS_LAYOUT
      IT_TOOLBAR_EXCLUDING = LT_EXCLUDE
      IS_VARIANT           = GS_VARIANT
      I_SAVE               = 'A'
    CHANGING
      IT_OUTTAB            = ITAB[]
      IT_FIELDCATALOG      = GT_FIELDCAT.
ENDFORM.                    "DISPLAY_ALV

*&---------------------------------------------------------------------*
*&      Form  SELECT_LINES
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
FORM SELECT_LINES.
  ITAB-BOX = ''.
  MODIFY ITAB TRANSPORTING BOX WHERE BOX NE ''.

  CALL METHOD GRID1->CHECK_CHANGED_DATA.

  CALL METHOD GRID1->GET_SELECTED_ROWS
    IMPORTING
      ET_ROW_NO = LT_ROW_NO[].

  LOOP AT LT_ROW_NO.
    READ TABLE ITAB INDEX LT_ROW_NO-ROW_ID.
    IF SY-SUBRC = 0.
      ITAB-BOX = 'X'.
      MODIFY ITAB INDEX LT_ROW_NO-ROW_ID.
    ENDIF.
  ENDLOOP.
ENDFORM.                    "set_lineselection

*&---------------------------------------------------------------------*
*&      Form  PREPARE_LAYOUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      -->P_GS_LAYOUT  text
*----------------------------------------------------------------------*
FORM PREPARE_LAYOUT  CHANGING P_GS_LAYOUT TYPE LVC_S_LAYO.
  P_GS_LAYOUT-SMALLTITLE  = 'X' .
  P_GS_LAYOUT-BOX_FNAME   = 'BOX'.
  P_GS_LAYOUT-EDIT        = ''.
  P_GS_LAYOUT-SEL_MODE    = 'A'.
  P_GS_LAYOUT-INFO_FNAME  = 'LINE_COLOR'.
  GS_VARIANT-REPORT       = SY-REPID.
ENDFORM.                    " prepare_layout

*----------------------------------------------------------------------*
*  MODULE STATUS_0100 OUTPUT
*----------------------------------------------------------------------*
*
*----------------------------------------------------------------------*
MODULE STATUS_0100 OUTPUT.
* >>> NEW CODE: Sesuaikan PF-STATUS agar Upload pakai STATUS MAIN101 (Bisa edit/save)
  IF R_CRT = 'X' OR R_UPL = 'X'.
    SET TITLEBAR 'MAIN101'.
    SET PF-STATUS 'MAIN101'.
* <<< END OF NEW CODE
  ELSEIF R_EDT = 'X'.
    SET TITLEBAR 'MAIN102'.
    SET PF-STATUS 'MAIN102'.
  ELSEIF R_DSP = 'X'.
    SET TITLEBAR 'MAIN103'.
    SET PF-STATUS 'MAIN103'.
  ENDIF.
ENDMODULE.                 " STATUS_0100  OUTPUT

*&---------------------------------------------------------------------*
*&      Form  PREPARE_FIELD_CATALOG
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      -->P_FCAT     text
*----------------------------------------------------------------------*
FORM PREPARE_FIELD_CATALOG  CHANGING P_FCAT TYPE LVC_T_FCAT .
  DATA: V_POS LIKE SY-TABIX.
  DATA M_FIELDCAT TYPE LVC_S_FCAT .
  DATA: V_EDIT TYPE C VALUE 'X'.

  IF R_DSP = 'X'.
    V_EDIT = ''.
  ENDIF.

  CLEAR M_FIELDCAT.
  M_FIELDCAT-COL_POS    = V_POS + 1.
  M_FIELDCAT-TABNAME    = 'ITAB'.
  M_FIELDCAT-FIELDNAME  = 'MATNR'.
  M_FIELDCAT-OUTPUTLEN  = 18.
  M_FIELDCAT-REPTEXT    = 'Material Number'.
  M_FIELDCAT-COL_OPT    = 'X'.
  M_FIELDCAT-FIX_COLUMN = 'X'.
  M_FIELDCAT-F4AVAILABL = 'X'.
* >>> NEW CODE: Buka akses Edit di ALV untuk R_UPL
  IF R_CRT = 'X' OR R_UPL = 'X'. M_FIELDCAT-EDIT = 'X'. ENDIF.
  APPEND M_FIELDCAT TO P_FCAT.

  CLEAR M_FIELDCAT.
  M_FIELDCAT-COL_POS    = V_POS + 1.
  M_FIELDCAT-TABNAME    = 'ITAB'.
  M_FIELDCAT-FIELDNAME  = 'MIC'.
  M_FIELDCAT-OUTPUTLEN  = 8.
  M_FIELDCAT-REPTEXT    = 'Master Insp. Char'.
  M_FIELDCAT-COL_OPT    = 'X'.
  M_FIELDCAT-FIX_COLUMN = 'X'.
  M_FIELDCAT-F4AVAILABL = 'X'.
  IF R_CRT = 'X' OR R_UPL = 'X'. M_FIELDCAT-EDIT = 'X'. ENDIF.
  APPEND M_FIELDCAT TO P_FCAT.

  CLEAR M_FIELDCAT.
  M_FIELDCAT-COL_POS    = V_POS + 1.
  M_FIELDCAT-TABNAME    = 'ITAB'.
  M_FIELDCAT-FIELDNAME  = 'NAME1'.
  M_FIELDCAT-OUTPUTLEN  = 35.
  M_FIELDCAT-REPTEXT    = 'Customer Name'.
  M_FIELDCAT-COL_OPT    = 'X'.
  M_FIELDCAT-FIX_COLUMN = 'X'.
  M_FIELDCAT-F4AVAILABL = 'X'.
  IF R_CRT = 'X' OR R_UPL = 'X'. M_FIELDCAT-EDIT = 'X'. ENDIF.
  APPEND M_FIELDCAT TO P_FCAT.

  CLEAR M_FIELDCAT.
  M_FIELDCAT-COL_POS    = V_POS + 1.
  M_FIELDCAT-TABNAME    = 'ITAB'.
  M_FIELDCAT-FIELDNAME  = 'METHOD'.
  M_FIELDCAT-OUTPUTLEN  = 43.
  M_FIELDCAT-REPTEXT    = 'Method Testing'.
  M_FIELDCAT-COL_OPT    = 'X'.
  M_FIELDCAT-FIX_COLUMN = 'X'.
  M_FIELDCAT-F4AVAILABL = 'X'.
  IF R_CRT = 'X' OR R_EDT = 'X' OR R_UPL = 'X'.
    M_FIELDCAT-EDIT = 'X'.
  ENDIF.
  APPEND M_FIELDCAT TO P_FCAT.

  CLEAR M_FIELDCAT.
  M_FIELDCAT-COL_POS    = V_POS + 1.
  M_FIELDCAT-TABNAME    = 'ITAB'.
  M_FIELDCAT-FIELDNAME  = 'MAPPING'.
  M_FIELDCAT-OUTPUTLEN  = 43.
  M_FIELDCAT-REPTEXT    = 'Mapping for Get Insp.'.
  M_FIELDCAT-COL_OPT    = 'X'.
  M_FIELDCAT-FIX_COLUMN = 'X'.
  M_FIELDCAT-F4AVAILABL = 'X'.
  M_FIELDCAT-LOWERCASE  = 'X'.
  IF R_CRT = 'X' OR R_EDT = 'X' OR R_UPL = 'X'.
    M_FIELDCAT-EDIT = 'X'.
  ENDIF.
  APPEND M_FIELDCAT TO P_FCAT.
* <<< END OF NEW CODE

  IF R_DSP = 'X'.
    CLEAR M_FIELDCAT.
    M_FIELDCAT-COL_POS    = V_POS + 1.
    M_FIELDCAT-TABNAME    = 'ITAB'.
    M_FIELDCAT-FIELDNAME  = 'DELETION'.
    M_FIELDCAT-OUTPUTLEN  = 6.
    M_FIELDCAT-REPTEXT    = 'Del-Flag'.
    M_FIELDCAT-EDIT       = V_EDIT.
    M_FIELDCAT-JUST       = 'C'.
    APPEND M_FIELDCAT TO P_FCAT.

    CLEAR M_FIELDCAT.
    M_FIELDCAT-COL_POS    = V_POS + 1.
    M_FIELDCAT-TABNAME    = 'ITAB'.
    M_FIELDCAT-FIELDNAME  = 'CPUDT'.
    M_FIELDCAT-OUTPUTLEN  = 8.
    M_FIELDCAT-COL_OPT    = 'X'.
    M_FIELDCAT-REPTEXT    = 'Created On'.
    M_FIELDCAT-EDIT       = V_EDIT.
    APPEND M_FIELDCAT TO P_FCAT.

    CLEAR M_FIELDCAT.
    M_FIELDCAT-COL_POS    = V_POS + 1.
    M_FIELDCAT-TABNAME    = 'ITAB'.
    M_FIELDCAT-FIELDNAME  = 'CPUTM'.
    M_FIELDCAT-OUTPUTLEN  = 6.
    M_FIELDCAT-COL_OPT    = 'X'.
    M_FIELDCAT-REPTEXT    = 'Created At'.
    M_FIELDCAT-EDIT       = V_EDIT.
    APPEND M_FIELDCAT TO P_FCAT.

    CLEAR M_FIELDCAT.
    M_FIELDCAT-COL_POS    = V_POS + 1.
    M_FIELDCAT-TABNAME    = 'ITAB'.
    M_FIELDCAT-FIELDNAME  = 'CREATED1'.
    M_FIELDCAT-OUTPUTLEN  = 50.
    M_FIELDCAT-COL_OPT    = 'X'.
    M_FIELDCAT-REPTEXT    = 'Created By'.
    M_FIELDCAT-EDIT       = V_EDIT.
    APPEND M_FIELDCAT TO P_FCAT.

    CLEAR M_FIELDCAT.
    M_FIELDCAT-COL_POS    = V_POS + 1.
    M_FIELDCAT-TABNAME    = 'ITAB'.
    M_FIELDCAT-FIELDNAME  = 'AEDAT'.
    M_FIELDCAT-OUTPUTLEN  = 8.
    M_FIELDCAT-COL_OPT    = 'X'.
    M_FIELDCAT-REPTEXT    = 'Changed On'.
    M_FIELDCAT-EDIT       = V_EDIT.
    APPEND M_FIELDCAT TO P_FCAT.

    CLEAR M_FIELDCAT.
    M_FIELDCAT-COL_POS    = V_POS + 1.
    M_FIELDCAT-TABNAME    = 'ITAB'.
    M_FIELDCAT-FIELDNAME  = 'PSOTM'.
    M_FIELDCAT-OUTPUTLEN  = 6.
    M_FIELDCAT-COL_OPT    = 'X'.
    M_FIELDCAT-REPTEXT    = 'Changed At'.
    M_FIELDCAT-EDIT       = V_EDIT.
    APPEND M_FIELDCAT TO P_FCAT.

    CLEAR M_FIELDCAT.
    M_FIELDCAT-COL_POS    = V_POS + 1.
    M_FIELDCAT-TABNAME    = 'ITAB'.
    M_FIELDCAT-FIELDNAME  = 'CREATED2'.
    M_FIELDCAT-OUTPUTLEN  = 50.
    M_FIELDCAT-COL_OPT    = 'X'.
    M_FIELDCAT-REPTEXT    = 'Changed By'.
    M_FIELDCAT-EDIT       = V_EDIT.
    APPEND M_FIELDCAT TO P_FCAT.

    EXIT.
  ENDIF.

  CLEAR M_FIELDCAT.
  M_FIELDCAT-COL_POS    = V_POS + 1.
  M_FIELDCAT-FIELDNAME  = 'REMARK'.
  M_FIELDCAT-OUTPUTLEN  = 60.
  M_FIELDCAT-REPTEXT    = 'Remarks'.
  APPEND M_FIELDCAT TO P_FCAT.
ENDFORM.                    "PREPARE_FIELD_CATALOG

*&---------------------------------------------------------------------*
*&      Form  EXCLUDE_TB_FUNCTIONS
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      -->PT_EXCLUDE text
*----------------------------------------------------------------------*
FORM EXCLUDE_TB_FUNCTIONS CHANGING PT_EXCLUDE TYPE UI_FUNCTIONS.
  DATA LS_EXCLUDE TYPE UI_FUNC.
  LS_EXCLUDE = CL_GUI_ALV_GRID=>MC_FC_LOC_COPY_ROW.
  APPEND LS_EXCLUDE TO PT_EXCLUDE.
  LS_EXCLUDE = CL_GUI_ALV_GRID=>MC_FC_LOC_DELETE_ROW.
  APPEND LS_EXCLUDE TO PT_EXCLUDE.
  LS_EXCLUDE = CL_GUI_ALV_GRID=>MC_FC_LOC_APPEND_ROW.
  APPEND LS_EXCLUDE TO PT_EXCLUDE.
  LS_EXCLUDE = CL_GUI_ALV_GRID=>MC_FC_LOC_INSERT_ROW.
  APPEND LS_EXCLUDE TO PT_EXCLUDE.
  LS_EXCLUDE = CL_GUI_ALV_GRID=>MC_FC_LOC_MOVE_ROW.
  APPEND LS_EXCLUDE TO PT_EXCLUDE.
  LS_EXCLUDE = CL_GUI_ALV_GRID=>MC_FC_LOC_COPY.
  APPEND LS_EXCLUDE TO PT_EXCLUDE.
  LS_EXCLUDE = CL_GUI_ALV_GRID=>MC_FC_LOC_CUT.
  APPEND LS_EXCLUDE TO PT_EXCLUDE.
  LS_EXCLUDE = CL_GUI_ALV_GRID=>MC_FC_LOC_PASTE.
  APPEND LS_EXCLUDE TO PT_EXCLUDE.
  LS_EXCLUDE = CL_GUI_ALV_GRID=>MC_FC_LOC_PASTE_NEW_ROW.
  APPEND LS_EXCLUDE TO PT_EXCLUDE.
  LS_EXCLUDE = CL_GUI_ALV_GRID=>MC_FC_LOC_UNDO.
  APPEND LS_EXCLUDE TO PT_EXCLUDE.
ENDFORM.                                       " EXCLUDE_TB_FUNCTIONS

*&---------------------------------------------------------------------*
*&      Form  GET_F4
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
FORM GET_F4.
  IT_S_F4-FIELDNAME  = 'MATNR'.
  IT_S_F4-REGISTER   = 'X'.
  APPEND IT_S_F4 TO WA_S_F4.

  IT_S_F4-FIELDNAME  = 'MIC'.
  IT_S_F4-REGISTER   = 'X'.
  APPEND IT_S_F4 TO WA_S_F4.

  IT_S_F4-FIELDNAME  = 'KUNNR'.
  IT_S_F4-REGISTER   = 'X'.
  APPEND IT_S_F4 TO WA_S_F4.

  IT_S_F4-FIELDNAME  = 'METHOD'.
  IT_S_F4-REGISTER   = 'X'.
  APPEND IT_S_F4 TO WA_S_F4.

  IT_S_F4-FIELDNAME  = 'MAPPING'.
  IT_S_F4-REGISTER   = 'X'.
  APPEND IT_S_F4 TO WA_S_F4.

  IT_T_F4[] = WA_S_F4[].
ENDFORM.                    "GET_F4

*&---------------------------------------------------------------------*
*&      Form  F_HELP
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      -->TITLE      text
*      -->DYNPRO     text
*      -->RETFIELD   text
*----------------------------------------------------------------------*
FORM F_HELP USING TITLE DYNPRO RETFIELD.
  DATA: IT_MAPPING LIKE ZMAP_COA OCCURS 0.

  SELECT * INTO CORRESPONDING FIELDS OF TABLE IT_MAPPING FROM ZMAP_COA.

  SORT IT_MAPPING BY (RETFIELD).
  DELETE ADJACENT DUPLICATES FROM IT_MAPPING COMPARING (RETFIELD).

  IF IT_MAPPING[] IS NOT INITIAL.
    CALL FUNCTION 'F4IF_INT_TABLE_VALUE_REQUEST'
      EXPORTING
        RETFIELD     = RETFIELD
        WINDOW_TITLE = TITLE
        VALUE_ORG    = 'S'
        DYNPPROG     = SY-REPID
        DYNPNR       = SY-DYNNR
        DYNPROFIELD  = DYNPRO
      TABLES
        VALUE_TAB    = IT_MAPPING.
  ELSE.
    MESSAGE 'No values found!' TYPE 'S' DISPLAY LIKE 'E'.
  ENDIF.
ENDFORM.                    "F_HELP

*&---------------------------------------------------------------------*
*&      Form  F_HELP_MATNR
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      -->ROW        text
*      -->VALUE      text
*----------------------------------------------------------------------*
FORM F_HELP_MATNR USING ROW VALUE.
  DATA: IT_RETURN TYPE STANDARD TABLE OF DDSHRETVAL WITH HEADER LINE.

  CALL FUNCTION 'F4IF_FIELD_VALUE_REQUEST'
    EXPORTING
      TABNAME    = 'MARA'
      FIELDNAME  = 'MATNR'
    TABLES
      RETURN_TAB = IT_RETURN[].

  IF SY-SUBRC = 0.
    READ TABLE IT_RETURN INDEX 1.
    IF SY-SUBRC EQ 0.
      READ TABLE ITAB INDEX ROW.
      IF SY-SUBRC EQ 0.
        ITAB-MATNR = IT_RETURN-FIELDVAL.
        MODIFY ITAB INDEX ROW.
      ENDIF.
    ENDIF.
  ENDIF.
ENDFORM.                    "F_HELP_MATNR

*&---------------------------------------------------------------------*
*&      Form  F_HELP_MIC
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      -->ROW        text
*      -->VALUE      text
*----------------------------------------------------------------------*
FORM F_HELP_MIC USING ROW VALUE.
  DATA: IT_RETURN TYPE STANDARD TABLE OF DDSHRETVAL WITH HEADER LINE.

  CALL FUNCTION 'F4IF_FIELD_VALUE_REQUEST'
    EXPORTING
      TABNAME    = 'QPMK'
      FIELDNAME  = 'MKMNR'
    TABLES
      RETURN_TAB = IT_RETURN[].

  IF SY-SUBRC = 0.
    READ TABLE IT_RETURN INDEX 1.
    IF SY-SUBRC EQ 0.
      READ TABLE ITAB INDEX ROW.
      IF SY-SUBRC EQ 0.
        ITAB-MIC = IT_RETURN-FIELDVAL.
        MODIFY ITAB INDEX ROW.
      ENDIF.
    ENDIF.
  ENDIF.
ENDFORM.                    "F_HELP_MIC

*&---------------------------------------------------------------------*
*&      Form  F_HELP_KUNNR
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      -->ROW        text
*      -->VALUE      text
*----------------------------------------------------------------------*
FORM F_HELP_KUNNR USING ROW VALUE.
  DATA: IT_RETURN TYPE STANDARD TABLE OF DDSHRETVAL WITH HEADER LINE.

  CALL FUNCTION 'F4IF_FIELD_VALUE_REQUEST'
    EXPORTING
      TABNAME    = 'KNA1'
      FIELDNAME  = 'KUNNR'
    TABLES
      RETURN_TAB = IT_RETURN[].

  IF SY-SUBRC = 0.
    READ TABLE IT_RETURN INDEX 1.
    IF SY-SUBRC EQ 0.
      READ TABLE ITAB INDEX ROW.
      IF SY-SUBRC EQ 0.
        ITAB-KUNNR = IT_RETURN-FIELDVAL.
        MODIFY ITAB INDEX ROW.
      ENDIF.
    ENDIF.
  ENDIF.
ENDFORM.                    "F_HELP_KUNNR

*&---------------------------------------------------------------------*
*&      Form  F_HELP_METHOD
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      -->ROW        text
*      -->VALUE      text
*----------------------------------------------------------------------*
FORM F_HELP_METHOD USING ROW VALUE.
  PERFORM F_HELP USING 'Method Help List' '' 'METHOD'.
ENDFORM.                    "F_HELP_METHOD

*&---------------------------------------------------------------------*
*&      Form  F_HELP_MAPPING
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      -->ROW        text
*      -->VALUE      text
*----------------------------------------------------------------------*
FORM F_HELP_MAPPING USING ROW VALUE.
  PERFORM F_HELP USING 'Mapping Help List' '' 'MAPPING'.
ENDFORM.                    "F_HELP_MAPPING