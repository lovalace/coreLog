*&---------------------------------------------------------------------*
*& Class: ZCL_CORELOG
*& Açıklama: Basit, minimal ABAP logger
*& Versiyon: 2.1 (TYPE ANY Support + Size Tracking)
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
        iv_data    TYPE any OPTIONAL.

    CLASS-METHODS info
      IMPORTING
        iv_message TYPE string
        iv_data    TYPE any OPTIONAL.

    CLASS-METHODS warning
      IMPORTING
        iv_message TYPE string
        iv_data    TYPE any OPTIONAL.

    CLASS-METHODS error
      IMPORTING
        iv_message TYPE string
        iv_data    TYPE any OPTIONAL.

    CLASS-METHODS fatal
      IMPORTING
        iv_message TYPE string
        iv_data    TYPE any OPTIONAL.

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
        iv_data    TYPE any OPTIONAL.

    CLASS-METHODS write_to_db
      IMPORTING
        iv_level   TYPE char10
        iv_message TYPE string
        iv_data    TYPE any OPTIONAL.

    CLASS-METHODS serialize_data
      IMPORTING
        iv_data           TYPE any
      RETURNING
        VALUE(rv_json)    TYPE string.

    CLASS-METHODS calculate_size_kb
      IMPORTING
        iv_data             TYPE string
      RETURNING
        VALUE(rv_size_kb)   TYPE dec10_2.

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
      iv_data    = iv_data
    ).
  ENDMETHOD.

  METHOD info.
    log_internal(
      iv_level   = c_level_info
      iv_message = iv_message
      iv_data    = iv_data
    ).
  ENDMETHOD.

  METHOD warning.
    log_internal(
      iv_level   = c_level_warning
      iv_message = iv_message
      iv_data    = iv_data
    ).
  ENDMETHOD.

  METHOD error.
    log_internal(
      iv_level   = c_level_error
      iv_message = iv_message
      iv_data    = iv_data
    ).
  ENDMETHOD.

  METHOD fatal.
    log_internal(
      iv_level   = c_level_fatal
      iv_message = iv_message
      iv_data    = iv_data
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
      iv_data    = iv_data
    ).
  ENDMETHOD.

  METHOD write_to_db.
    " Güvenli DB yazma (hata olsa bile program durmaz)
    TRY.
        DATA(lv_log_id) = generate_log_id( ).

        " Timestamp oluştur: YYYYMMDDHHMMSS
        DATA(lv_timestamp) = CONV dec15( |{ sy-datum }{ sy-uzeit }| ).

        " Veriyi serialize et (TYPE ANY → JSON string)
        DATA(lv_details) = serialize_data( iv_data ).

        " Veri boyutunu hesapla (KB cinsinden)
        DATA(lv_size_kb) = calculate_size_kb( lv_details ).

        INSERT INTO zcorelog_log VALUES @(
          VALUE #(
            client       = sy-mandt
            log_id       = lv_log_id
            timestamp    = lv_timestamp
            log_level    = iv_level
            message      = iv_message
            username     = sy-uname
            program      = sy-cprog
            tcode        = sy-tcode
            details      = lv_details
            data_size_kb = lv_size_kb
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

  METHOD serialize_data.
    " TYPE ANY veriyi JSON string'e çevir
    TRY.
        " Boş veri kontrolü
        IF iv_data IS INITIAL.
          rv_json = ''.
          RETURN.
        ENDIF.

        " RTTI ile tip tespiti
        DATA(lo_type) = cl_abap_typedescr=>describe_by_data( iv_data ).

        CASE lo_type->kind.
          WHEN cl_abap_typedescr=>kind_struct.
            " Structure → JSON serialize
            /ui2/cl_json=>serialize(
              EXPORTING
                data        = iv_data
                compress    = abap_false
                pretty_name = /ui2/cl_json=>pretty_mode-low_case
              RECEIVING
                r_json      = rv_json
            ).

          WHEN cl_abap_typedescr=>kind_table.
            " Table → JSON array serialize
            /ui2/cl_json=>serialize(
              EXPORTING
                data        = iv_data
                compress    = abap_false
                pretty_name = /ui2/cl_json=>pretty_mode-low_case
              RECEIVING
                r_json      = rv_json
            ).

          WHEN cl_abap_typedescr=>kind_elem.
            " Primitive type → direkt string'e çevir
            DATA lv_string TYPE string.
            lv_string = iv_data.
            rv_json = lv_string.

          WHEN OTHERS.
            " String varsay
            rv_json = iv_data.
        ENDCASE.

      CATCH cx_root INTO DATA(lx_error).
        " Serialize hatası, boş string dön
        rv_json = |Serialize error: { lx_error->get_text( ) }|.
    ENDTRY.
  ENDMETHOD.

  METHOD calculate_size_kb.
    " String boyutunu KB cinsinden hesapla
    TRY.
        DATA(lv_length) = strlen( iv_data ).

        " UTF-8 encoding varsayımıyla byte hesapla
        " ABAP string'ler genelde UTF-16 (2 byte/char)
        DATA(lv_bytes) = lv_length * 2.

        " Bytes → KB (1 KB = 1024 bytes)
        rv_size_kb = lv_bytes / 1024.

        " Çok küçük değerler için 0.01 minimum
        IF rv_size_kb < '0.01' AND lv_bytes > 0.
          rv_size_kb = '0.01'.
        ENDIF.

      CATCH cx_root.
        " Hata durumunda 0
        rv_size_kb = 0.
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
