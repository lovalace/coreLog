*&---------------------------------------------------------------------*
*& Report: ZCORELOG_DEMO
*& Açıklama: CoreLog kullanım örnekleri
*&---------------------------------------------------------------------*

REPORT zcorelog_demo.

*&---------------------------------------------------------------------*
*& Örnek 1: Temel Kullanım
*&---------------------------------------------------------------------*
START-OF-SELECTION.

  WRITE: / '═══════════════════════════════════════════════════════',
         / 'CoreLog Demo - Basit Logger Kullanımı',
         / '═══════════════════════════════════════════════════════',
         /.

  " Konfigürasyonu başlat (opsiyonel - otomatik de başlar)
  zcl_corelog=>init( ).

  WRITE: / '1. Temel log mesajları...'.
  zcl_corelog=>debug( 'Bu bir DEBUG mesajıdır' ).
  zcl_corelog=>info( 'Program başlatıldı' ).
  zcl_corelog=>warning( 'Dikkat: Stok seviyesi düşük' ).
  zcl_corelog=>error( 'Hata: Kayıt bulunamadı' ).
  zcl_corelog=>fatal( 'Kritik hata: Sistem yanıt vermiyor' ).

  WRITE: / '   ✓ 5 farklı seviyede log yazıldı',
         /.

*&---------------------------------------------------------------------*
*& Örnek 2: Detaylı Bilgi ile Loglama
*&---------------------------------------------------------------------*
  WRITE: / '2. JSON detayları ile loglama...'.

  DATA(lv_order_id) = '12345'.
  DATA(lv_customer) = 'ACME Corp'.

  DATA(lv_details) = |{{ "order_id": "{ lv_order_id }", | &&
                     |"customer": "{ lv_customer }", | &&
                     |"amount": 1500.50 }}|.

  zcl_corelog=>info(
    iv_message = 'Sipariş oluşturuldu'
    iv_details = lv_details
  ).

  WRITE: / '   ✓ Detaylı log JSON formatında yazıldı',
         /.

*&---------------------------------------------------------------------*
*& Örnek 3: Try-Catch ile Hata Yakalama
*&---------------------------------------------------------------------*
  WRITE: / '3. Exception handling...'.

  TRY.
      " Hata üretmek için kasıtlı olarak var olmayan tablo
      DATA: lt_dummy TYPE STANDARD TABLE OF zcorelog_log.
      SELECT * FROM zcorelog_nonexistent INTO TABLE @lt_dummy UP TO 1 ROWS.

      zcl_corelog=>info( 'İşlem başarılı' ).

    CATCH cx_root INTO DATA(lx_error).
      zcl_corelog=>error(
        iv_message = |Hata yakalandı: { lx_error->get_text( ) }|
        iv_details = |{{ "exception": "{ lx_error->get_text( ) }" }}|
      ).

      WRITE: / '   ✓ Exception yakalanıp loglandı',
             /.
  ENDTRY.

*&---------------------------------------------------------------------*
*& Örnek 4: Döngüde Loglama
*&---------------------------------------------------------------------*
  WRITE: / '4. Toplu işlem loglaması...'.

  TYPES: BEGIN OF ty_data,
           id     TYPE i,
           status TYPE char10,
         END OF ty_data.

  DATA: lt_data TYPE TABLE OF ty_data.

  " Test verisi oluştur
  lt_data = VALUE #(
    ( id = 1 status = 'SUCCESS' )
    ( id = 2 status = 'ERROR' )
    ( id = 3 status = 'SUCCESS' )
    ( id = 4 status = 'WARNING' )
    ( id = 5 status = 'SUCCESS' )
  ).

  LOOP AT lt_data INTO DATA(ls_data).
    CASE ls_data-status.
      WHEN 'SUCCESS'.
        zcl_corelog=>debug( |Kayıt { ls_data-id } başarıyla işlendi| ).
      WHEN 'WARNING'.
        zcl_corelog=>warning( |Kayıt { ls_data-id } uyarı ile işlendi| ).
      WHEN 'ERROR'.
        zcl_corelog=>error( |Kayıt { ls_data-id } hata verdi| ).
    ENDCASE.
  ENDLOOP.

  zcl_corelog=>info( |Toplam { lines( lt_data ) } kayıt işlendi| ).

  WRITE: / '   ✓ Döngüde 6 log yazıldı',
         /.

*&---------------------------------------------------------------------*
*& Örnek 5: Seviye Kontrolü Testi
*&---------------------------------------------------------------------*
  WRITE: / '5. Log seviyesi kontrolü...'.

  " Mevcut seviye INFO ise DEBUG logları yazılmaz
  zcl_corelog=>debug( 'Bu log seviye düşük olduğu için yazılmayabilir' ).
  zcl_corelog=>info( 'Bu log yazılır (INFO seviyesi)' ).
  zcl_corelog=>error( 'Bu log kesinlikle yazılır (ERROR seviyesi)' ).

  WRITE: / '   ✓ Log seviye kontrolü çalıştı',
         /.

*&---------------------------------------------------------------------*
*& Sonuç
*&---------------------------------------------------------------------*
  WRITE: /,
         / '═══════════════════════════════════════════════════════',
         / '✓ Tüm örnekler başarıyla çalıştırıldı!',
         / '',
         / 'Logları görmek için:',
         / '  → SE16: ZCORELOG_LOG tablosunu görüntüle',
         / '  → Filtrele: USERNAME = ', sy-uname,
         / '═══════════════════════════════════════════════════════'.
