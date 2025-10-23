*&---------------------------------------------------------------------*
*& Tablo: ZCORELOG_LOG
*& Açıklama: CoreLog kayıtlarının saklandığı ana tablo
*&---------------------------------------------------------------------*

@EndUserText.label : 'CoreLog Kayıtları'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #ALLOWED

define table zcorelog_log {
  key client    : mandt not null;
  key log_id    : numc16 not null;
  @EndUserText.label : 'Zaman Damgası'
  timestamp     : dec15;
  @EndUserText.label : 'Log Seviyesi'
  log_level     : char10;
  @EndUserText.label : 'Mesaj'
  message       : string(0);
  @EndUserText.label : 'Kullanıcı'
  username      : syuname;
  @EndUserText.label : 'Program'
  program       : syrepid;
  @EndUserText.label : 'T-Code'
  tcode         : sytcode;
  @EndUserText.label : 'Detaylar (JSON)'
  details       : string(0);
  @EndUserText.label : 'Veri Boyutu (KB)'
  data_size_kb  : dec10_2;
  @EndUserText.label : 'Modül Adı'
  module_name   : char30;
  @EndUserText.label : 'Alt Modül'
  sub_module    : char30;
}
