@AbapCatalog.sqlViewName: 'ZCLOGTIMESERIES'
@AbapCatalog.compiler.compareFilter: true
@AbapCatalog.preserveKey: true
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'CoreLog Time Series - Hourly Aggregation'

@Analytics.dataCategory: #CUBE
@VDM.viewType: #CONSUMPTION

define view Z_CORELOG_TIME_SERIES
  as select from zcorelog_log
{
      @EndUserText.label: 'Client'
  key client,

      @EndUserText.label: 'Date'
      @Semantics.businessDate.at: true
  key cast( substring( timestamp, 1, 8 ) as abap.dats ) as log_date,

      @EndUserText.label: 'Hour'
  key substring( timestamp, 9, 2 ) as log_hour,

      @EndUserText.label: 'Log Level'
  key log_level,

      @EndUserText.label: 'Module Name'
  key module_name,

      // Time-based aggregations
      @EndUserText.label: 'Total Logs'
      @DefaultAggregation: #SUM
      count(*) as log_count,

      @EndUserText.label: 'Total Size (KB)'
      @DefaultAggregation: #SUM
      @Semantics.quantity.unitOfMeasure: 'size_unit'
      sum( data_size_kb ) as total_size,

      @EndUserText.label: 'Average Size (KB)'
      @DefaultAggregation: #AVG
      @Semantics.quantity.unitOfMeasure: 'size_unit'
      avg( data_size_kb as abap.dec(10,2) ) as avg_size,

      @EndUserText.label: 'Unit'
      cast( 'KB' as abap.char( 3 ) ) as size_unit,

      // Error indicators
      @EndUserText.label: 'Error Count'
      @DefaultAggregation: #SUM
      count( case when log_level = 'ERROR' or log_level = 'FATAL' then 1 end ) as error_count,

      @EndUserText.label: 'Warning Count'
      @DefaultAggregation: #SUM
      count( case when log_level = 'WARNING' then 1 end ) as warning_count,

      // Trend calculation
      @EndUserText.label: 'DateTime (Sortable)'
      concat( cast( substring( timestamp, 1, 8 ) as abap.char(8) ),
              substring( timestamp, 9, 2 ) ) as datetime_sort,

      // Criticality
      @EndUserText.label: 'Criticality'
      case
        when count( case when log_level = 'ERROR' or log_level = 'FATAL' then 1 end ) > 10 then 1
        when count( case when log_level = 'WARNING' then 1 end ) > 50 then 2
        else 0
      end as criticality

}
group by
  client,
  cast( substring( timestamp, 1, 8 ) as abap.dats ),
  substring( timestamp, 9, 2 ),
  log_level,
  module_name
