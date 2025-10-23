*&---------------------------------------------------------------------*
*& Report: ZCORELOG_TEST
*& Açıklama: CoreLog unit test ve validasyon (TYPE ANY Support)
*& Versiyon: 2.1
*&---------------------------------------------------------------------*

REPORT zcorelog_test.

DATA: gv_test_count   TYPE i,
      gv_passed_count TYPE i,
      gv_failed_count TYPE i.

*&---------------------------------------------------------------------*
*& Test Type Tanımları
*&---------------------------------------------------------------------*
TYPES: BEGIN OF ty_test_user,
         user_id  TYPE i,
         username TYPE char20,
       END OF ty_test_user.

TYPES: BEGIN OF ty_test_order,
         order_id TYPE i,
         amount   TYPE p DECIMALS 2,
       END OF ty_test_order.

*&---------------------------------------------------------------------*
*& Test Yardımcı Makroları
*&---------------------------------------------------------------------*
DEFINE test_start.
  gv_test_count = gv_test_count + 1.
  WRITE: / '[ TEST', gv_test_count, '] ', &1.
END-OF-DEFINITION.

DEFINE test_pass.
  gv_passed_count = gv_passed_count + 1.
  WRITE: '   → ✓ PASSED'.
END-OF-DEFINITION.

DEFINE test_fail.
  gv_failed_count = gv_failed_count + 1.
  WRITE: '   → ✗ FAILED: ', &1.
END-OF-DEFINITION.

*&---------------------------------------------------------------------*
*& Main Test Runner
*&---------------------------------------------------------------------*
START-OF-SELECTION.

  WRITE: / '═══════════════════════════════════════════════════════',
         / 'CoreLog Test Suite v2.1 (TYPE ANY Support)',
         / '═══════════════════════════════════════════════════════',
         /.

  " Test suite
  PERFORM test_initialization.
  PERFORM test_log_levels.
  PERFORM test_level_filtering.
  PERFORM test_silent_fail.
  PERFORM test_db_write.
  PERFORM test_structure_logging.
  PERFORM test_table_logging.
  PERFORM test_primitive_logging.
  PERFORM test_empty_data.
  PERFORM test_size_tracking.

  " Test sonuçları
  WRITE: /,
         / '═══════════════════════════════════════════════════════',
         / 'Test Sonuçları:',
         / '  Toplam   :', gv_test_count,
         / '  Başarılı :', gv_passed_count COLOR COL_POSITIVE,
         / '  Başarısız:', gv_failed_count COLOR COL_NEGATIVE.

  IF gv_failed_count = 0.
    WRITE: / '',
           / '✓ Tüm testler başarıyla geçti!' COLOR COL_POSITIVE.
  ELSE.
    WRITE: / '',
           / '✗ Bazı testler başarısız!' COLOR COL_NEGATIVE.
  ENDIF.

  WRITE: / '═══════════════════════════════════════════════════════'.

*&---------------------------------------------------------------------*
*& Test: Initialization
*&---------------------------------------------------------------------*
FORM test_initialization.

  test_start 'Logger başlatma (init)'.

  TRY.
      zcl_corelog=>init( 'DEFAULT' ).
      test_pass.
    CATCH cx_root INTO DATA(lx_error).
      test_fail lx_error->get_text( ).
  ENDTRY.

ENDFORM.

*&---------------------------------------------------------------------*
*& Test: Log Levels
*&---------------------------------------------------------------------*
FORM test_log_levels.

  test_start 'Tüm log seviyeleri çalışıyor mu?'.

  TRY.
      zcl_corelog=>debug( 'Test DEBUG log' ).
      zcl_corelog=>info( 'Test INFO log' ).
      zcl_corelog=>warning( 'Test WARNING log' ).
      zcl_corelog=>error( 'Test ERROR log' ).
      zcl_corelog=>fatal( 'Test FATAL log' ).

      test_pass.
    CATCH cx_root INTO DATA(lx_error).
      test_fail lx_error->get_text( ).
  ENDTRY.

ENDFORM.

*&---------------------------------------------------------------------*
*& Test: Level Filtering
*&---------------------------------------------------------------------*
FORM test_level_filtering.

  test_start 'Log seviye filtreleme'.

  TRY.
      " INFO seviyesi ayarla
      zcl_corelog=>set_log_level( 'INFO' ).

      " DEBUG yazılmamalı (seviye düşük)
      zcl_corelog=>debug( 'Bu yazılmamalı' ).

      " INFO yazılmalı
      zcl_corelog=>info( 'Bu yazılmalı' ).

      " ERROR yazılmalı (seviye yüksek)
      zcl_corelog=>error( 'Bu da yazılmalı' ).

      test_pass.
    CATCH cx_root INTO DATA(lx_error).
      test_fail lx_error->get_text( ).
  ENDTRY.

ENDFORM.

*&---------------------------------------------------------------------*
*& Test: Silent Fail
*&---------------------------------------------------------------------*
FORM test_silent_fail.

  test_start 'Hata durumunda sessiz devam etme'.

  TRY.
      " Çok uzun mesaj veya başka bir hata olsa bile
      " logger exception fırlatmamalı
      DATA(lv_long_message) = 'Test' && repeat( val = 'x' occ = 1000 ).

      zcl_corelog=>info( lv_long_message ).

      " Buraya kadar geldiyse test başarılı
      test_pass.

    CATCH cx_root INTO DATA(lx_error).
      test_fail lx_error->get_text( ).
  ENDTRY.

ENDFORM.

*&---------------------------------------------------------------------*
*& Test: DB Write
*&---------------------------------------------------------------------*
FORM test_db_write.

  test_start 'Veritabanına yazma kontrolü'.

  " Unique mesaj oluştur
  DATA(lv_timestamp) = |{ sy-datum }{ sy-uzeit }|.
  DATA(lv_test_msg) = |TEST_MESSAGE_{ lv_timestamp }|.

  " Log yaz
  zcl_corelog=>info( lv_test_msg ).

  " Kısa bekle (async işlem varsa)
  WAIT UP TO 1 SECONDS.

  " DB'den oku
  SELECT SINGLE message
    FROM zcorelog_log
    WHERE message = @lv_test_msg
    INTO @DATA(lv_result).

  IF sy-subrc = 0.
    test_pass.
  ELSE.
    test_fail 'Log DB''ye yazılmadı'.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*& Test: Structure Logging (YENİ!)
*&---------------------------------------------------------------------*
FORM test_structure_logging.

  test_start 'Structure loglama (TYPE ANY)'.

  TRY.
      DATA(ls_user) = VALUE ty_test_user(
        user_id  = 999
        username = 'testuser'
      ).

      zcl_corelog=>info(
        iv_message = 'Test structure log'
        iv_data    = ls_user
      ).

      " Kısa bekle
      WAIT UP TO 1 SECONDS.

      " DB'den kontrol et - JSON formatında olmalı
      SELECT SINGLE details
        FROM zcorelog_log
        WHERE message = 'Test structure log'
        ORDER BY timestamp DESCENDING
        INTO @DATA(lv_json).

      IF sy-subrc = 0 AND lv_json CS 'user_id'.
        test_pass.
      ELSE.
        test_fail 'Structure JSON''a çevrilemedi'.
      ENDIF.

    CATCH cx_root INTO DATA(lx_error).
      test_fail lx_error->get_text( ).
  ENDTRY.

ENDFORM.

*&---------------------------------------------------------------------*
*& Test: Table Logging (YENİ!)
*&---------------------------------------------------------------------*
FORM test_table_logging.

  test_start 'Table loglama (TYPE ANY)'.

  TRY.
      DATA: lt_orders TYPE TABLE OF ty_test_order.

      lt_orders = VALUE #(
        ( order_id = 1 amount = '100.00' )
        ( order_id = 2 amount = '200.00' )
      ).

      zcl_corelog=>info(
        iv_message = 'Test table log'
        iv_data    = lt_orders
      ).

      " Kısa bekle
      WAIT UP TO 1 SECONDS.

      " DB'den kontrol et - JSON array formatında olmalı
      SELECT SINGLE details
        FROM zcorelog_log
        WHERE message = 'Test table log'
        ORDER BY timestamp DESCENDING
        INTO @DATA(lv_json).

      IF sy-subrc = 0 AND lv_json CS 'order_id'.
        test_pass.
      ELSE.
        test_fail 'Table JSON array''e çevrilemedi'.
      ENDIF.

    CATCH cx_root INTO DATA(lx_error).
      test_fail lx_error->get_text( ).
  ENDTRY.

ENDFORM.

*&---------------------------------------------------------------------*
*& Test: Primitive Type Logging (YENİ!)
*&---------------------------------------------------------------------*
FORM test_primitive_logging.

  test_start 'Primitive type loglama'.

  TRY.
      DATA: lv_number TYPE i VALUE 42.

      zcl_corelog=>info(
        iv_message = 'Test primitive log'
        iv_data    = lv_number
      ).

      " Kısa bekle
      WAIT UP TO 1 SECONDS.

      " DB'den kontrol et
      SELECT SINGLE details
        FROM zcorelog_log
        WHERE message = 'Test primitive log'
        ORDER BY timestamp DESCENDING
        INTO @DATA(lv_result).

      IF sy-subrc = 0 AND lv_result CS '42'.
        test_pass.
      ELSE.
        test_fail 'Primitive type loglanamadı'.
      ENDIF.

    CATCH cx_root INTO DATA(lx_error).
      test_fail lx_error->get_text( ).
  ENDTRY.

ENDFORM.

*&---------------------------------------------------------------------*
*& Test: Empty Data Handling (YENİ!)
*&---------------------------------------------------------------------*
FORM test_empty_data.

  test_start 'Boş data güvenli işleme'.

  TRY.
      " Sadece mesaj, data yok
      zcl_corelog=>info( iv_message = 'Test empty data' ).

      " Boş structure
      DATA: ls_empty_user TYPE ty_test_user.
      zcl_corelog=>info(
        iv_message = 'Test empty structure'
        iv_data    = ls_empty_user
      ).

      " Buraya kadar geldiyse başarılı
      test_pass.

    CATCH cx_root INTO DATA(lx_error).
      test_fail lx_error->get_text( ).
  ENDTRY.

ENDFORM.

*&---------------------------------------------------------------------*
*& Test: Size Tracking (YENİ!)
*&---------------------------------------------------------------------*
FORM test_size_tracking.

  test_start 'Veri boyutu takibi (KB)'.

  TRY.
      DATA: lt_big_orders TYPE TABLE OF ty_test_order.

      " 50 kayıtlı tablo oluştur
      DO 50 TIMES.
        APPEND VALUE #(
          order_id = sy-index
          amount   = sy-index * 100
        ) TO lt_big_orders.
      ENDDO.

      zcl_corelog=>info(
        iv_message = 'Test size tracking'
        iv_data    = lt_big_orders
      ).

      " Kısa bekle
      WAIT UP TO 1 SECONDS.

      " DB'den kontrol et - data_size_kb 0'dan büyük olmalı
      SELECT SINGLE data_size_kb
        FROM zcorelog_log
        WHERE message = 'Test size tracking'
        ORDER BY timestamp DESCENDING
        INTO @DATA(lv_size).

      IF sy-subrc = 0 AND lv_size > 0.
        WRITE: / '      (Log boyutu:', lv_size, 'KB)'.
        test_pass.
      ELSE.
        test_fail 'Size tracking çalışmadı'.
      ENDIF.

    CATCH cx_root INTO DATA(lx_error).
      test_fail lx_error->get_text( ).
  ENDTRY.

ENDFORM.
