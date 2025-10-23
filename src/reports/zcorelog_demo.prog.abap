*&---------------------------------------------------------------------*
*& Report: ZCORELOG_DEMO
*& Açıklama: CoreLog kullanım örnekleri (TYPE ANY Support)
*& Versiyon: 2.1
*&---------------------------------------------------------------------*

REPORT zcorelog_demo.

*&---------------------------------------------------------------------*
*& Type Tanımları
*&---------------------------------------------------------------------*
TYPES: BEGIN OF ty_user,
         user_id   TYPE i,
         username  TYPE char20,
         email     TYPE char50,
         is_active TYPE abap_boolean,
       END OF ty_user.

TYPES: BEGIN OF ty_order,
         order_id   TYPE i,
         customer   TYPE char30,
         amount     TYPE p DECIMALS 2,
         currency   TYPE char3,
         order_date TYPE datum,
       END OF ty_order.

TYPES: BEGIN OF ty_address,
         street  TYPE char50,
         city    TYPE char30,
         country TYPE char20,
       END OF ty_address.

TYPES: BEGIN OF ty_customer,
         customer_id TYPE i,
         name        TYPE char50,
         address     TYPE ty_address,
       END OF ty_customer.

*&---------------------------------------------------------------------*
*& Örnek 1: String ile Basit Loglama
*&---------------------------------------------------------------------*
START-OF-SELECTION.

  WRITE: / '═══════════════════════════════════════════════════════',
         / 'CoreLog Demo - TYPE ANY Support',
         / '═══════════════════════════════════════════════════════',
         /.

  " Konfigürasyonu başlat (opsiyonel - otomatik de başlar)
  zcl_corelog=>init( ).

  WRITE: / '1. String ile basit loglama...'.
  zcl_corelog=>info( iv_message = 'Program başlatıldı' ).
  zcl_corelog=>debug( iv_message = 'Debug modunda' ).
  zcl_corelog=>warning( iv_message = 'Dikkat: Stok düşük' ).
  zcl_corelog=>error( iv_message = 'Hata: Kayıt bulunamadı' ).

  WRITE: / '   ✓ Farklı seviyeler ile loglandı',
         /.

*&---------------------------------------------------------------------*
*& Örnek 2: Structure ile Loglama (YENİ!)
*&---------------------------------------------------------------------*
  WRITE: / '2. Structure ile loglama (otomatik JSON)...'.

  DATA(ls_user) = VALUE ty_user(
    user_id   = 12345
    username  = 'johndoe'
    email     = 'john@example.com'
    is_active = abap_true
  ).

  " Structure direkt gönderilir, otomatik JSON'a çevrilir
  zcl_corelog=>info(
    iv_message = 'Kullanıcı oluşturuldu'
    iv_data    = ls_user
  ).

  WRITE: / '   ✓ Structure otomatik JSON''a çevrildi',
         /.

*&---------------------------------------------------------------------*
*& Örnek 3: Table ile Loglama (YENİ!)
*&---------------------------------------------------------------------*
  WRITE: / '3. Table ile loglama (otomatik JSON array)...'.

  DATA: lt_orders TYPE TABLE OF ty_order.

  lt_orders = VALUE #(
    ( order_id = 1001 customer = 'ACME Corp' amount = '1500.50' currency = 'EUR' order_date = '20240115' )
    ( order_id = 1002 customer = 'TechCo'    amount = '2300.00' currency = 'USD' order_date = '20240116' )
    ( order_id = 1003 customer = 'GlobalInc' amount = '890.25'  currency = 'EUR' order_date = '20240117' )
  ).

  " Table direkt gönderilir, otomatik JSON array'e çevrilir
  zcl_corelog=>info(
    iv_message = 'Siparişler işlendi'
    iv_data    = lt_orders
  ).

  WRITE: / '   ✓ Table otomatik JSON array''e çevrildi',
         /.

*&---------------------------------------------------------------------*
*& Örnek 4: Nested Structure ile Loglama (YENİ!)
*&---------------------------------------------------------------------*
  WRITE: / '4. Nested structure loglama...'.

  DATA(ls_customer) = VALUE ty_customer(
    customer_id = 5001
    name        = 'John Doe'
    address     = VALUE #(
      street  = '123 Main Street'
      city    = 'New York'
      country = 'USA'
    )
  ).

  zcl_corelog=>info(
    iv_message = 'Müşteri bilgileri'
    iv_data    = ls_customer
  ).

  WRITE: / '   ✓ Nested structure JSON''a çevrildi',
         /.

*&---------------------------------------------------------------------*
*& Örnek 5: Primitive Types ile Loglama (YENİ!)
*&---------------------------------------------------------------------*
  WRITE: / '5. Primitive type loglama...'.

  DATA: lv_count  TYPE i,
        lv_amount TYPE p DECIMALS 2,
        lv_flag   TYPE abap_boolean.

  lv_count = 42.
  lv_amount = '1234.56'.
  lv_flag = abap_true.

  zcl_corelog=>info(
    iv_message = 'İşlem sayısı'
    iv_data    = lv_count
  ).

  zcl_corelog=>info(
    iv_message = 'Toplam tutar'
    iv_data    = lv_amount
  ).

  zcl_corelog=>info(
    iv_message = 'Aktif mi?'
    iv_data    = lv_flag
  ).

  WRITE: / '   ✓ Primitive tipler loglandı',
         /.

*&---------------------------------------------------------------------*
*& Örnek 6: Büyük Table ile Loglama (Size Tracking)
*&---------------------------------------------------------------------*
  WRITE: / '6. Büyük table loglama (size tracking)...'.

  DATA: lt_big_orders TYPE TABLE OF ty_order.

  " 100 kayıtlı büyük bir tablo oluştur
  DO 100 TIMES.
    APPEND VALUE #(
      order_id   = sy-index
      customer   = |Customer { sy-index }|
      amount     = sy-index * 100
      currency   = 'EUR'
      order_date = sy-datum
    ) TO lt_big_orders.
  ENDDO.

  zcl_corelog=>info(
    iv_message = |{ lines( lt_big_orders ) } sipariş toplu işlendi|
    iv_data    = lt_big_orders
  ).

  WRITE: / '   ✓ Büyük table loglandı (KB değeri ile)',
         /.

*&---------------------------------------------------------------------*
*& Örnek 7: Try-Catch ile Exception Loglama
*&---------------------------------------------------------------------*
  WRITE: / '7. Exception handling...'.

  TRY.
      " Kasıtlı hata
      DATA: lt_dummy TYPE STANDARD TABLE OF zcorelog_log.
      SELECT * FROM zcorelog_nonexistent INTO TABLE @lt_dummy UP TO 1 ROWS.

    CATCH cx_root INTO DATA(lx_error).
      " Exception detaylarını structure olarak logla
      DATA: BEGIN OF ls_error_detail,
              error_type TYPE char30,
              error_text TYPE string,
              program    TYPE syrepid,
              line       TYPE i,
            END OF ls_error_detail.

      ls_error_detail-error_type = lx_error->get_text( ).
      ls_error_detail-error_text = lx_error->get_longtext( ).
      ls_error_detail-program    = sy-cprog.
      ls_error_detail-line       = sy-tabix.

      zcl_corelog=>error(
        iv_message = 'Beklenmeyen hata oluştu'
        iv_data    = ls_error_detail
      ).

      WRITE: / '   ✓ Exception structure olarak loglandı',
             /.
  ENDTRY.

*&---------------------------------------------------------------------*
*& Örnek 8: Mixed Types - String ve Structure Karışık
*&---------------------------------------------------------------------*
  WRITE: / '8. Karışık tip kullanımı...'.

  " Bazen string
  zcl_corelog=>info(
    iv_message = 'Basit mesaj'
    iv_data    = 'Detay bilgi'
  ).

  " Bazen structure
  zcl_corelog=>info(
    iv_message = 'Kullanıcı girişi'
    iv_data    = ls_user
  ).

  " Bazen table
  zcl_corelog=>info(
    iv_message = 'Son siparişler'
    iv_data    = lt_orders
  ).

  WRITE: / '   ✓ Farklı tipler aynı metodla loglandı',
         /.

*&---------------------------------------------------------------------*
*& Örnek 9: Boş Data ile Loglama
*&---------------------------------------------------------------------*
  WRITE: / '9. Boş data ile loglama...'.

  DATA: ls_empty_user TYPE ty_user.

  " Sadece mesaj, data yok
  zcl_corelog=>info( iv_message = 'Sadece mesaj' ).

  " Boş structure
  zcl_corelog=>info(
    iv_message = 'Boş structure'
    iv_data    = ls_empty_user
  ).

  WRITE: / '   ✓ Boş data güvenli şekilde işlendi',
         /.

*&---------------------------------------------------------------------*
*& Sonuç
*&---------------------------------------------------------------------*
  WRITE: /,
         / '═══════════════════════════════════════════════════════',
         / '✓ Tüm örnekler başarıyla çalıştırıldı!',
         / '',
         / 'Yeni Özellikler:',
         / '  → TYPE ANY desteği',
         / '  → Otomatik JSON serialization',
         / '  → Structure/Table/Primitive tipleri destekliyor',
         / '  → KB cinsinden boyut takibi',
         / '',
         / 'Logları görmek için:',
         / '  → SE16: ZCORELOG_LOG tablosunu görüntüle',
         / '  → Filtrele: USERNAME = ', sy-uname,
         / '  → Yeni: DATA_SIZE_KB alanını kontrol et!',
         / '═══════════════════════════════════════════════════════'.
