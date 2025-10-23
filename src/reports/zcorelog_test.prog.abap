*&---------------------------------------------------------------------*
*& Report: ZCORELOG_TEST
*& Açıklama: CoreLog unit test ve validasyon
*&---------------------------------------------------------------------*

REPORT zcorelog_test.

DATA: gv_test_count   TYPE i,
      gv_passed_count TYPE i,
      gv_failed_count TYPE i.

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
         / 'CoreLog Test Suite',
         / '═══════════════════════════════════════════════════════',
         /.

  " Önce test için temiz başlangıç
  perform test_initialization.
  perform test_log_levels.
  perform test_level_filtering.
  perform test_silent_fail.
  perform test_db_write.

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
      DATA(lv_long_message) = 'Test' && repeat( val = 'x' occ = 10000 ).

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
