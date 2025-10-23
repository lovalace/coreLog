# CoreLog Kurulum Kılavuzu

## Adım 1: Tabloları Oluştur (SE11)

### ZCORELOG_CONFIG Tablosu

1. Transaction: **SE11**
2. Tablo adı: `ZCORELOG_CONFIG`
3. Kısa açıklama: `CoreLog Konfigürasyon`
4. Delivery Class: `C` (Customizing table)
5. Alanlar:

| Alan | Key | Data Element | Tip | Uzunluk | Açıklama |
|------|-----|--------------|-----|---------|----------|
| MANDT | X | MANDT | CLNT | 3 | Client |
| CONFIG_NAME | X | CHAR30 | CHAR | 30 | Konfigürasyon Adı |
| LOG_LEVEL | | CHAR10 | CHAR | 10 | Log Seviyesi |
| IS_ACTIVE | | ABAP_BOOLEAN | CHAR | 1 | Aktif |
| CREATED_BY | | SYUNAME | CHAR | 12 | Oluşturan |
| CREATED_AT | | SYDATUM | DATS | 8 | Oluşturma Tarihi |
| CHANGED_BY | | SYUNAME | CHAR | 12 | Değiştiren |
| CHANGED_AT | | SYDATUM | DATS | 8 | Değiştirme Tarihi |

6. Aktivasyon: F3 (Aktif et)

### ZCORELOG_LOG Tablosu

1. Transaction: **SE11**
2. Tablo adı: `ZCORELOG_LOG`
3. Kısa açıklama: `CoreLog Kayıtları`
4. Delivery Class: `A` (Application table)
5. Alanlar:

| Alan | Key | Data Element | Tip | Uzunluk | Açıklama |
|------|-----|--------------|-----|---------|----------|
| MANDT | X | MANDT | CLNT | 3 | Client |
| LOG_ID | X | NUMC16 | NUMC | 16 | Log ID |
| TIMESTAMP | | DEC15 | DEC | 15,0 | Zaman Damgası |
| LOG_LEVEL | | CHAR10 | CHAR | 10 | Log Seviyesi |
| MESSAGE | | STRING | STRG | 0 | Mesaj |
| USERNAME | | SYUNAME | CHAR | 12 | Kullanıcı |
| PROGRAM | | SYREPID | CHAR | 40 | Program |
| TCODE | | SYTCODE | CHAR | 20 | Transaction Code |
| DETAILS | | STRING | STRG | 0 | Detaylar (JSON) |

6. Technical Settings (SE13):
   - Data Class: `APPL0` (Master data)
   - Size Category: `3` (büyük tablo, loglar zamanla artar)
   - Buffering: `Buffering not allowed`

7. Index önerisi (SE11 → Indexes):
   - Index adı: `ZCORELOG_LOG~001`
   - Alanlar: `TIMESTAMP`, `LOG_LEVEL`, `USERNAME`
   - Index türü: Non-unique

8. Aktivasyon: F3 (Aktif et)

---

## Adım 2: Sınıfı Oluştur (SE24 veya Eclipse)

### SE24 ile (SAP GUI)

1. Transaction: **SE24**
2. Sınıf adı: `ZCL_CORELOG`
3. Açıklama: `CoreLog - Basit Logger`
4. Özellikler:
   - Instantiation: `Public`
   - Final: `X` (işaretle)

5. Kaynak kodu: `src/classes/zcl_corelog.clas.abap` dosyasını kopyala-yapıştır

6. Aktivasyon: Ctrl+F3

### Eclipse (ABAP Development Tools) ile

1. Projeye sağ tık → New → ABAP Class
2. Name: `ZCL_CORELOG`
3. Description: `CoreLog - Basit Logger`
4. `src/classes/zcl_corelog.clas.abap` dosyasının içeriğini yapıştır
5. Ctrl+F3 ile aktif et

---

## Adım 3: İlk Konfigürasyonu Ekle (SE16N)

1. Transaction: **SE16N**
2. Tablo: `ZCORELOG_CONFIG`
3. "Create" butonuna tıkla (veya F5)
4. Değerleri gir:

```
CLIENT      : 100 (veya sisteminizdeki client)
CONFIG_NAME : DEFAULT
LOG_LEVEL   : INFO
IS_ACTIVE   : X
CREATED_BY  : <kullanıcı adınız>
CREATED_AT  : <bugünün tarihi>
```

5. Kaydet (Ctrl+S)

---

## Adım 4: Demo Programını Çalıştır (SE38)

1. Transaction: **SE38**
2. Program adı: `ZCORELOG_DEMO`
3. Create → Executable Program
4. `src/reports/zcorelog_demo.prog.abap` dosyasını kopyala-yapıştır
5. Aktivasyon: Ctrl+F3
6. Çalıştır: F8

**Sonuç:** Demo program çeşitli log örneklerini çalıştırır.

---

## Adım 5: Logları Kontrol Et (SE16)

1. Transaction: **SE16** veya **SE16N**
2. Tablo: `ZCORELOG_LOG`
3. Filtreler:
   - USERNAME = `<kullanıcı adınız>`
   - TIMESTAMP = `<bugün>`

4. Execute (F8)

**Görmelisiniz:**
- DEBUG, INFO, WARNING, ERROR, FATAL seviyelerinde loglar
- Timestamp bilgisi
- Program adı (ZCORELOG_DEMO)
- Detaylı mesajlar

---

## Adım 6: Test Programını Çalıştır (İsteğe Bağlı)

1. Transaction: **SE38**
2. Program adı: `ZCORELOG_TEST`
3. Create → Executable Program
4. `src/reports/zcorelog_test.prog.abap` dosyasını kopyala-yapıştır
5. Aktivasyon: Ctrl+F3
6. Çalıştır: F8

**Beklenen:** Tüm testlerin başarılı olması (✓ PASSED)

---

## Hızlı Kontrol Listesi

- [ ] ZCORELOG_CONFIG tablosu oluşturuldu ve aktif
- [ ] ZCORELOG_LOG tablosu oluşturuldu ve aktif
- [ ] ZCL_CORELOG sınıfı oluşturuldu ve aktif
- [ ] DEFAULT konfigürasyonu ZCORELOG_CONFIG'e eklendi
- [ ] ZCORELOG_DEMO programı çalıştırıldı
- [ ] ZCORELOG_LOG tablosunda loglar görüldü
- [ ] ZCORELOG_TEST programı başarılı geçti

---

## İlk Kullanım

Herhangi bir ABAP programınızda:

```abap
REPORT z_my_program.

START-OF-SELECTION.
  " Basit kullanım - konfigürasyon otomatik
  zcl_corelog=>info( 'Program başladı' ).

  " Detaylı log
  zcl_corelog=>error(
    iv_message = 'Bir hata oluştu'
    iv_details = '{"error_code": "E001"}'
  ).
```

**İşte bu kadar!** Logger kullanıma hazır.

---

## Sorun Giderme

### Problem: "ZCORELOG_CONFIG not found"
**Çözüm:** Adım 3'te konfigürasyon kaydı eklemeyi unutmadınız mı?

### Problem: "ZCORELOG_LOG tablosunda kayıt yok"
**Çözüm:**
- LOG_LEVEL kontrolü yapılıyor mu? DEBUG logları için LOG_LEVEL = 'DEBUG' olmalı
- IS_ACTIVE = 'X' mi?

### Problem: "Short dump - CX_SY_OPEN_SQL_DB"
**Çözüm:** Tablolar doğru aktivasyona sahip mi? SE14'ten activation/adjust et.

---

## Güvenlik Notları

1. **Yetkilendirme:**
   - ZCORELOG_LOG tablosuna sadece okuma yetkisi ver
   - Silme/değiştirme sadece sistem adminleri için

2. **Performans:**
   - Büyük sistemlerde LOG_LEVEL = 'ERROR' kullan
   - Periyodik temizleme job'ı kur:
     ```abap
     DELETE FROM zcorelog_log WHERE timestamp < sy-datum - 90.
     ```

3. **Sensitive Data:**
   - Kişisel bilgi (şifre, kredi kartı) loglama!
   - Gerekirse maskeleme ekle

---

## Sonraki Adımlar

1. Production ortamına taşıma (Transport Request)
2. Periyodik temizleme job'ı kurma
3. Log analiz raporları geliştirme
4. İhtiyaç halinde özel özellikler ekleme (API hedefi, GZIP vb.)

**Tebrikler!** CoreLog başarıyla kuruldu.
