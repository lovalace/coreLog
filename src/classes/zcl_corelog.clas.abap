*&---------------------------------------------------------------------*
*& Class: ZCL_CORELOG
*& Açıklama: Basit, minimal ABAP logger
*& Versiyon: 2.0 (Basitleştirilmiş)
*&---------------------------------------------------------------------*

CLASS zcl_corelog DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    " Log seviyeleri
    CONSTANTS:
      c_level_debug   TYPE char10 VALUE 'DEBUG',
      c_level_info    TYPE char10 VALUE 'INFO',
      c_level_warning TYPE char10 VALUE 'WARNING',
      c_level_error   TYPE char10 VALUE 'ERROR',
      c_level_fatal   TYPE char10 VALUE 'FATAL'.

    " Numeric seviyeler (karşılaştırma için)
    CONSTANTS:
      c_level_num_debug   TYPE i VALUE 1,
      c_level_num_info    TYPE i VALUE 2,
      c_level_num_warning TYPE i VALUE 3,
      c_level_num_error   TYPE i VALUE 4,
      c_level_num_fatal   TYPE i VALUE 5.

    " Ana log metodları
    CLASS-METHODS debug
      IMPORTING
        iv_message TYPE string
        iv_details TYPE string OPTIONAL.

    CLASS-METHODS info
      IMPORTING
        iv_message TYPE string
        iv_details TYPE string OPTIONAL.

    CLASS-METHODS warning
      IMPORTING
        iv_message TYPE string
        iv_details TYPE string OPTIONAL.

    CLASS-METHODS error
      IMPORTING
        iv_message TYPE string
        iv_details TYPE string OPTIONAL.

    CLASS-METHODS fatal
      IMPORTING
        iv_message TYPE string
        iv_details TYPE string OPTIONAL.

    " Konfigürasyon
    CLASS-METHODS init
      IMPORTING
        iv_config_name TYPE char30 DEFAULT 'DEFAULT'.

    CLASS-METHODS set_log_level
      IMPORTING
        iv_level TYPE char10.

  PROTECTED SECTION.

  PRIVATE SECTION.

    " İç değişkenler
    CLASS-DATA:
      gv_config_name   TYPE char30,
      gv_log_level     TYPE char10,
      gv_log_level_num TYPE i,
      gv_is_active     TYPE abap_boolean,
      gv_initialized   TYPE abap_boolean.

    " İç metodlar
    CLASS-METHODS log_internal
      IMPORTING
        iv_level   TYPE char10
        iv_message TYPE string
        iv_details TYPE string OPTIONAL.

    CLASS-METHODS write_to_db
      IMPORTING
        iv_level   TYPE char10
        iv_message TYPE string
        iv_details TYPE string OPTIONAL.

    CLASS-METHODS get_level_number
      IMPORTING
        iv_level        TYPE char10
      RETURNING
        VALUE(rv_level) TYPE i.

    CLASS-METHODS load_config
      IMPORTING
        iv_config_name TYPE char30.

    CLASS-METHODS generate_log_id
      RETURNING
        VALUE(rv_log_id) TYPE numc16.

ENDCLASS.



CLASS zcl_corelog IMPLEMENTATION.

  METHOD debug.
    log_internal(
      iv_level   = c_level_debug
      iv_message = iv_message
      iv_details = iv_details
    ).
  ENDMETHOD.

  METHOD info.
    log_internal(
      iv_level   = c_level_info
      iv_message = iv_message
      iv_details = iv_details
    ).
  ENDMETHOD.

  METHOD warning.
    log_internal(
      iv_level   = c_level_warning
      iv_message = iv_message
      iv_details = iv_details
    ).
  ENDMETHOD.

  METHOD error.
    log_internal(
      iv_level   = c_level_error
      iv_message = iv_message
      iv_details = iv_details
    ).
  ENDMETHOD.

  METHOD fatal.
    log_internal(
      iv_level   = c_level_fatal
      iv_message = iv_message
      iv_details = iv_details
    ).
  ENDMETHOD.

  METHOD init.
    " Konfigürasyonu yükle
    load_config( iv_config_name ).
    gv_initialized = abap_true.
  ENDMETHOD.

  METHOD set_log_level.
    " Manuel log seviyesi ayarı
    gv_log_level = iv_level.
    gv_log_level_num = get_level_number( iv_level ).
  ENDMETHOD.

  METHOD log_internal.
    " Eğer initialize edilmemişse, default config ile başlat
    IF gv_initialized = abap_false.
      init( ).
    ENDIF.

    " Logger deaktifse çık
    IF gv_is_active = abap_false.
      RETURN.
    ENDIF.

    " Seviye kontrolü - sadece eşit veya üst seviye logla
    DATA(lv_current_level_num) = get_level_number( iv_level ).

    IF lv_current_level_num < gv_log_level_num.
      " Bu log seviyesi yeterince önemli değil, yazma
      RETURN.
    ENDIF.

    " DB'ye yaz
    write_to_db(
      iv_level   = iv_level
      iv_message = iv_message
      iv_details = iv_details
    ).
  ENDMETHOD.

  METHOD write_to_db.
    " Güvenli DB yazma (hata olsa bile program durmaz)
    TRY.
        DATA(lv_log_id) = generate_log_id( ).

        " Timestamp oluştur: YYYYMMDDHHMMSS
        DATA(lv_timestamp) = CONV dec15( |{ sy-datum }{ sy-uzeit }| ).

        INSERT INTO zcorelog_log VALUES @(
          VALUE #(
            client    = sy-mandt
            log_id    = lv_log_id
            timestamp = lv_timestamp
            log_level = iv_level
            message   = iv_message
            username  = sy-uname
            program   = sy-cprog
            tcode     = sy-tcode
            details   = iv_details
          )
        ).

        IF sy-subrc <> 0.
          " DB yazma hatası, ama sessizce devam et
          " Silent fail - log hatası ana programı etkilememeli
        ENDIF.

      CATCH cx_root.
        " Herhangi bir hata olursa, sessizce devam et
        " Logger hiçbir zaman ana programı bozmamalı
    ENDTRY.
  ENDMETHOD.

  METHOD get_level_number.
    " String seviyeyi numeric'e çevir
    rv_level = SWITCH #( iv_level
      WHEN c_level_debug   THEN c_level_num_debug
      WHEN c_level_info    THEN c_level_num_info
      WHEN c_level_warning THEN c_level_num_warning
      WHEN c_level_error   THEN c_level_num_error
      WHEN c_level_fatal   THEN c_level_num_fatal
      ELSE c_level_num_info  " Default: INFO
    ).
  ENDMETHOD.

  METHOD load_config.
    " Konfigürasyonu DB'den oku
    TRY.
        SELECT SINGLE log_level, is_active
          FROM zcorelog_config
          WHERE config_name = @iv_config_name
          INTO @DATA(ls_config).

        IF sy-subrc = 0.
          gv_config_name   = iv_config_name.
          gv_log_level     = ls_config-log_level.
          gv_log_level_num = get_level_number( ls_config-log_level ).
          gv_is_active     = ls_config-is_active.
        ELSE.
          " Konfigürasyon bulunamadı, default değerler kullan
          gv_config_name   = 'DEFAULT'.
          gv_log_level     = c_level_info.
          gv_log_level_num = c_level_num_info.
          gv_is_active     = abap_true.
        ENDIF.

      CATCH cx_root.
        " DB okuma hatası, default değerler kullan
        gv_config_name   = 'DEFAULT'.
        gv_log_level     = c_level_info.
        gv_log_level_num = c_level_num_info.
        gv_is_active     = abap_true.
    ENDTRY.
  ENDMETHOD.

  METHOD generate_log_id.
    " Benzersiz log ID oluştur: YYYYMMDDHHMMSSXXXXXX (timestamp + random)
    DATA: lv_random TYPE i.

    " Random sayı üret (0-999999)
    CALL FUNCTION 'GENERAL_GET_RANDOM_INT'
      EXPORTING
        range  = 999999
      IMPORTING
        random = lv_random.

    " Timestamp + random ile benzersiz ID
    rv_log_id = |{ sy-datum }{ sy-uzeit }{ lv_random WIDTH = 6 ALIGN = RIGHT PAD = '0' }|.

  ENDMETHOD.

ENDCLASS.
