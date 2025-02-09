# CoreLog Projesi

Bu proje, **ABAP** ortamında merkezi loglama (logging) işlevini sağlamak amacıyla geliştirilmiş, **senkron/asenkron** ve **dependency injection** prensiplerine dayanan bir altyapı sunar. “**CoreLog**” adı altında; tablolar, sınıflar ve arayüzler bir araya gelerek esnek, konfigüre edilebilir ve modüler bir loglama çözümü oluşturur.

## İçindekiler
- [Özellikler](#özellikler)
- [Kurulum & Ön Gereksinimler](#kurulum--ön-gereksinimler)
- [Proje Mimarisi](#proje-mimarisi)
  - [Tablolar](#tablolar)
  - [Arayüzler (Interfaces)](#arayüzler-interfaces)
  - [Sınıflar](#sınıflar)
- [Konfigürasyon](#konfigürasyon)
  - [ZCORELOG_CONFIG](#zcorelog_config)
  - [ZCORELOG_TARGET](#zcorelog_target)
  - [ZCORELOG_MODULE](#zcorelog_module)
  - [ZCORELOG_LOG](#zcorelog_log)
  - [ZCORELOG_FORMAT (Opsiyonel)](#zcorelog_format-opsiyonel)
- [Kullanım](#kullanım)
  - [Basit Örnek](#basit-örnek)
  - [Senkron / Asenkron](#senkron--asenkron)
  - [Tablo Bazlı Özel Hedef](#tablo-bazlı-özel-hedef)
  - [Modül Bazlı Log Seviyesi](#modül-bazlı-log-seviyesi)
  - [Meta Data Ekleme](#meta-data-ekleme)
- [Mermaid ile Sınıf Diyagramı](#mermaid-ile-sınıf-diyagramı)
- [Katkıda Bulunma](#katkıda-bulunma)
- [Lisans](#lisans)

---

## Özellikler

- **Merkezi Yönetim**: Log seviyeleri, log hedefleri, asenkron/senkron mod ve benzeri ayarlar veritabanı tabloları (ZCORELOG_*) üzerinden yönetilir.  
- **Çoklu Hedef**: DB, API, FILE, FTP vb. hedeflere yazma imkânı. Aynı anda birden fazla hedef desteklenebilir.  
- **Senkron veya Asenkron**: Performans ihtiyacına göre anlık (INSERT) veya asenkron (buffer) loglamayı etkinleştirebilirsiniz.  
- **Modül/Tablo Bazlı**: Belirli ABAP program modülleri veya veri tabloları için özel log seviyeleri ve hedefler tanımlanabilir.  
- **Dependency Injection**: Varsayılan formatter ve target nesnelerini isteğe göre dışarıdan gönderip konfigüre edebilirsiniz.

---

## Kurulum & Ön Gereksinimler

1. **Sürüm**: Proje, ABAP 7.40+ (S/4HANA 1909 vb.) sürümleri için tasarlanmıştır.  
2. **Erişim Yetkileri**: Yeni veritabanı tabloları oluşturmak, global sınıf ve arayüz tanımlamak için gerekli yetkilere sahip olmalısınız.  
3. **Uygun paket/namespace**: İsteğe bağlı olarak kendi Z paketinizde veya bir yerel paket (TMP) içinde oluşturabilirsiniz.

**Adım Adım:**
1. **Tabloları Oluşturun**: ZCORELOG_CONFIG, ZCORELOG_TARGET, ZCORELOG_MODULE, ZCORELOG_LOG ve isteğe bağlı ZCORELOG_FORMAT tablolarını tanımlayın.  
2. **Arayüz ve Sınıfları** (ZIF_CORELOG_*, ZCL_CORELOG_*) SE80 veya Eclipse ortamında yükleyin.  
3. Gerekirse dummy verileri veya başlangıç kayıtlarını ekleyip test edin.

---

## Proje Mimarisi

### Tablolar

- **ZCORELOG_CONFIG**  
  Genel log ayarları (log_level, async_logging vb.).  
- **ZCORELOG_TARGET**  
  Hedef tanımları (DB, API, FILE vb.) ve ilgili alanlar.  
- **ZCORELOG_MODULE**  
  Belirli modüller (ABAP program/paket) için özel log seviyesi konfigürasyonu.  
- **ZCORELOG_LOG**  
  Log kayıtlarının (timestamp, log_level, message, data, meta_data) saklandığı tablo.  
- **ZCORELOG_FORMAT** *(Opsiyonel)*  
  Birden çok format tipini (JSON, XML vb.) aynı konfigürasyon altında yönetmek için.

### Arayüzler (Interfaces)

1. **ZIF_CORELOG_CONSTANTS**  
   - Log seviyeleri (DEBUG, INFO, WARNING, ERROR, FATAL) için sabitler.  
   - `CLASS-METHODS getLevelForString(iv_level_str : string) : i` metodu ile `'DEBUG'` → `10` dönüşümü yapılabilir (sürüm kısıtlarına göre `CLASS-METHODS` arayüzde kullanılabilir veya sabitler bir sınıfa taşınabilir).

2. **ZIF_CORELOG_FORMATTER**  
   - `format(io_log_entry : zcl_corelog_entry) : xstring` metodunu içerir.  
   - Log verisini JSON/XML vb. formata dönüştürerek xstring döndürür; GZIP sıkıştırma eklenebilir.

3. **ZIF_CORELOG_TARGET**  
   - `write(iv_data : xstring)` metodu, formatlanmış log verisini hedefe (DB, API, dosya vb.) yazar.

### Sınıflar

1. **ZCL_CORELOG_ENTRY**  
   - Tek bir log girdisini (level, message, data, timestamp, metaData vb.) temsil eder.

2. **ZCL_CORELOG_GZIP_FORMATTER** *(ZIF_CORELOG_FORMATTER implementasyonu)*  
   - Log girdisini JSON’a çevirir ve GZIP ile sıkıştırır.

3. **ZCL_CORELOG_DB_TARGET** *(ZIF_CORELOG_TARGET implementasyonu)*  
   - Log bilgisini ZCORELOG_LOG tablosuna `INSERT` yapar.

4. **ZCL_CORELOG_API_TARGET / ZCL_CORELOG_FTP_TARGET / ZCL_CORELOG_FILE_TARGET** *(opsiyonel)*  
   - DB dışında API, FTP veya dosya sistemine log göndermeye yarayan sınıflar.

5. **ZCL_CORELOG (Ana Logger)**  
   - Statik metotlar (`init`, `log`, `debug`, `info`, `error`, `fatal` vb.) içerir.  
   - Veritabanı konfigürasyonu okuyarak `_log_level`, `_async_mode`, `_targets` gibi ayarları yönetir.  
   - Log verilerini `_formatter` ile formatlayıp `_targets` listesindeki tüm hedeflere yazar.

---

## Konfigürasyon

### ZCORELOG_CONFIG

| Alan                 | Açıklama                                 |
|----------------------|------------------------------------------|
| `client (CLNT)`      | SAP client                               |
| `config_id (INT4)`   | Konfigürasyon kimliği                    |
| `active (BOOLEAN)`   | Bu konfigürasyon aktif mi?               |
| `log_level (CHAR(10))` | `'DEBUG'`, `'INFO'`, `'ERROR'` vb.     |
| `async_logging (BOOL)` | Asenkron loglama aktif mi?             |
| ...                  | Diğer alanlar (`log_rotation_size` vb.)  |

> **Öneri**: `log_level` metinsel (`DEBUG`, `INFO` vb.) saklanarak `getLevelForString` ile numeric değere dönüştürülebilir.

### ZCORELOG_TARGET

| Alan                 | Açıklama                                                    |
|----------------------|-------------------------------------------------------------|
| `client (CLNT)`      | SAP client                                                 |
| `target_id (INT4)`   | Hedef kimliği                                              |
| `config_id (INT4)`   | Bu hedef hangi konfigürasyona ait?                          |
| `target_type (CHAR(20))`  | 'DB', 'API', 'FTP', 'FILE' vb.                        |
| `source_table (CHAR(200))`| 'MARA', 'VBAK' vb. tabloya özel hedef isteniyorsa      |
| `target_active (BOOL)`    | Hedefin aktif/pasif durumu                             |
| ...                  | `destination`, `target_path`, `target_table` gibi alanlar   |

### ZCORELOG_MODULE

| Alan                    | Açıklama                                        |
|-------------------------|-------------------------------------------------|
| `client (CLNT)`         | SAP client                                     |
| `module_id (INT4)`      | Modül kimliği                                  |
| `module_name (CHAR(200))`| ABAP program/paket adı (örn. `SAPLZSD`)       |
| `module_level (CHAR(10))` | `'DEBUG'`, `'INFO'`, `'ERROR'`, vb.          |

### ZCORELOG_LOG

| Alan                | Açıklama                                         |
|---------------------|--------------------------------------------------|
| `log_id (INT4)`     | Log kaydı numarası                               |
| `timestamp (DEC(15))` | YYYYMMDDHHMMSS biçiminde saklanabilir          |
| `log_level (INT4)`  | Numeric seviye (10=DEBUG, 20=INFO vb.)           |
| `message (STRING)`  | Metinsel log mesajı                              |
| `data (RAWSTRING)`  | Formatlanmış/sıkıştırılmış veri                  |
| `meta_data (STRING)`| Ek bilgiler (JSON, key=value çiftleri vb.)       |
| ...                 | `username`, `tcode`, `tableName` vb.             |

### ZCORELOG_FORMAT (Opsiyonel)

| Alan                  | Açıklama                                |
|-----------------------|-----------------------------------------|
| `client (CLNT)`       | SAP client                              |
| `config_id (INT4)`    | ZCORELOG_CONFIG ile ilişkili ID          |
| `format_type (CHAR(20))` | `'JSON'`, `'XML'`, `'PLAIN'`, vb.     |

Bu tabloyu kullanarak “bir konfigürasyona ait çoklu format tiplerini” yönetebilirsiniz.

---

## Kullanım

### Basit Örnek

```abap
REPORT zcorelog_demo.

INITIALIZATION.
  " DB'den config_id=1'i okuyup ayarları uygula
  zcl_corelog=>init( iv_config_id = 1 ).

START-OF-SELECTION.
  zcl_corelog=>info( iv_message = 'Program başladı.' ).
  " ...
  zcl_corelog=>error( iv_message = 'Önemli hata oluştu' ).

END-OF-SELECTION.
  zcl_corelog=>flush( ). " Asenkron moddaysa buffer'ı boşalt


##Senkron / Asenkron
Senkron: Her zcl_corelog=>log(...) çağrısı anında hedeflere (DB, API vb.) yazar.
Asenkron: zcl_corelog=>enableAsyncLogging( ) ile aktif edilir. Bu modda loglar _log_buffer’da tutulur ve zcl_corelog=>flush( ) çağrısıyla hedeflere toplu aktarılır.
zcl_corelog=>init( iv_config_id = 1 ).
zcl_corelog=>enableAsyncLogging( ).

zcl_corelog=>debug( iv_message = 'Buffera giren debug log.' ).

" Program sonu
zcl_corelog=>flush( ).


##Tablo Bazlı Özel Hedef
ZCORELOG_TARGET’ta source_table = 'MARA' ve target_type = 'API' tanımladınız diyelim. zcl_corelog=>log(...) çağrısında:
zcl_corelog=>debug(
  iv_message = 'MARA kaydı güncelleniyor.'
  iv_table   = 'MARA'
).
ZCL_CORELOG otomatik olarak _getCustomTarget ile MARA kaydını bulur, API tipinde bir target (örn. ZCL_CORELOG_API_TARGET) yaratır.

Modül Bazlı Log Seviyesi
ZCORELOG_MODULE tablosunda module_name='SAPLZSD' ve module_level='ERROR' tanımı varsa, SAPLZSD programı çalışırken DEBUG veya INFO log çağrıları devre dışı kalabilir:
  
