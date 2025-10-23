# CoreLog - Basit ABAP Logger

**CoreLog**, ABAP ortamında kullanımı kolay, minimal bir merkezi loglama kütüphanesidir.

## Tasarım Felsefesi

- **Basitlik Öncelikli**: Gereksiz karmaşıklık yok
- **Hızlı Başlangıç**: 5 dakikada kurulum ve kullanıma hazır
- **Minimum Tablo**: Sadece 2 tablo, 1 sınıf
- **Kolay Bakım**: Az kod = az hata

## İçindekiler
- [Özellikler](#özellikler)
- [Hızlı Başlangıç](#hızlı-başlangıç)
- [Mimari](#mimari)
- [Kullanım Örnekleri](#kullanım-örnekleri)
- [Gelişmiş Özellikler](#gelişmiş-özellikler)

---

## Özellikler

- 5 log seviyesi: DEBUG, INFO, WARNING, ERROR, FATAL
- **TYPE ANY desteği**: String, Structure, Table, Primitive tipleri destekler
- **Otomatik JSON serialization**: Structure ve Table'lar otomatik JSON'a çevrilir
- **Boyut takibi**: Her log'un KB cinsinden boyutunu saklar
- Veritabanına otomatik kayıt
- Hata durumunda güvenli çalışma (silent fail)
- Log seviyesi kontrolü (sadece önemli loglar kaydedilir)
- Kullanıcı ve timestamp otomatik ekleme

---

## Hızlı Başlangıç

### 1. Tabloları Oluştur

**ZCORELOG_CONFIG** - Minimal konfigürasyon
```abap
@EndUserText.label : 'CoreLog Konfigürasyon'
define table zcorelog_config {
  key client      : abap.clnt;
  key config_name : abap.char(30);
  log_level       : abap.char(10);  // 'DEBUG', 'INFO', 'ERROR' vb.
  is_active       : abap_boolean;
}
```

**ZCORELOG_LOG** - Log kayıtları
```abap
@EndUserText.label : 'CoreLog Kayıtları'
define table zcorelog_log {
  key client    : abap.clnt;
  key log_id    : abap.numc(16);
  timestamp     : abap.dec(15,0);
  log_level     : abap.char(10);
  message       : abap.string(0);
  username      : abap.char(12);
  program       : abap.char(40);
  details       : abap.string(0);  // JSON formatında ek bilgiler
}
```

### 2. Sınıfı Oluştur

**ZCL_CORELOG** - Ana logger sınıfı (tek sınıf!)

### 3. İlk Konfigürasyonu Ekle

ZCORELOG_CONFIG tablosuna bir kayıt ekle:
```
CLIENT      CONFIG_NAME  LOG_LEVEL  IS_ACTIVE
100         DEFAULT      INFO       X
```

### 4. Kullanmaya Başla

```abap
REPORT zcorelog_demo.

START-OF-SELECTION.
  zcl_corelog=>info( 'Program başladı' ).
  zcl_corelog=>error( 'Bir hata oluştu' ).
```

İşte bu kadar!

---

## Mimari

### Tasarım

```
┌─────────────────┐
│  ABAP Program   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐      ┌──────────────────┐
│  ZCL_CORELOG    │─────▶│ ZCORELOG_CONFIG  │
│  (Static Class) │      │ (Ayarlar)        │
└────────┬────────┘      └──────────────────┘
         │
         ▼
┌─────────────────┐
│ ZCORELOG_LOG    │
│ (Log Kayıtları) │
└─────────────────┘
```

### Bileşenler

**1. ZCORELOG_CONFIG (2 alan)**
- `config_name`: Konfigürasyon adı
- `log_level`: Minimum log seviyesi

**2. ZCORELOG_LOG (8 alan)**
- `log_id`: Benzersiz numara
- `timestamp`: Zaman damgası
- `log_level`: Seviye
- `message`: Mesaj
- `username`: Kullanıcı
- `program`: Program adı
- `details`: JSON ek bilgiler (TYPE ANY → JSON)
- `data_size_kb`: Veri boyutu (KB)

**3. ZCL_CORELOG (1 sınıf)**
- Statik metodlar: `debug()`, `info()`, `warning()`, `error()`, `fatal()`
- Otomatik seviye kontrolü
- Güvenli hata yönetimi

## Kullanım Örnekleri

### 1. Basit String ile Kullanım

```abap
REPORT zdemo_logger.

START-OF-SELECTION.
  " Sadece çağır - konfigürasyon otomatik okunur
  zcl_corelog=>info( 'Program başladı' ).

  " Farklı seviyeler
  zcl_corelog=>debug( 'Değişken değeri: ' && lv_value ).
  zcl_corelog=>warning( 'Dikkat: Stok azaldı' ).
  zcl_corelog=>error( 'Kayıt bulunamadı' ).
```

### 2. Structure ile Kullanım (YENİ!)

```abap
TYPES: BEGIN OF ty_user,
         user_id   TYPE i,
         username  TYPE char20,
         email     TYPE char50,
       END OF ty_user.

DATA(ls_user) = VALUE ty_user(
  user_id  = 12345
  username = 'johndoe'
  email    = 'john@example.com'
).

" Structure direkt gönder - otomatik JSON'a çevrilir!
zcl_corelog=>info(
  iv_message = 'Kullanıcı oluşturuldu'
  iv_data    = ls_user
).

" DB'de şöyle saklanır:
" details = '{"user_id":12345,"username":"johndoe","email":"john@example.com"}'
" data_size_kb = 0.15
```

### 3. Table ile Kullanım (YENİ!)

```abap
TYPES: BEGIN OF ty_order,
         order_id TYPE i,
         amount   TYPE p DECIMALS 2,
       END OF ty_order.

DATA: lt_orders TYPE TABLE OF ty_order.

lt_orders = VALUE #(
  ( order_id = 1001 amount = '1500.50' )
  ( order_id = 1002 amount = '2300.00' )
).

" Table direkt gönder - otomatik JSON array'e çevrilir!
zcl_corelog=>info(
  iv_message = 'Siparişler işlendi'
  iv_data    = lt_orders
).

" DB'de şöyle saklanır:
" details = '[{"order_id":1001,"amount":1500.50},{"order_id":1002,"amount":2300.00}]'
" data_size_kb = 0.18
```

### 4. Try-Catch ile Kullanım

```abap
TRY.
    " Riskli işlem
    CALL FUNCTION 'SOME_FUNCTION'.
    zcl_corelog=>info( 'İşlem başarılı' ).

  CATCH cx_root INTO DATA(lx_error).
    zcl_corelog=>error(
      iv_message = 'Hata: ' && lx_error->get_text( )
      iv_details = lx_error->if_message~get_longtext( )
    ).
ENDTRY.
```

### 5. Döngülerde Kullanım

```abap
LOOP AT lt_data INTO DATA(ls_data).
  zcl_corelog=>debug( |İşleniyor: { ls_data-id }| ).

  " İş mantığı
  IF ls_data-status = 'ERROR'.
    zcl_corelog=>warning( |Sorunlu kayıt: { ls_data-id }| ).
  ENDIF.
ENDLOOP.

zcl_corelog=>info( |{ lines( lt_data ) } kayıt işlendi| ).
```

### 6. Büyük Table ile Loglama (Boyut Takibi)

```abap
DATA: lt_big_table TYPE TABLE OF ty_complex_structure.

" 1000 kayıtlı büyük bir tablo
DO 1000 TIMES.
  APPEND ... TO lt_big_table.
ENDDO.

" Otomatik boyut hesaplama
zcl_corelog=>info(
  iv_message = 'Toplu veri işlemi'
  iv_data    = lt_big_table
).

" DB'de data_size_kb = 250.35 gibi bir değer saklanır
" SE16'dan boyutu görebilirsin!
```

---

## Gelişmiş Özellikler

### TYPE ANY Desteği

CoreLog v2.1'den itibaren `iv_data TYPE any` parametresi ile her tipten veriyi loglay abilirsiniz:

**Desteklenen Tipler:**
- ✅ **String**: Direkt olarak saklanır
- ✅ **Structure**: Otomatik JSON'a çevrilir
- ✅ **Table**: Otomatik JSON array'e çevrilir
- ✅ **Primitive** (integer, decimal, boolean, date): String'e çevrilir
- ✅ **Nested Structure**: İç içe yapılar desteklenir

**Nasıl Çalışır?**
1. RTTI ile tip tespiti yapılır
2. `/UI2/CL_JSON` ile SAP standart serialization
3. Otomatik boyut hesaplama (bytes → KB)
4. DB'ye JSON formatında saklanır

**Avantajlar:**
- Kullanıcı manual JSON yazmak zorunda değil
- Tip güvenliği (compile-time check)
- Otomatik boyut takibi
- Standart SAP sınıfı kullanımı

### Boyut Takibi (Size Tracking)

Her log kaydı için `data_size_kb` alanı otomatik hesaplanır:

```sql
SELECT message, data_size_kb
  FROM zcorelog_log
  ORDER BY data_size_kb DESCENDING.

-- En büyük logları bul
-- Performans optimizasyonu için kullan
```

**Kullanım Senaryoları:**
- Hangi logların çok yer kapladığını görmek
- Storage optimizasyonu
- Log rotation stratejisi belirlemek
- Cost analysis

### Log Seviyesi Nasıl Çalışır?

```
Konfigürasyon: LOG_LEVEL = 'INFO'

zcl_corelog=>debug(...)    → ❌ Yazılmaz (DEBUG < INFO)
zcl_corelog=>info(...)     → ✅ Yazılır
zcl_corelog=>warning(...)  → ✅ Yazılır
zcl_corelog=>error(...)    → ✅ Yazılır
zcl_corelog=>fatal(...)    → ✅ Yazılır
```

**Seviye Hiyerarşisi:**
```
DEBUG (1) < INFO (2) < WARNING (3) < ERROR (4) < FATAL (5)
```

### Performans İpuçları

**1. Production'da INFO kullan**
```
LOG_LEVEL = 'INFO'  → DEBUG logları yazılmaz (performans kazancı)
```

**2. Debug'da DEBUG kullan**
```
LOG_LEVEL = 'DEBUG' → Tüm loglar yazılır (detaylı analiz)
```

**3. Kritik sistemlerde ERROR kullan**
```
LOG_LEVEL = 'ERROR' → Sadece hatalar yazılır (minimum overhead)
```

### Özelleştirme

**Farklı programlar için farklı seviyeler:**

```
CONFIG_NAME     LOG_LEVEL
DEFAULT         INFO
BACKGROUND      DEBUG
CRITICAL_BATCH  ERROR
```

ZCL_CORELOG sınıfında:
```abap
" Program adına göre config seç
DATA(lv_config) = COND #(
  WHEN sy-cprog CS 'BATCH' THEN 'BACKGROUND'
  WHEN sy-cprog CS 'CRIT'  THEN 'CRITICAL_BATCH'
  ELSE 'DEFAULT'
).
```

---

## SSS (Sık Sorulan Sorular)

**S: Eski karmaşık versiyon nerede?**
C: Bu basitleştirilmiş versiyon %90 kullanım senaryosunu karşılıyor. İleri özellikler (API/FTP hedefleri, asenkron mod vb.) ihtiyaç halinde eklenebilir.

**S: Performans etkisi var mı?**
C: Minimal. Log seviyesi kontrolü sayesinde gereksiz INSERT'ler yapılmaz. DEBUG logları production'da devre dışı bırakılabilir.

**S: Hata durumunda ne olur?**
C: Logger hata verse bile ana program çalışmaya devam eder (silent fail). Bu sayede log hatası program akışını engellemez.

**S: JSON details zorunlu mu?**
C: Hayır. Basit mesajlar için sadece `iv_message` yeterli. Detaylı bilgi gerekirse JSON eklenebilir.

**S: Eski loglar nasıl silinir?**
C: Periyodik job ile ZCORELOG_LOG tablosundan eski kayıtlar silinebilir:
```abap
DELETE FROM zcorelog_log
  WHERE timestamp < sy-datum - 90.  " 90 gün öncesi
```

---

## Basit vs Karmaşık Karşılaştırma

| Özellik | Eski Karmaşık | Yeni Basit |
|---------|---------------|------------|
| **Tablo Sayısı** | 5 tablo | 2 tablo |
| **Sınıf Sayısı** | 5+ sınıf | 1 sınıf |
| **Interface** | 3 interface | 0 interface |
| **Kurulum Süresi** | 30+ dakika | 5 dakika |
| **Kod Satırı** | ~1000+ | ~200 |
| **Öğrenme Eğrisi** | Dik | Düz |
| **Bakım** | Zor | Kolay |
| **Özellikler** | Çok (gereksiz) | Yeterli |

---

## Katkıda Bulunma

Basitliği koruyarak iyileştirme önerileri bekliyoruz!

## Lisans

MIT
