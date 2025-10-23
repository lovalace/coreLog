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

**2. ZCORELOG_LOG (7 alan)**
- `log_id`: Benzersiz numara
- `timestamp`: Zaman damgası
- `log_level`: Seviye
- `message`: Mesaj
- `username`: Kullanıcı
- `program`: Program adı
- `details`: JSON ek bilgiler

**3. ZCL_CORELOG (1 sınıf)**
- Statik metodlar: `debug()`, `info()`, `warning()`, `error()`, `fatal()`
- Otomatik seviye kontrolü
- Güvenli hata yönetimi

## Kullanım Örnekleri

### 1. Temel Kullanım

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

### 2. Detaylı Bilgi Ekleme

```abap
DATA(lv_details) = |{{ "order_id": "{ lv_order }", "status": "failed" }}|.

zcl_corelog=>error(
  iv_message = 'Sipariş işlenemedi'
  iv_details = lv_details
).
```

### 3. Try-Catch ile Kullanım

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

### 4. Döngülerde Kullanım

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

---

## Gelişmiş Özellikler

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
