@AbapCatalog.sqlViewName: 'ZCLOGMODSTATS'
@AbapCatalog.compiler.compareFilter: true
@AbapCatalog.preserveKey: true
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'CoreLog Module Statistics - Aggregated'

@Analytics.dataCategory: #CUBE
@VDM.viewType: #CONSUMPTION

define view Z_CORELOG_MODULE_STATS
  as select from zcorelog_log
{
      @EndUserText.label: 'Client'
  key client,

      @EndUserText.label: 'Module Name'
  key module_name,

      @EndUserText.label: 'Log Level'
  key log_level,

      @EndUserText.label: 'Date'
  key cast( substring( timestamp, 1, 8 ) as abap.dats ) as log_date,

      // Aggregations
      @EndUserText.label: 'Total Logs'
      @DefaultAggregation: #SUM
      count(*) as total_logs,

      @EndUserText.label: 'Total Size (KB)'
      @DefaultAggregation: #SUM
      @Semantics.quantity.unitOfMeasure: 'size_unit'
      sum( data_size_kb ) as total_size_kb,

      @EndUserText.label: 'Average Size (KB)'
      @DefaultAggregation: #AVG
      @Semantics.quantity.unitOfMeasure: 'size_unit'
      avg( data_size_kb as abap.dec(10,2) ) as avg_size_kb,

      @EndUserText.label: 'Max Size (KB)'
      @DefaultAggregation: #MAX
      @Semantics.quantity.unitOfMeasure: 'size_unit'
      max( data_size_kb ) as max_size_kb,

      @EndUserText.label: 'Unit'
      cast( 'KB' as abap.char( 3 ) ) as size_unit,

      @EndUserText.label: 'Unique Users'
      @DefaultAggregation: #SUM
      count( distinct username ) as unique_users,

      @EndUserText.label: 'Unique Programs'
      @DefaultAggregation: #SUM
      count( distinct program ) as unique_programs,

      // Criticality for visualization
      @EndUserText.label: 'Criticality'
      case log_level
        when 'DEBUG'   then 0
        when 'INFO'    then 0
        when 'WARNING' then 2
        when 'ERROR'   then 1
        when 'FATAL'   then 1
        else 0
      end as criticality

}
where
  module_name is not null
group by
  client,
  module_name,
  log_level,
  cast( substring( timestamp, 1, 8 ) as abap.dats )
