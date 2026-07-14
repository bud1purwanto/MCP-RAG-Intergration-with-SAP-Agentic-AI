*&---------------------------------------------------------------------*
*&  Report     :  ZMAP_TYPE                                            *
*&  Appl. Area :  MM                                                   *
*&  Created by :  J. Budi                                              *
*&  Created on :  23 Mei 2022                                          *
*&---------------------------------------------------------------------*

REPORT  ZMAP_TYPE.

TABLES: ZMAP_TYPE.

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
        INCLUDE STRUCTURE ZMAP_TYPE.
DATA: ATWTB LIKE CAWNT-ATWTB.
DATA: CREATED1 TYPE C LENGTH 50.
DATA: CREATED2 TYPE C LENGTH 50.
DATA: BOX(1).
DATA: REMARK(100).
DATA: LINE_COLOR TYPE C LENGTH 4.
DATA: END OF ITAB.

DATA: IT_CHAR     TYPE STANDARD TABLE OF ZMAP_TYPE.
DATA: ITAB_TEMP   LIKE ITAB OCCURS 0 WITH HEADER LINE.

DATA: V_MSG       TYPE STRING,
      V_ANS(5)    TYPE C,
      V_ERR       TYPE C LENGTH 4 VALUE 'C600',
      V_OK        TYPE C LENGTH 4.

SELECTION-SCREEN BEGIN OF BLOCK BLK0 WITH FRAME TITLE TEXT-001.
PARAMETERS : R_CRT RADIOBUTTON GROUP R_UP USER-COMMAND AC DEFAULT 'X',
             R_EDT RADIOBUTTON GROUP R_UP,
             R_DSP RADIOBUTTON GROUP R_UP.
SELECTION-SCREEN END OF BLOCK BLK0.

SELECTION-SCREEN BEGIN OF BLOCK BLK1 WITH FRAME TITLE TEXT-002.
SELECT-OPTIONS: P_TCODE FOR ZMAP_TYPE-TCODE MODIF ID PRM.
SELECT-OPTIONS: P_PROG  FOR ZMAP_TYPE-PROG  MODIF ID PRM.
SELECT-OPTIONS: P_TYPE  FOR ZMAP_TYPE-TYPE  MODIF ID PRM.
SELECT-OPTIONS: P_OPT   FOR ZMAP_TYPE-OPT   MODIF ID PRM.
SELECT-OPTIONS: P_VALUE FOR ZMAP_TYPE-VALUE MODIF ID PRM.
SELECTION-SCREEN END OF BLOCK BLK1.

SELECTION-SCREEN BEGIN OF BLOCK BLK2 WITH FRAME TITLE TEXT-003.
PARAMETER: R_TCODE RADIOBUTTON GROUP RB DEFAULT 'X' MODIF ID PRM.
PARAMETER: R_TYPE RADIOBUTTON GROUP RB MODIF ID PRM.
PARAMETER: R_VALUE RADIOBUTTON GROUP RB MODIF ID PRM.
SELECTION-SCREEN END OF BLOCK BLK2.

SELECTION-SCREEN BEGIN OF BLOCK BLK3 WITH FRAME TITLE TEXT-004.
PARAMETER: R_DEL AS CHECKBOX DEFAULT 'X' MODIF ID DEL.
SELECTION-SCREEN END OF BLOCK BLK3.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR P_TCODE-LOW.
  PERFORM F_HELP USING 'T-Code Help List' 'P_TCODE' 'TCODE'.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR P_PROG-LOW.
  PERFORM F_HELP USING 'Program Help List' 'P_PROG' 'PROG'.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR P_TYPE-LOW.
  PERFORM F_HELP USING 'Type Help List' 'P_TYPE' 'TYPE'.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR P_OPT-LOW.
  PERFORM F_HELP USING 'Option Help List' 'P_OPT' 'OPT'.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR P_VALUE-LOW.
  PERFORM F_HELP USING 'Value Help List' 'P_VALUE' 'VALUE'.

*----------------------------------------------------------------------*
*       CLASS LCL_EVENT_RECEIVER DEFINITION
*----------------------------------------------------------------------*
*
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
*       CLASS LCL_EVENT_RECEIVER IMPLEMENTATION
*----------------------------------------------------------------------*
*
*----------------------------------------------------------------------*
CLASS LCL_EVENT_RECEIVER IMPLEMENTATION.
  METHOD CATCH_F4.

*    CALL METHOD GRID1->CHECK_CHANGED_DATA.

    IF E_FIELDNAME EQ 'TCODE'.
      PERFORM F_HELP_TCODE USING ES_ROW_NO-ROW_ID E_FIELDVALUE.
    ELSEIF E_FIELDNAME EQ 'PROG'.
      PERFORM F_HELP_PROG USING ES_ROW_NO-ROW_ID E_FIELDVALUE.
    ELSEIF E_FIELDNAME EQ 'TYPE'.
      PERFORM F_HELP_TYPE USING ES_ROW_NO-ROW_ID E_FIELDVALUE.
    ELSEIF E_FIELDNAME EQ 'OPT'.
      PERFORM F_HELP_OPT USING ES_ROW_NO-ROW_ID E_FIELDVALUE.
    ELSEIF E_FIELDNAME EQ 'VALUE'.
      PERFORM F_HELP_VALUE USING ES_ROW_NO-ROW_ID E_FIELDVALUE.
    ENDIF.

    CALL METHOD GRID1->REFRESH_TABLE_DISPLAY.
  ENDMETHOD.                    "CATCH_F4
ENDCLASS.                    "LCL_EVENT_RECEIVER IMPLEMENTATION

AT SELECTION-SCREEN OUTPUT.
  IF R_CRT <> 'X'.
    LOOP AT SCREEN.
      IF SCREEN-GROUP1 = 'PRM'.
        SCREEN-INPUT = 1.
        SCREEN-ACTIVE = 1.
        MODIFY SCREEN.
      ENDIF..
    ENDLOOP.
  ELSE.
    LOOP AT SCREEN.
      IF SCREEN-GROUP1 = 'PRM'.
        SCREEN-INPUT = 0.
        SCREEN-ACTIVE = 0.
        MODIFY SCREEN.
      ENDIF.
    ENDLOOP.
  ENDIF.

  IF R_DSP EQ 'X'.
    LOOP AT SCREEN.
      IF SCREEN-GROUP1 = 'DEL'.
        SCREEN-INPUT = 1.
        SCREEN-ACTIVE = 1.
        MODIFY SCREEN.
      ENDIF..
    ENDLOOP.
  ELSE.
    LOOP AT SCREEN.
      IF SCREEN-GROUP1 = 'DEL'.
        SCREEN-INPUT = 0.
        SCREEN-ACTIVE = 0.
        MODIFY SCREEN.
      ENDIF.
    ENDLOOP.
  ENDIF.

START-OF-SELECTION.
  IF R_CRT = 'X'.
    DO 100 TIMES.
      APPEND ITAB.
    ENDDO.
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
*  MODULE awal OUTPUT
*----------------------------------------------------------------------*
*
*----------------------------------------------------------------------*
MODULE AWAL OUTPUT.
  IF SY-UCOMM = ''.
    PERFORM DISPLAY_ALV.
  ENDIF.
ENDMODULE.                    "awal OUTPUT

*&---------------------------------------------------------------------*
*&      Form  GET_DATA
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
FORM GET_DATA.
  CLEAR ITAB. REFRESH: ITAB.

  SELECT *
  INTO CORRESPONDING FIELDS OF TABLE ITAB
  FROM ZMAP_TYPE
 WHERE TCODE IN P_TCODE
   AND PROG  IN P_PROG
   AND TYPE  IN P_TYPE
   AND OPT   IN P_OPT
   AND VALUE IN P_VALUE.

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

  IF R_TCODE EQ 'X'.
    SORT ITAB BY TCODE PROG TYPE OPT VALUE TEXT1 TEXT2 TEXT3 TEXT4 TEXT5 ASCENDING.
  ELSEIF R_TYPE EQ 'X'.
    SORT ITAB BY TYPE TCODE PROG OPT VALUE TEXT1 TEXT2 TEXT3 TEXT4 TEXT5 ASCENDING.
  ELSEIF R_VALUE EQ 'X'.
    SORT ITAB BY VALUE TEXT1 TEXT2 TEXT3 TEXT4 TEXT5 TYPE TCODE PROG OPT ASCENDING.
  ENDIF.

  ITAB_TEMP[] = ITAB[].

ENDFORM.                    "GET_DATA

*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_0100  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
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
*       text
*----------------------------------------------------------------------*
FORM F_CREATE_DATA.
  CALL METHOD GRID1->CHECK_CHANGED_DATA.

  LOOP AT ITAB.
    CLEAR: V_MSG, ITAB-REMARK, ITAB-DELETION.
    ITAB-LINE_COLOR = V_OK.

    "Check empty fill
    IF ITAB-TCODE IS INITIAL AND ITAB-PROG IS INITIAL AND ITAB-TYPE IS INITIAL AND ITAB-OPT IS INITIAL AND ITAB-VALUE IS INITIAL.
      CONTINUE.
    ENDIF.

    "Check empty fill
    IF ITAB-TCODE IS INITIAL AND ITAB-PROG IS INITIAL.
      ITAB-REMARK = 'Please fill t-code or program...!'.
      ITAB-LINE_COLOR = V_ERR.
      MODIFY ITAB.
      CONTINUE.
    ENDIF.

*    "Check empty fill
*    IF ITAB-PROG IS INITIAL.
*      ITAB-REMARK = 'Please fill program...!'.
*      ITAB-LINE_COLOR = V_ERR.
*      MODIFY ITAB.
*      CONTINUE.
*    ENDIF.

    IF ITAB-TCODE IS NOT INITIAL.
      SELECT SINGLE TCODE INTO ITAB-TCODE FROM TSTC WHERE TCODE EQ ITAB-TCODE.
      IF SY-SUBRC NE 0.
        CONCATENATE 'T-Code: ' ITAB-TCODE 'is not available...!' INTO V_MSG SEPARATED BY SPACE.
        ITAB-REMARK     = V_MSG.
        ITAB-LINE_COLOR = V_ERR.
        MODIFY ITAB.
        CONTINUE.
      ENDIF.
    ENDIF.

    IF ITAB-PROG IS NOT INITIAL.
      SELECT SINGLE OBJ_NAME INTO ITAB-PROG FROM TADIR WHERE OBJ_NAME EQ ITAB-PROG.
      IF SY-SUBRC NE 0.
        CONCATENATE 'Program: ' ITAB-PROG 'is not available...!' INTO V_MSG SEPARATED BY SPACE.
        ITAB-REMARK     = V_MSG.
        ITAB-LINE_COLOR = V_ERR.
        MODIFY ITAB.
        CONTINUE.
      ENDIF.
    ENDIF.

    "Check empty fill type
    IF ITAB-TYPE IS INITIAL.
      ITAB-REMARK = 'Please fill the type...!'.
      ITAB-LINE_COLOR = V_ERR.
      MODIFY ITAB.
      CONTINUE.
    ENDIF.

    "Check empty fill value
    IF ITAB-VALUE IS INITIAL.
      ITAB-REMARK = 'Please fill the value...!'.
      ITAB-LINE_COLOR = V_ERR.
      MODIFY ITAB.
      CONTINUE.
    ENDIF.

    "Check type is exist
    SELECT SINGLE TCODE DELETION INTO (ITAB-TCODE, ITAB-DELETION)
      FROM ZMAP_TYPE
     WHERE TCODE = ITAB-TCODE
       AND PROG  = ITAB-PROG
       AND TYPE  = ITAB-TYPE
       AND OPT   = ITAB-OPT
       AND VALUE = ITAB-VALUE.
    IF SY-SUBRC EQ 0.
      IF ITAB-DELETION EQ 'X'.
        CONCATENATE ITAB-TCODE ': Value' ITAB-VALUE 'is mark for deletion...!' INTO V_MSG SEPARATED BY SPACE.
        ITAB-REMARK     = V_MSG.
        ITAB-LINE_COLOR = V_ERR.
        MODIFY ITAB.
        CONTINUE.
      ELSE.
        CONCATENATE ITAB-TCODE ': Value' ITAB-VALUE 'is exist...!' INTO V_MSG SEPARATED BY SPACE.
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
        TERMINAL = ITAB-TERM1
      EXCEPTIONS
        OTHERS   = 1.

    INSERT ZMAP_TYPE FROM ITAB.

    CONCATENATE ITAB-TCODE ': Value' ITAB-VALUE 'Successfully added...!' INTO V_MSG SEPARATED BY SPACE.

    ITAB-REMARK = V_MSG.
    MODIFY ITAB.

  ENDLOOP.

ENDFORM.                    "F_CREATE_DATA

*&---------------------------------------------------------------------*
*&      Form  F_CHANGE_DATA
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
FORM F_CHANGE_DATA.
  CALL METHOD GRID1->CHECK_CHANGED_DATA.

  LOOP AT ITAB.
    CLEAR: V_MSG, ITAB-REMARK.
    ITAB-LINE_COLOR = V_OK.

    "Check empty fill value
    IF ITAB-VALUE IS INITIAL.
      ITAB-REMARK = 'Please fill the value...!'.
      ITAB-LINE_COLOR = V_ERR.
      MODIFY ITAB.
      CONTINUE.
    ENDIF.

    READ TABLE ITAB_TEMP WITH KEY TCODE = ITAB-TCODE PROG = ITAB-PROG TYPE = ITAB-TYPE OPT = ITAB-OPT VALUE = ITAB-VALUE.

    IF ITAB_TEMP-VALUE <> ITAB-VALUE
    OR ITAB_TEMP-TEXT1 <> ITAB-TEXT1
    OR ITAB_TEMP-TEXT2 <> ITAB-TEXT2
    OR ITAB_TEMP-TEXT3 <> ITAB-TEXT3
    OR ITAB_TEMP-TEXT4 <> ITAB-TEXT4
    OR ITAB_TEMP-TEXT5 <> ITAB-TEXT5.
    ELSE.
      CONCATENATE 'No update on t-code' ITAB-TCODE 'and type' ITAB-TYPE
      INTO V_MSG SEPARATED BY SPACE.
      ITAB-REMARK = V_MSG.
      MODIFY ITAB.
      CONTINUE.
    ENDIF.

    ITAB-AEDAT = SY-DATUM.
    ITAB-PSOTM = SY-UZEIT.
    ITAB-AENAM = SY-UNAME.

    CALL FUNCTION 'TERMINAL_ID_GET'
      EXPORTING
        USERNAME = SY-UNAME
      IMPORTING
        TERMINAL = ITAB-TERM2
      EXCEPTIONS
        OTHERS   = 1.

    UPDATE ZMAP_TYPE
    SET
    TEXT1 = ITAB-TEXT1
    TEXT2 = ITAB-TEXT2
    TEXT3 = ITAB-TEXT3
    TEXT4 = ITAB-TEXT4
    TEXT5 = ITAB-TEXT5
    AEDAT = ITAB-AEDAT
    PSOTM = ITAB-PSOTM
    AENAM = ITAB-AENAM
    TERM2 = ITAB-TERM2
    WHERE TCODE = ITAB-TCODE AND PROG = ITAB-PROG AND TYPE = ITAB-TYPE AND OPT = ITAB-OPT AND VALUE = ITAB-VALUE.

    IF ITAB_TEMP-VALUE <> ITAB-VALUE.
      CONCATENATE V_MSG 'Value' ITAB-VALUE INTO V_MSG SEPARATED BY SPACE.
    ENDIF.
    IF ITAB_TEMP-TEXT1 <> ITAB-TEXT1.
      CONCATENATE V_MSG 'TEXT1' INTO V_MSG SEPARATED BY SPACE.
    ENDIF.
    IF ITAB_TEMP-TEXT2 <> ITAB-TEXT2.
      CONCATENATE V_MSG 'TEXT2' INTO V_MSG SEPARATED BY SPACE.
    ENDIF.
    IF ITAB_TEMP-TEXT3 <> ITAB-TEXT3.
      CONCATENATE V_MSG 'TEXT3' INTO V_MSG SEPARATED BY SPACE.
    ENDIF.
    IF ITAB_TEMP-TEXT4 <> ITAB-TEXT4.
      CONCATENATE V_MSG 'TEXT4' INTO V_MSG SEPARATED BY SPACE.
    ENDIF.
    IF ITAB_TEMP-TEXT5 <> ITAB-TEXT5.
      CONCATENATE V_MSG 'TEXT5' INTO V_MSG SEPARATED BY SPACE.
    ENDIF.

    CONCATENATE V_MSG 'Successfully updated on t-code' ITAB-TCODE 'and type' ITAB-TYPE '...!' INTO V_MSG SEPARATED BY SPACE.

    ITAB-REMARK = V_MSG.
    MODIFY ITAB.

  ENDLOOP.

  SELECT *
    INTO CORRESPONDING FIELDS OF TABLE ITAB_TEMP
    FROM ZMAP_TYPE
   WHERE TCODE IN P_TCODE
     AND PROG  IN P_PROG
     AND TYPE  IN P_TYPE
     AND OPT   IN P_OPT.

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
        TERMINAL = ITAB-TERM2
      EXCEPTIONS
        OTHERS   = 1.

    UPDATE ZMAP_TYPE
    SET
    AEDAT = ITAB-AEDAT
    PSOTM = ITAB-PSOTM
    AENAM = ITAB-AENAM
    TERM2 = ITAB-TERM2
    DELETION = ITAB-DELETION
    WHERE TCODE = ITAB-TCODE AND PROG = ITAB-PROG AND TYPE = ITAB-TYPE AND OPT = ITAB-OPT AND VALUE = ITAB-VALUE.

    CONCATENATE 'T-code' ITAB-TCODE 'and type' ITAB-TYPE ':' ITAB-VALUE 'successfully deleted...!' INTO V_MSG SEPARATED BY SPACE.

    ITAB-REMARK = V_MSG.
    MODIFY ITAB.
  ENDLOOP.

  SELECT *
    INTO CORRESPONDING FIELDS OF TABLE ITAB_TEMP
    FROM ZMAP_TYPE
   WHERE TCODE IN P_TCODE
     AND PROG  IN P_PROG
     AND TYPE  IN P_TYPE
     AND OPT   IN P_OPT.

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
        TERMINAL = ITAB-TERM2
      EXCEPTIONS
        OTHERS   = 1.

    UPDATE ZMAP_TYPE
    SET
    AEDAT = ITAB-AEDAT
    PSOTM = ITAB-PSOTM
    AENAM = ITAB-AENAM
    TERM2 = ITAB-TERM2
    DELETION = ITAB-DELETION
    WHERE TCODE = ITAB-TCODE AND PROG = ITAB-PROG AND TYPE = ITAB-TYPE AND OPT = ITAB-OPT AND VALUE = ITAB-VALUE.

    CONCATENATE 'T-code' ITAB-TCODE 'and type' ITAB-TYPE ':' ITAB-VALUE 'successfully undeletion flag...!' INTO V_MSG SEPARATED BY SPACE.

    ITAB-REMARK = V_MSG.
    MODIFY ITAB.
  ENDLOOP.

  SELECT *
    INTO CORRESPONDING FIELDS OF TABLE ITAB_TEMP
    FROM ZMAP_TYPE
   WHERE TCODE IN P_TCODE
     AND PROG  IN P_PROG
     AND TYPE  IN P_TYPE
     AND OPT   IN P_OPT.

  PERFORM GET_DATA.
ENDFORM.                    "F_DELETE_DATA

*&---------------------------------------------------------------------*
*&      Form  F_CLEAR_DATA
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
FORM F_CLEAR_DATA.
  DELETE ITAB WHERE TCODE IS NOT INITIAL.
ENDFORM.                    "F_CLEAR_DATA

*&---------------------------------------------------------------------*
*&      Form  DISPLAY_ALV_SB
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
FORM DISPLAY_ALV.
  DATA: LT_EXCLUDE TYPE UI_FUNCTIONS.

  PERFORM PREPARE_LAYOUT CHANGING GS_LAYOUT .
  PERFORM PREPARE_FIELD_CATALOG CHANGING GT_FIELDCAT .
  IF R_CRT <> 'X'.
    PERFORM EXCLUDE_TB_FUNCTIONS CHANGING LT_EXCLUDE .
  ENDIF.

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
ENDFORM.                    "DISPLAY_ALV_SB

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
*&      Form  prepare_layout
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


*&---------------------------------------------------------------------*
*&      Module  STATUS_0100  OUTPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE STATUS_0100 OUTPUT.
  IF R_CRT = 'X'.
    SET TITLEBAR 'MAIN101'.
    SET PF-STATUS 'MAIN101'.
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
  M_FIELDCAT-FIELDNAME  = 'TCODE'.
  M_FIELDCAT-OUTPUTLEN  = 20.
  M_FIELDCAT-REPTEXT    = 'Transaction Code'.
  M_FIELDCAT-COL_OPT    = 'X'.
  M_FIELDCAT-FIX_COLUMN = 'X'.
  M_FIELDCAT-F4AVAILABL = 'X'.
  IF R_CRT = 'X'.
    M_FIELDCAT-EDIT = 'X'.
  ENDIF.
  APPEND M_FIELDCAT TO P_FCAT.

  CLEAR M_FIELDCAT.
  M_FIELDCAT-COL_POS    = V_POS + 1.
  M_FIELDCAT-TABNAME    = 'ITAB'.
  M_FIELDCAT-FIELDNAME  = 'PROG'.
  M_FIELDCAT-OUTPUTLEN  = 40.
  M_FIELDCAT-REPTEXT    = 'Program Name / Source Code'.
  M_FIELDCAT-COL_OPT    = 'X'.
  M_FIELDCAT-FIX_COLUMN = 'X'.
  M_FIELDCAT-F4AVAILABL = 'X'.
  IF R_CRT = 'X'.
    M_FIELDCAT-EDIT     = 'X'.
  ENDIF.
  APPEND M_FIELDCAT TO P_FCAT.

  CLEAR M_FIELDCAT.
  M_FIELDCAT-COL_POS    = V_POS + 1.
  M_FIELDCAT-TABNAME    = 'ITAB'.
  M_FIELDCAT-FIELDNAME  = 'TYPE'.
  M_FIELDCAT-OUTPUTLEN  = 30.
  M_FIELDCAT-REPTEXT    = 'Type of Data'.
  M_FIELDCAT-COL_OPT    = 'X'.
  M_FIELDCAT-FIX_COLUMN = 'X'.
  M_FIELDCAT-F4AVAILABL = 'X'.
  IF R_CRT = 'X'.
    M_FIELDCAT-EDIT     = 'X'.
  ENDIF.
  APPEND M_FIELDCAT TO P_FCAT.

  CLEAR M_FIELDCAT.
  M_FIELDCAT-COL_POS    = V_POS + 1.
  M_FIELDCAT-TABNAME    = 'ITAB'.
  M_FIELDCAT-FIELDNAME  = 'OPT'.
  M_FIELDCAT-OUTPUTLEN  = 30.
  M_FIELDCAT-REPTEXT    = 'Option Parameter'.
  M_FIELDCAT-COL_OPT    = 'X'.
  M_FIELDCAT-FIX_COLUMN = 'X'.
  M_FIELDCAT-F4AVAILABL = 'X'.
  IF R_CRT = 'X'.
    M_FIELDCAT-EDIT     = 'X'.
  ENDIF.
  APPEND M_FIELDCAT TO P_FCAT.

  CLEAR M_FIELDCAT.
  M_FIELDCAT-COL_POS    = V_POS + 1.
  M_FIELDCAT-TABNAME    = 'ITAB'.
  M_FIELDCAT-FIELDNAME  = 'VALUE'.
  M_FIELDCAT-OUTPUTLEN  = 30.
  M_FIELDCAT-REPTEXT    = 'Value'.
  M_FIELDCAT-COL_OPT    = 'X'.
  M_FIELDCAT-FIX_COLUMN = 'X'.
  M_FIELDCAT-F4AVAILABL = 'X'.
  M_FIELDCAT-LOWERCASE  = 'X'.
  IF R_CRT = 'X'.
    M_FIELDCAT-EDIT     = 'X'.
  ENDIF.
  APPEND M_FIELDCAT TO P_FCAT.

  CLEAR M_FIELDCAT.
  M_FIELDCAT-COL_POS    = V_POS + 1.
  M_FIELDCAT-TABNAME    = 'ITAB'.
  M_FIELDCAT-FIELDNAME  = 'TEXT1'.
  M_FIELDCAT-OUTPUTLEN  = 20.
  M_FIELDCAT-REPTEXT    = 'Text 1'.
  M_FIELDCAT-COL_OPT    = 'X'.
  M_FIELDCAT-LOWERCASE  = 'X'.
  M_FIELDCAT-EDIT       = V_EDIT.
  APPEND M_FIELDCAT TO P_FCAT.

  CLEAR M_FIELDCAT.
  M_FIELDCAT-COL_POS    = V_POS + 1.
  M_FIELDCAT-TABNAME    = 'ITAB'.
  M_FIELDCAT-FIELDNAME  = 'TEXT2'.
  M_FIELDCAT-OUTPUTLEN  = 20.
  M_FIELDCAT-REPTEXT    = 'Text 2'.
  M_FIELDCAT-COL_OPT    = 'X'.
  M_FIELDCAT-LOWERCASE  = 'X'.
  M_FIELDCAT-EDIT       = V_EDIT.
  APPEND M_FIELDCAT TO P_FCAT.

  CLEAR M_FIELDCAT.
  M_FIELDCAT-COL_POS    = V_POS + 1.
  M_FIELDCAT-TABNAME    = 'ITAB'.
  M_FIELDCAT-FIELDNAME  = 'TEXT3'.
  M_FIELDCAT-OUTPUTLEN  = 30.
  M_FIELDCAT-REPTEXT    = 'Text 3'.
  M_FIELDCAT-COL_OPT    = 'X'.
  M_FIELDCAT-LOWERCASE  = 'X'.
  M_FIELDCAT-EDIT       = V_EDIT.
  APPEND M_FIELDCAT TO P_FCAT.

  CLEAR M_FIELDCAT.
  M_FIELDCAT-COL_POS    = V_POS + 1.
  M_FIELDCAT-TABNAME    = 'ITAB'.
  M_FIELDCAT-FIELDNAME  = 'TEXT4'.
  M_FIELDCAT-OUTPUTLEN  = 30.
  M_FIELDCAT-REPTEXT    = 'Text 4'.
  M_FIELDCAT-COL_OPT    = 'X'.
  M_FIELDCAT-LOWERCASE  = 'X'.
  M_FIELDCAT-EDIT       = V_EDIT.
  APPEND M_FIELDCAT TO P_FCAT.

  CLEAR M_FIELDCAT.
  M_FIELDCAT-COL_POS    = V_POS + 1.
  M_FIELDCAT-TABNAME    = 'ITAB'.
  M_FIELDCAT-FIELDNAME  = 'TEXT5'.
  M_FIELDCAT-OUTPUTLEN  = 45.
  M_FIELDCAT-REPTEXT    = 'Text 5'.
  M_FIELDCAT-COL_OPT    = 'X'.
  M_FIELDCAT-LOWERCASE  = 'X'.
  M_FIELDCAT-EDIT       = V_EDIT.
  APPEND M_FIELDCAT TO P_FCAT.

  IF R_DSP = 'X'.
    CLEAR M_FIELDCAT.
    M_FIELDCAT-COL_POS    = V_POS + 1.
    M_FIELDCAT-TABNAME    = 'ITAB'.
    M_FIELDCAT-FIELDNAME  = 'DELETION'.
    M_FIELDCAT-OUTPUTLEN  = 6.
*    M_FIELDCAT-COL_OPT    = 'X'.
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
*&      Form  exclude_tb_functions
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
ENDFORM.                               " EXCLUDE_TB_FUNCTIONS

*&---------------------------------------------------------------------*
*&      Form  GET_F4
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
FORM GET_F4.
  IT_S_F4-FIELDNAME  = 'TCODE'.
  IT_S_F4-REGISTER   = 'X'.
  IT_S_F4-GETBEFORE  = ''.
  IT_S_F4-CHNGEAFTER = ''.
  APPEND IT_S_F4 TO WA_S_F4.

  IT_S_F4-FIELDNAME  = 'PROG'.
  IT_S_F4-REGISTER   = 'X'.
  IT_S_F4-GETBEFORE  = ''.
  IT_S_F4-CHNGEAFTER = ''.
  APPEND IT_S_F4 TO WA_S_F4.

  IT_S_F4-FIELDNAME  = 'TYPE'.
  IT_S_F4-REGISTER   = 'X'.
  IT_S_F4-GETBEFORE  = ''.
  IT_S_F4-CHNGEAFTER = ''.
  APPEND IT_S_F4 TO WA_S_F4.

  IT_S_F4-FIELDNAME  = 'OPT'.
  IT_S_F4-REGISTER   = 'X'.
  IT_S_F4-GETBEFORE  = ''.
  IT_S_F4-CHNGEAFTER = ''.
  APPEND IT_S_F4 TO WA_S_F4.

  IT_S_F4-FIELDNAME  = 'VALUE'.
  IT_S_F4-REGISTER   = 'X'.
  IT_S_F4-GETBEFORE  = ''.
  IT_S_F4-CHNGEAFTER = ''.
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
  DATA: IT_MAPPING LIKE ZMAP_TYPE OCCURS 0.

  SELECT * INTO CORRESPONDING FIELDS OF TABLE IT_MAPPING FROM ZMAP_TYPE.

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
*&      Form  F_HELP_TCODE
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
FORM F_HELP_TCODE USING ROW VALUE.
  DATA: IT_TSTCT  LIKE TSTCT OCCURS 0,
        IT_RETURN TYPE STANDARD TABLE OF DDSHRETVAL WITH HEADER LINE,
        V_PARAM   TYPE C LENGTH 50.

  IF VALUE IS NOT INITIAL.
    V_PARAM = VALUE && '%'.
  ELSE.
    V_PARAM = 'Z%%%'.
  ENDIF.

  SELECT * INTO CORRESPONDING FIELDS OF TABLE IT_TSTCT FROM TSTCT WHERE TCODE LIKE V_PARAM.

  SORT IT_TSTCT BY TCODE.
  DELETE ADJACENT DUPLICATES FROM IT_TSTCT COMPARING TCODE.

  IF IT_TSTCT[] IS NOT INITIAL.
    CALL FUNCTION 'F4IF_INT_TABLE_VALUE_REQUEST'
      EXPORTING
        RETFIELD     = 'TCODE'
        WINDOW_TITLE = 'T-Code Help List'
        VALUE_ORG    = 'S'
      TABLES
        VALUE_TAB    = IT_TSTCT
        RETURN_TAB   = IT_RETURN[].

    IF SY-SUBRC = 0.
      READ TABLE IT_RETURN INDEX 1.
      IF SY-SUBRC EQ 0.
        READ TABLE ITAB INDEX ROW.
        IF SY-SUBRC EQ 0.
          ITAB-TCODE = IT_RETURN-FIELDVAL.
          MODIFY ITAB INDEX ROW.
        ENDIF.
      ENDIF.
    ENDIF.
  ELSE.
    MESSAGE 'No values found!' TYPE 'S' DISPLAY LIKE 'E'.
  ENDIF.
ENDFORM.                    "F_HELP_TCODE

*&---------------------------------------------------------------------*
*&      Form  F_HELP_PROG
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      -->ROW        text
*      -->VALUE      text
*----------------------------------------------------------------------*
FORM F_HELP_PROG USING ROW VALUE.
  DATA: IT_TRDIRT  LIKE TRDIRT OCCURS 0,
        IT_RETURN TYPE STANDARD TABLE OF DDSHRETVAL WITH HEADER LINE,
        V_PARAM   TYPE C LENGTH 50.

  IF VALUE IS NOT INITIAL.
    V_PARAM = VALUE && '%'.
  ELSE.
    V_PARAM = 'Z%%%'.
  ENDIF.

  SELECT * INTO CORRESPONDING FIELDS OF TABLE IT_TRDIRT FROM TRDIRT WHERE NAME LIKE V_PARAM.

  SORT IT_TRDIRT BY NAME.
  DELETE ADJACENT DUPLICATES FROM IT_TRDIRT COMPARING NAME.

  IF IT_TRDIRT[] IS NOT INITIAL.
    CALL FUNCTION 'F4IF_INT_TABLE_VALUE_REQUEST'
      EXPORTING
        RETFIELD     = 'NAME'
        WINDOW_TITLE = 'Program Help List'
        VALUE_ORG    = 'S'
      TABLES
        VALUE_TAB    = IT_TRDIRT
        RETURN_TAB   = IT_RETURN[].

    IF SY-SUBRC = 0.
      READ TABLE IT_RETURN INDEX 1.
      IF SY-SUBRC EQ 0.
        READ TABLE ITAB INDEX ROW.
        IF SY-SUBRC EQ 0.
          ITAB-PROG = IT_RETURN-FIELDVAL.
          MODIFY ITAB INDEX ROW.
        ENDIF.
      ENDIF.
    ENDIF.
  ELSE.
    MESSAGE 'No values found!' TYPE 'S' DISPLAY LIKE 'E'.
  ENDIF.
ENDFORM.                    "F_HELP_PROG

*&---------------------------------------------------------------------*
*&      Form  F_HELP_TYPE
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      -->ROW        text
*      -->VALUE      text
*----------------------------------------------------------------------*
FORM F_HELP_TYPE USING ROW VALUE.
  DATA: IT_MAPPING LIKE ZMAP_TYPE OCCURS 0,
        IT_RETURN TYPE STANDARD TABLE OF DDSHRETVAL WITH HEADER LINE,
        V_PARAM   TYPE C LENGTH 50.

  IF VALUE IS NOT INITIAL.
    V_PARAM = VALUE && '%'.
  ELSE.
    V_PARAM = '%'.
  ENDIF.

  SELECT * INTO CORRESPONDING FIELDS OF TABLE IT_MAPPING FROM ZMAP_TYPE WHERE TYPE LIKE V_PARAM.

  SORT IT_MAPPING BY TYPE.
  DELETE ADJACENT DUPLICATES FROM IT_MAPPING COMPARING TYPE.

  IF IT_MAPPING[] IS NOT INITIAL.
    CALL FUNCTION 'F4IF_INT_TABLE_VALUE_REQUEST'
      EXPORTING
        RETFIELD     = 'TYPE'
        WINDOW_TITLE = 'Type Help List'
        VALUE_ORG    = 'S'
      TABLES
        VALUE_TAB    = IT_MAPPING
        RETURN_TAB   = IT_RETURN[].

    IF SY-SUBRC = 0.
      READ TABLE IT_RETURN INDEX 1.
      IF SY-SUBRC EQ 0.
        READ TABLE ITAB INDEX ROW.
        IF SY-SUBRC EQ 0.
          ITAB-TYPE = IT_RETURN-FIELDVAL.
          MODIFY ITAB INDEX ROW.
        ENDIF.
      ENDIF.
    ENDIF.
  ELSE.
    MESSAGE 'No values found!' TYPE 'S' DISPLAY LIKE 'E'.
  ENDIF.
ENDFORM.                    "F_HELP_TYPE


*&---------------------------------------------------------------------*
*&      Form  F_HELP_TYPE
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      -->ROW        text
*      -->VALUE      text
*----------------------------------------------------------------------*
FORM F_HELP_OPT USING ROW VALUE.
  DATA: IT_MAPPING LIKE ZMAP_TYPE OCCURS 0,
        IT_RETURN TYPE STANDARD TABLE OF DDSHRETVAL WITH HEADER LINE,
        V_PARAM   TYPE C LENGTH 50.

  IF VALUE IS NOT INITIAL.
    V_PARAM = VALUE && '%'.
  ELSE.
    V_PARAM = '%'.
  ENDIF.

  SELECT * INTO CORRESPONDING FIELDS OF TABLE IT_MAPPING FROM ZMAP_TYPE WHERE OPT LIKE V_PARAM.

  SORT IT_MAPPING BY OPT.
  DELETE ADJACENT DUPLICATES FROM IT_MAPPING COMPARING OPT.

  IF IT_MAPPING[] IS NOT INITIAL.
    CALL FUNCTION 'F4IF_INT_TABLE_VALUE_REQUEST'
      EXPORTING
        RETFIELD     = 'OPT'
        WINDOW_TITLE = 'Type Help List'
        VALUE_ORG    = 'S'
      TABLES
        VALUE_TAB    = IT_MAPPING
        RETURN_TAB   = IT_RETURN[].

    IF SY-SUBRC = 0.
      READ TABLE IT_RETURN INDEX 1.
      IF SY-SUBRC EQ 0.
        READ TABLE ITAB INDEX ROW.
        IF SY-SUBRC EQ 0.
          ITAB-OPT = IT_RETURN-FIELDVAL.
          MODIFY ITAB INDEX ROW.
        ENDIF.
      ENDIF.
    ENDIF.
  ELSE.
    MESSAGE 'No values found!' TYPE 'S' DISPLAY LIKE 'E'.
  ENDIF.
ENDFORM.                    "F_HELP_TYPE

*&---------------------------------------------------------------------*
*&      Form  F_HELP_VALUE
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      -->ROW        text
*      -->VALUE      text
*----------------------------------------------------------------------*
FORM F_HELP_VALUE USING ROW VALUE.
  DATA: IT_MAPPING LIKE ZMAP_TYPE OCCURS 0,
        IT_RETURN TYPE STANDARD TABLE OF DDSHRETVAL WITH HEADER LINE,
        V_PARAM   TYPE C LENGTH 50.

  IF VALUE IS NOT INITIAL.
    V_PARAM = VALUE && '%'.
  ELSE.
    V_PARAM = '%'.
  ENDIF.

  READ TABLE ITAB INDEX ROW.
  IF ITAB-TYPE IS NOT INITIAL.
    SELECT * INTO CORRESPONDING FIELDS OF TABLE IT_MAPPING FROM ZMAP_TYPE WHERE TYPE EQ ITAB-TYPE AND VALUE LIKE V_PARAM.
  ELSE.
    SELECT * INTO CORRESPONDING FIELDS OF TABLE IT_MAPPING FROM ZMAP_TYPE WHERE VALUE LIKE V_PARAM.
  ENDIF.

  SORT IT_MAPPING BY VALUE.
  DELETE ADJACENT DUPLICATES FROM IT_MAPPING COMPARING VALUE.

  IF IT_MAPPING[] IS NOT INITIAL.
    CALL FUNCTION 'F4IF_INT_TABLE_VALUE_REQUEST'
      EXPORTING
        RETFIELD     = 'VALUE'
        WINDOW_TITLE = 'Type Help List'
        VALUE_ORG    = 'S'
      TABLES
        VALUE_TAB    = IT_MAPPING
        RETURN_TAB   = IT_RETURN[].

    IF SY-SUBRC = 0.
      READ TABLE IT_RETURN INDEX 1.
      IF SY-SUBRC EQ 0.
        READ TABLE ITAB INDEX ROW.
        IF SY-SUBRC EQ 0.
          ITAB-VALUE = IT_RETURN-FIELDVAL.
          MODIFY ITAB INDEX ROW.
        ENDIF.
      ENDIF.
    ENDIF.
  ELSE.
    MESSAGE 'No values found!' TYPE 'S' DISPLAY LIKE 'E'.
  ENDIF.
ENDFORM.                    "F_HELP_VALUE