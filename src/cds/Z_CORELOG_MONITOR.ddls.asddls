@AbapCatalog.sqlViewName: 'ZCLOGMONITOR'
@AbapCatalog.compiler.compareFilter: true
@AbapCatalog.preserveKey: true
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'CoreLog Monitor - Real-time Log View'

@Analytics.dataCategory: #FACT
@VDM.viewType: #CONSUMPTION

define view Z_CORELOG_MONITOR
  as select from zcorelog_log
{
      @EndUserText.label: 'Client'
  key client,

      @EndUserText.label: 'Log ID'
  key log_id,

      @EndUserText.label: 'Timestamp'
      @Semantics.businessDate.at: true
      cast( substring( timestamp, 1, 8 ) as abap.dats ) as log_date,

      @EndUserText.label: 'Time'
      cast( substring( timestamp, 9, 6 ) as abap.tims ) as log_time,

      @EndUserText.label: 'Full Timestamp'
      timestamp,

      @EndUserText.label: 'Log Level'
      @Consumption.filter.selectionType: #SINGLE
      @Consumption.valueHelpDefinition: [{ entity: { name: 'I_LogLevel', element: 'LogLevel' } }]
      log_level,

      @EndUserText.label: 'Message'
      @Semantics.text: true
      message,

      @EndUserText.label: 'Username'
      @Consumption.filter.selectionType: #INTERVAL
      username,

      @EndUserText.label: 'Program'
      @Consumption.filter.selectionType: #INTERVAL
      program,

      @EndUserText.label: 'T-Code'
      @Consumption.filter.selectionType: #INTERVAL
      tcode,

      @EndUserText.label: 'Details (JSON)'
      details,

      @EndUserText.label: 'Data Size (KB)'
      @Semantics.quantity.unitOfMeasure: 'size_unit'
      @DefaultAggregation: #SUM
      data_size_kb,

      @EndUserText.label: 'Unit'
      cast( 'KB' as abap.char( 3 ) ) as size_unit,

      @EndUserText.label: 'Module Name'
      @Consumption.filter.selectionType: #SINGLE
      @Consumption.filter.mandatory: false
      module_name,

      @EndUserText.label: 'Sub Module'
      @Consumption.filter.selectionType: #SINGLE
      sub_module,

      // Calculated fields
      @EndUserText.label: 'Is Error'
      case log_level
        when 'ERROR' then 'X'
        when 'FATAL' then 'X'
        else ''
      end as is_error,

      @EndUserText.label: 'Criticality'
      case log_level
        when 'DEBUG'   then 0  // Neutral
        when 'INFO'    then 0  // Neutral
        when 'WARNING' then 2  // Critical
        when 'ERROR'   then 1  // Negative
        when 'FATAL'   then 1  // Negative
        else 0
      end as criticality,

      @EndUserText.label: 'Has Large Data'
      case
        when data_size_kb > 100 then 'X'
        else ''
      end as has_large_data
}
where
  log_level is not null
