*&---------------------------------------------------------------------*
*& Tablo: ZCORELOG_CONFIG
*& Açıklama: CoreLog konfigürasyon tablosu (minimal)
*&---------------------------------------------------------------------*

@EndUserText.label : 'CoreLog Konfigürasyon'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED

define table zcorelog_config {
  key client      : mandt not null;
  key config_name : char30 not null;
  @EndUserText.label : 'Log Seviyesi'
  log_level       : char10;
  @EndUserText.label : 'Aktif'
  is_active       : abap_boolean;
  @EndUserText.label : 'Oluşturan'
  created_by      : syuname;
  @EndUserText.label : 'Oluşturma Tarihi'
  created_at      : sydatum;
  @EndUserText.label : 'Değiştiren'
  changed_by      : syuname;
  @EndUserText.label : 'Değiştirme Tarihi'
  changed_at      : sydatum;
}
