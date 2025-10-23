*&---------------------------------------------------------------------*
*& Report: ZCORELOG_DASHBOARD
*& Açıklama: CoreLog Real-time Dashboard with SALV
*& Versiyon: 1.0
*&---------------------------------------------------------------------*

REPORT zcorelog_dashboard.

" Type tanımları
TYPES: BEGIN OF ty_log_summary,
         module_name  TYPE char30,
         log_level    TYPE char10,
         log_count    TYPE i,
         total_size   TYPE dec10_2,
         criticality  TYPE i,
         icon         TYPE icon_d,
       END OF ty_log_summary.

TYPES: BEGIN OF ty_kpi,
         label TYPE string,
         value TYPE string,
         color TYPE lvc_col,
       END OF ty_kpi.

" Data declarations
DATA: gt_logs         TYPE STANDARD TABLE OF zcorelog_log,
      gt_summary      TYPE STANDARD TABLE OF ty_log_summary,
      gt_kpis         TYPE STANDARD TABLE OF ty_kpi,
      go_alv          TYPE REF TO cl_salv_table,
      go_alv_summary  TYPE REF TO cl_salv_table.

" Selection screen
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE text-001.
  PARAMETERS: p_datefr TYPE sydatum DEFAULT sy-datum,
              p_dateto TYPE sydatum DEFAULT sy-datum.
  SELECT-OPTIONS: s_module FOR zcorelog_log-module_name,
                  s_level  FOR zcorelog_log-log_level,
                  s_prog   FOR zcorelog_log-program,
                  s_user   FOR zcorelog_log-username.
SELECTION-SCREEN END OF BLOCK b1.

SELECTION-SCREEN BEGIN OF BLOCK b2 WITH FRAME TITLE text-002.
  PARAMETERS: p_detail RADIOBUTTON GROUP rg1 DEFAULT 'X',
              p_summar RADIOBUTTON GROUP rg1,
              p_kpi    RADIOBUTTON GROUP rg1.
SELECTION-SCREEN END OF BLOCK b2.

*&---------------------------------------------------------------------*
*& Initialization
*&---------------------------------------------------------------------*
INITIALIZATION.
  " Default date range: Son 7 gün
  p_datefr = sy-datum - 7.
  p_dateto = sy-datum.

  " Text elements
  text-001 = 'Filtreleme Kriterleri'.
  text-002 = 'Görünüm Seçimi'.

*&---------------------------------------------------------------------*
*& Start of Selection
*&---------------------------------------------------------------------*
START-OF-SELECTION.

  " Veri oku
  PERFORM get_log_data.

  " Görünüm seç
  CASE abap_true.
    WHEN p_detail.
      PERFORM display_detail_view.
    WHEN p_summar.
      PERFORM display_summary_view.
    WHEN p_kpi.
      PERFORM display_kpi_view.
  ENDCASE.

*&---------------------------------------------------------------------*
*& Form: get_log_data
*&---------------------------------------------------------------------*
FORM get_log_data.

  DATA: lv_datefr_ts TYPE dec15,
        lv_dateto_ts TYPE dec15.

  " Timestamp aralığı hesapla
  lv_datefr_ts = p_datefr && '000000'.
  lv_dateto_ts = p_dateto && '235959'.

  " Ana veriyi oku
  SELECT *
    FROM zcorelog_log
    INTO TABLE @gt_logs
    WHERE timestamp BETWEEN @lv_datefr_ts AND @lv_dateto_ts
      AND module_name IN @s_module
      AND log_level   IN @s_level
      AND program     IN @s_prog
      AND username    IN @s_user
    ORDER BY timestamp DESCENDING.

  IF sy-subrc <> 0.
    MESSAGE 'Seçili kriterlere uygun log bulunamadı' TYPE 'I'.
    LEAVE LIST-PROCESSING.
  ENDIF.

  " Özet veri hazırla
  PERFORM prepare_summary_data.

  " KPI verileri hazırla
  PERFORM prepare_kpi_data.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form: prepare_summary_data
*&---------------------------------------------------------------------*
FORM prepare_summary_data.

  DATA: lt_temp TYPE SORTED TABLE OF ty_log_summary WITH NON-UNIQUE KEY module_name log_level.

  " Modül ve level bazında group by
  LOOP AT gt_logs INTO DATA(ls_log).
    READ TABLE lt_temp
      WITH KEY module_name = ls_log-module_name
               log_level   = ls_log-log_level
      TRANSPORTING NO FIELDS.

    IF sy-subrc = 0.
      DATA(lv_tabix) = sy-tabix.
      lt_temp[ lv_tabix ]-log_count   = lt_temp[ lv_tabix ]-log_count + 1.
      lt_temp[ lv_tabix ]-total_size  = lt_temp[ lv_tabix ]-total_size + ls_log-data_size_kb.
    ELSE.
      DATA(ls_summary) = VALUE ty_log_summary(
        module_name = ls_log-module_name
        log_level   = ls_log-log_level
        log_count   = 1
        total_size  = ls_log-data_size_kb
      ).

      " Criticality ve icon
      CASE ls_log-log_level.
        WHEN 'DEBUG' OR 'INFO'.
          ls_summary-criticality = 0.
          ls_summary-icon = icon_led_green.
        WHEN 'WARNING'.
          ls_summary-criticality = 2.
          ls_summary-icon = icon_led_yellow.
        WHEN 'ERROR' OR 'FATAL'.
          ls_summary-criticality = 1.
          ls_summary-icon = icon_led_red.
      ENDCASE.

      INSERT ls_summary INTO TABLE lt_temp.
    ENDIF.
  ENDLOOP.

  gt_summary = lt_temp.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form: prepare_kpi_data
*&---------------------------------------------------------------------*
FORM prepare_kpi_data.

  DATA: lv_total_logs  TYPE i,
        lv_error_count TYPE i,
        lv_warn_count  TYPE i,
        lv_total_size  TYPE dec10_2,
        lv_avg_size    TYPE dec10_2.

  " KPI hesapları
  lv_total_logs = lines( gt_logs ).

  LOOP AT gt_logs INTO DATA(ls_log).
    CASE ls_log-log_level.
      WHEN 'ERROR' OR 'FATAL'.
        lv_error_count = lv_error_count + 1.
      WHEN 'WARNING'.
        lv_warn_count = lv_warn_count + 1.
    ENDCASE.
    lv_total_size = lv_total_size + ls_log-data_size_kb.
  ENDLOOP.

  IF lv_total_logs > 0.
    lv_avg_size = lv_total_size / lv_total_logs.
  ENDIF.

  " KPI listesi oluştur
  gt_kpis = VALUE #(
    ( label = 'Toplam Log Sayısı'  value = |{ lv_total_logs }|     color = 'C300' )
    ( label = 'Hata Sayısı'        value = |{ lv_error_count }|    color = 'C610' )
    ( label = 'Uyarı Sayısı'       value = |{ lv_warn_count }|     color = 'C310' )
    ( label = 'Toplam Boyut (KB)'  value = |{ lv_total_size }|     color = 'C500' )
    ( label = 'Ortalama Boyut (KB)' value = |{ lv_avg_size }|      color = 'C500' )
    ( label = 'Modül Sayısı'       value = |{ lines( gt_summary ) }| color = 'C300' )
  ).

ENDFORM.

*&---------------------------------------------------------------------*
*& Form: display_detail_view
*&---------------------------------------------------------------------*
FORM display_detail_view.

  TRY.
      " SALV oluştur
      cl_salv_table=>factory(
        IMPORTING
          r_salv_table = go_alv
        CHANGING
          t_table = gt_logs
      ).

      " Fonksiyonlar
      DATA(lo_functions) = go_alv->get_functions( ).
      lo_functions->set_all( abap_true ).

      " Kolonlar
      DATA(lo_columns) = go_alv->get_columns( ).
      lo_columns->set_optimize( abap_true ).

      " Özel kolon ayarları
      TRY.
          DATA(lo_column) = lo_columns->get_column( 'LOG_LEVEL' ).
          lo_column->set_short_text( 'Level' ).
          lo_column->set_medium_text( 'Log Level' ).
          lo_column->set_long_text( 'Log Level' ).

          lo_column = lo_columns->get_column( 'MODULE_NAME' ).
          lo_column->set_short_text( 'Module' ).
          lo_column->set_medium_text( 'Module Name' ).

          lo_column = lo_columns->get_column( 'DATA_SIZE_KB' ).
          lo_column->set_short_text( 'Size KB' ).
          lo_column->set_medium_text( 'Data Size (KB)' ).

        CATCH cx_salv_not_found.
      ENDTRY.

      " Display settings
      DATA(lo_display) = go_alv->get_display_settings( ).
      lo_display->set_striped_pattern( abap_true ).
      lo_display->set_list_header( |CoreLog Dashboard - Detaylı Görünüm ({ lines( gt_logs ) } kayıt)| ).

      " Göster
      go_alv->display( ).

    CATCH cx_salv_msg INTO DATA(lx_error).
      MESSAGE lx_error->get_text( ) TYPE 'E'.
  ENDTRY.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form: display_summary_view
*&---------------------------------------------------------------------*
FORM display_summary_view.

  TRY.
      " SALV oluştur
      cl_salv_table=>factory(
        IMPORTING
          r_salv_table = go_alv_summary
        CHANGING
          t_table = gt_summary
      ).

      " Fonksiyonlar
      DATA(lo_functions) = go_alv_summary->get_functions( ).
      lo_functions->set_all( abap_true ).

      " Kolonlar
      DATA(lo_columns) = go_alv_summary->get_columns( ).
      lo_columns->set_optimize( abap_true ).

      " Kolon başlıkları
      TRY.
          DATA(lo_column) = lo_columns->get_column( 'MODULE_NAME' ).
          lo_column->set_long_text( 'Modül Adı' ).

          lo_column = lo_columns->get_column( 'LOG_LEVEL' ).
          lo_column->set_long_text( 'Log Seviyesi' ).

          lo_column = lo_columns->get_column( 'LOG_COUNT' ).
          lo_column->set_long_text( 'Log Sayısı' ).

          lo_column = lo_columns->get_column( 'TOTAL_SIZE' ).
          lo_column->set_long_text( 'Toplam Boyut (KB)' ).

          lo_column = lo_columns->get_column( 'ICON' ).
          lo_column->set_icon( abap_true ).

        CATCH cx_salv_not_found.
      ENDTRY.

      " Aggregations
      DATA(lo_aggregations) = go_alv_summary->get_aggregations( ).
      TRY.
          lo_aggregations->add_aggregation(
            columnname  = 'LOG_COUNT'
            aggregation = if_salv_c_aggregation=>total
          ).
          lo_aggregations->add_aggregation(
            columnname  = 'TOTAL_SIZE'
            aggregation = if_salv_c_aggregation=>total
          ).
        CATCH cx_salv_data_error.
      ENDTRY.

      " Display settings
      DATA(lo_display) = go_alv_summary->get_display_settings( ).
      lo_display->set_striped_pattern( abap_true ).
      lo_display->set_list_header( |CoreLog Dashboard - Özet Görünüm (Modül/Level)| ).

      " Göster
      go_alv_summary->display( ).

    CATCH cx_salv_msg INTO DATA(lx_error).
      MESSAGE lx_error->get_text( ) TYPE 'E'.
  ENDTRY.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form: display_kpi_view
*&---------------------------------------------------------------------*
FORM display_kpi_view.

  " KPI'ları ekrana yazdır
  WRITE: / '═══════════════════════════════════════════════════',
         / 'CoreLog Dashboard - KPI Görünümü',
         / '═══════════════════════════════════════════════════',
         /.

  LOOP AT gt_kpis INTO DATA(ls_kpi).
    WRITE: / ls_kpi-label, ': ', ls_kpi-value COLOR COL_HEADING.
  ENDLOOP.

  WRITE: /,
         / '═══════════════════════════════════════════════════',
         / 'Modül Bazlı Dağılım:',
         / '═══════════════════════════════════════════════════',
         /.

  " Modül bazlı özet
  LOOP AT gt_summary INTO DATA(ls_summary).
    WRITE: / icon_led_green AS ICON,
           ls_summary-module_name,
           '-',
           ls_summary-log_level,
           ':',
           ls_summary-log_count,
           'logs (',
           ls_summary-total_size,
           'KB )'.

    " Renklendirme
    CASE ls_summary-log_level.
      WHEN 'ERROR' OR 'FATAL'.
        FORMAT COLOR COL_NEGATIVE.
      WHEN 'WARNING'.
        FORMAT COLOR COL_TOTAL.
      WHEN OTHERS.
        FORMAT COLOR COL_NORMAL.
    ENDCASE.
  ENDLOOP.

  FORMAT RESET.

  WRITE: /,
         / '═══════════════════════════════════════════════════',
         / 'F3 ile çıkış yapabilirsiniz.',
         / '═══════════════════════════════════════════════════'.

ENDFORM.
