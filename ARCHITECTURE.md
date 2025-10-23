# CoreLog Mimari Dokümantasyonu

## Genel Bakış

CoreLog, **basitlik ve kullanım kolaylığı** prensipleriyle tasarlanmış minimal bir ABAP logger'dır.

## Tasarım Prensipleri

### 1. KISS (Keep It Simple, Stupid)
- Gereksiz abstraction yok
- Minimum bileşen sayısı
- Tek sorumluluk prensibi

### 2. Fail-Safe
- Logger asla ana programı bozmamalı
- Tüm hatalar sessizce yakalanır
- Exception propagation yok

### 3. Zero Configuration
- Default değerlerle çalışır
- Konfigürasyon opsiyonel
- Manuel init gerekmez

---

## Bileşenler

```
┌─────────────────────────────────────────────────┐
│                 ABAP Program                    │
│  (REPORT, Function, Method, Class, etc.)        │
└──────────────────────┬──────────────────────────┘
                       │
                       │ Static Method Call
                       │ (zcl_corelog=>info(...))
                       │
                       ▼
┌─────────────────────────────────────────────────┐
│            ZCL_CORELOG (Singleton)              │
│  ┌───────────────────────────────────────────┐  │
│  │ Public Methods:                           │  │
│  │  - debug()                                │  │
│  │  - info()                                 │  │
│  │  - warning()                              │  │
│  │  - error()                                │  │
│  │  - fatal()                                │  │
│  │  - init()                                 │  │
│  │  - set_log_level()                        │  │
│  └───────────────────────────────────────────┘  │
│                                                  │
│  ┌───────────────────────────────────────────┐  │
│  │ Private Methods:                          │  │
│  │  - log_internal()     [Seviye kontrolü]  │  │
│  │  - write_to_db()      [DB yazma]         │  │
│  │  - load_config()      [Config okuma]     │  │
│  │  - get_level_number() [String→Numeric]   │  │
│  │  - generate_log_id()  [Unique ID]        │  │
│  └───────────────────────────────────────────┘  │
│                                                  │
│  ┌───────────────────────────────────────────┐  │
│  │ Class Variables (Static):                 │  │
│  │  - gv_config_name                         │  │
│  │  - gv_log_level                           │  │
│  │  - gv_log_level_num                       │  │
│  │  - gv_is_active                           │  │
│  │  - gv_initialized                         │  │
│  └───────────────────────────────────────────┘  │
└────────┬────────────────────────────┬───────────┘
         │                            │
         │ SELECT                     │ INSERT
         │                            │
         ▼                            ▼
┌─────────────────┐          ┌─────────────────┐
│ ZCORELOG_CONFIG │          │ ZCORELOG_LOG    │
│                 │          │                 │
│ - config_name   │          │ - log_id        │
│ - log_level     │          │ - timestamp     │
│ - is_active     │          │ - log_level     │
│                 │          │ - message       │
│                 │          │ - username      │
│                 │          │ - program       │
│                 │          │ - tcode         │
│                 │          │ - details       │
└─────────────────┘          └─────────────────┘
```

---

## Veri Akışı

### 1. Loglama İsteği
```
User Code → zcl_corelog=>info('mesaj')
```

### 2. İlk Çağrı (Lazy Initialization)
```
log_internal() kontrol eder:
  ├─ gv_initialized = false mi?
  │   └─ init() çağır
  │       └─ load_config()
  │           ├─ ZCORELOG_CONFIG'den oku
  │           ├─ gv_log_level ayarla
  │           └─ gv_initialized = true
  └─ Devam et
```

### 3. Seviye Kontrolü
```
log_internal():
  ├─ is_active kontrolü
  │   └─ false ise → ÇIK
  │
  ├─ Seviye karşılaştırma
  │   └─ iv_level < gv_log_level_num ise → ÇIK
  │
  └─ write_to_db() çağır
```

### 4. DB Yazma
```
write_to_db():
  ├─ TRY
  │   ├─ generate_log_id() → Unique ID
  │   ├─ Timestamp oluştur
  │   ├─ INSERT INTO zcorelog_log
  │   └─ sy-subrc kontrolü
  │
  └─ CATCH cx_root
      └─ Sessizce devam et (silent fail)
```

---

## Log Seviyesi Hiyerarşisi

### Numeric Değerler
```
DEBUG   (1) ──┐
INFO    (2)   │  Artan Önem
WARNING (3)   │  ↓
ERROR   (4)   │
FATAL   (5) ──┘
```

### Filtreleme Mantığı

**Konfigürasyon: LOG_LEVEL = 'INFO' (numeric: 2)**

```abap
zcl_corelog=>debug('...')    " numeric: 1 < 2 → ❌ YAZILMAZ
zcl_corelog=>info('...')     " numeric: 2 = 2 → ✅ YAZILIR
zcl_corelog=>warning('...')  " numeric: 3 > 2 → ✅ YAZILIR
zcl_corelog=>error('...')    " numeric: 4 > 2 → ✅ YAZILIR
zcl_corelog=>fatal('...')    " numeric: 5 > 2 → ✅ YAZILIR
```

### Kod İmplementasyonu
```abap
METHOD log_internal.
  DATA(lv_current_level_num) = get_level_number( iv_level ).

  IF lv_current_level_num < gv_log_level_num.
    RETURN.  " Seviye düşük, yazma
  ENDIF.

  write_to_db( ... ).
ENDMETHOD.
```

---

## Hata Yönetimi Stratejisi

### Prensip: "Never Break the Main Program"

Tüm operasyonlar TRY-CATCH blokları içinde:

```abap
METHOD write_to_db.
  TRY.
      " DB operasyonu
      INSERT INTO zcorelog_log VALUES ...

      IF sy-subrc <> 0.
        " Hata oldu ama exception fırlatma
        " Sadece devam et
      ENDIF.

  CATCH cx_root.
      " Herhangi bir hata → sessizce devam
      " Logger hatası ana programı asla bozmamalı
  ENDTRY.
ENDMETHOD.
```

### Hata Senaryoları

| Senaryo | Davranış |
|---------|----------|
| Tablo yok | Silent fail, program devam |
| Yetki yok | Silent fail, program devam |
| Disk dolu | Silent fail, program devam |
| Network timeout | N/A (DB local) |
| NULL string | Boş string kaydedilir |
| Çok uzun mesaj | DB truncate eder |

---

## Performans Optimizasyonları

### 1. Lazy Initialization
```abap
" init() ilk log çağrısında otomatik çalışır
" Gereksiz DB okuması yok
IF gv_initialized = abap_false.
  init( ).
ENDIF.
```

### 2. Seviye Kontrolü (Early Return)
```abap
" DB'ye yazmadan önce filtrele
IF lv_current_level_num < gv_log_level_num.
  RETURN.  " Gereksiz INSERT önlendi
ENDIF.
```

### 3. Single INSERT (Batch Yok)
```abap
" Basitlik için her log ayrı INSERT
" İhtiyaç halinde buffer eklenebilir
INSERT INTO zcorelog_log VALUES ...
```

### 4. Index Kullanımı
```sql
-- ZCORELOG_LOG tablosunda önerilen index
INDEX: (TIMESTAMP, LOG_LEVEL, USERNAME)

-- Sık kullanılan sorgular:
SELECT * FROM zcorelog_log
  WHERE timestamp >= '20240101000000'
    AND log_level = 'ERROR'
    AND username = 'JOHNDOE'
```

---

## Genişletilebilirlik

### Mevcut Mimari: Minimal

```
1 Class + 2 Tables = Basit Ama Yeterli
```

### Gelecekte Eklenebilecek Özellikler

#### 1. Asenkron Buffer (Performance)
```abap
CLASS-DATA: gt_log_buffer TYPE TABLE OF zcorelog_log.

METHOD enable_async_logging.
  gv_async_mode = abap_true.
ENDMETHOD.

METHOD flush.
  INSERT zcorelog_log FROM TABLE @gt_log_buffer.
  CLEAR gt_log_buffer.
ENDMETHOD.
```

#### 2. API Target (Multiple Destinations)
```abap
METHOD write_to_api.
  cl_http_client=>create_by_url( ... ).
  " JSON payload gönder
ENDMETHOD.
```

#### 3. GZIP Compression (Space Saving)
```abap
METHOD compress_message.
  cl_abap_gzip=>compress_binary( ... ).
ENDMETHOD.
```

#### 4. Modül Bazlı Config (Advanced Filtering)
```abap
" ZCORELOG_MODULE tablosu ekle
SELECT SINGLE module_level
  FROM zcorelog_module
  WHERE module_name = @sy-cprog
  INTO @lv_module_level.
```

---

## Güvenlik Mimarisi

### 1. Yetkilendirme (Önerilir)

```abap
" Custom authorization object: ZCORELOG
" Activity:
"   01 = Create logs
"   03 = Display logs
"   06 = Delete logs

AUTHORITY-CHECK OBJECT 'ZCORELOG'
  ID 'ACTVT' FIELD '01'.

IF sy-subrc <> 0.
  " Yetki yok, loglamayı engelle
  RETURN.
ENDIF.
```

### 2. Sensitive Data Masking

```abap
METHOD mask_sensitive_data.
  " Kredi kartı numaralarını maskele
  lv_message = replace(
    val = lv_message
    regex = '\d{4}[-\s]?\d{4}[-\s]?\d{4}[-\s]?\d{4}'
    with = 'XXXX-XXXX-XXXX-XXXX'
  ).
ENDMETHOD.
```

### 3. Log Retention Policy

```abap
" Periyodik job (ZCORELOG_CLEANUP)
DELETE FROM zcorelog_log
  WHERE timestamp < @lv_cutoff_date.

" Örnek: 90 gün sonra sil
lv_cutoff_date = sy-datum - 90.
```

---

## Test Stratejisi

### Unit Test Coverage

| Metod | Test Tipi | Beklenen |
|-------|-----------|----------|
| debug() | Functional | Log yazılır |
| info() | Functional | Log yazılır |
| error() | Functional | Log yazılır |
| log_internal() | Unit | Seviye filtresi çalışır |
| write_to_db() | Integration | DB insert başarılı |
| load_config() | Integration | Config okunur |
| get_level_number() | Unit | String→Numeric doğru |
| generate_log_id() | Unit | Unique ID üretilir |

### Test Programı: ZCORELOG_TEST

Tüm core fonksiyonları test eder:
- ✓ Initialization
- ✓ Log levels
- ✓ Level filtering
- ✓ Silent fail
- ✓ DB write

---

## Deployment Mimarisi

### Development → Quality → Production

```
┌────────────────┐
│ Development    │  1. SE11 - Tablolar oluştur
│ (DEV Client)   │  2. SE24 - Sınıf oluştur
│                │  3. SE38 - Test programları
└───────┬────────┘  4. Test et
        │
        │ Transport Request (DEVK9xxxxx)
        │
        ▼
┌────────────────┐
│ Quality        │  1. Transport import
│ (QAS Client)   │  2. Integration test
│                │  3. UAT
└───────┬────────┘  4. Performance test
        │
        │ Transport Request (onay sonrası)
        │
        ▼
┌────────────────┐
│ Production     │  1. Transport import
│ (PRD Client)   │  2. Smoke test
│                │  3. Config ayarları (LOG_LEVEL)
└────────────────┘  4. Monitoring
```

### Customizing Transport

```
SE09 → Create Transport Request
├─ Type: Customizing Request
├─ Objects:
│   ├─ TABL ZCORELOG_CONFIG
│   ├─ TABL ZCORELOG_LOG
│   ├─ CLAS ZCL_CORELOG
│   ├─ PROG ZCORELOG_DEMO
│   └─ PROG ZCORELOG_TEST
└─ Release → Import to QAS/PRD
```

---

## Monitoring ve Troubleshooting

### Log Analizi

```sql
-- En çok hata veren programlar
SELECT program, COUNT(*) as error_count
FROM zcorelog_log
WHERE log_level = 'ERROR'
  AND timestamp >= '20240101000000'
GROUP BY program
ORDER BY error_count DESC;

-- Kullanıcı bazlı aktivite
SELECT username, log_level, COUNT(*) as cnt
FROM zcorelog_log
WHERE timestamp >= '20240101000000'
GROUP BY username, log_level;

-- Saatlik log dağılımı
SELECT SUBSTRING(timestamp, 1, 10) as hour,
       COUNT(*) as log_count
FROM zcorelog_log
GROUP BY SUBSTRING(timestamp, 1, 10)
ORDER BY hour DESC;
```

### Health Check Report (ZCORELOG_HEALTH)

```abap
" Önerilen kontroller:
" 1. Son 1 saatte log var mı?
" 2. Tablo boyutu kritik seviyede mi?
" 3. CONFIG aktif mi?
" 4. Index kullanımı optimize mi?
```

---

## Sonuç

CoreLog mimarisi:
- ✅ Basit ve anlaşılır
- ✅ Genişletilebilir
- ✅ Güvenli (fail-safe)
- ✅ Performanslı
- ✅ Test edilebilir
- ✅ Production-ready

**"Complexity is the enemy of reliability"** - Unknown
