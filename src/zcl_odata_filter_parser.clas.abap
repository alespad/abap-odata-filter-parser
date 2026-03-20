"! OData $filter to ABAP Select Options Parser
"!
"! Parses OData V2 and V4 $filter strings and converts them
"! to ABAP range tables (select options).
"!
"! Supports:
"!   V2: eq, ne, gt, ge, lt, le, and, or, not, parentheses
"!   V4: contains(), startswith(), endswith(), in operator, tolower(), toupper()
"!
"! Quick usage - static method:
"!   DATA(lt_selopts) = zcl_odata_filter_parser=>parse_to_select_options(
"!     iv_filter  = |Plant eq '1000' and contains(Material,'MAT')|
"!     iv_version = zcl_odata_filter_parser=>gc_version-v4 ).
"!
"! Get range for specific field:
"!   DATA(lt_range) = zcl_odata_filter_parser=>get_range_for_field(
"!     iv_filter  = lv_filter_string
"!     iv_field   = 'Plant'
"!     iv_version = zcl_odata_filter_parser=>gc_version-v4 ).
"!
"! Instance usage for multiple operations on same filter:
"!   DATA(lo_parser) = NEW zcl_odata_filter_parser(
"!     iv_filter  = lv_filter_string
"!     iv_version = zcl_odata_filter_parser=>gc_version-v4 ).
"!   DATA(lt_all)    = lo_parser->get_select_options( ).
"!   DATA(lt_plant)  = lo_parser->get_range( 'Plant' ).
"!   DATA(lt_matnr)  = lo_parser->get_range( 'Material' ).
CLASS zcl_odata_filter_parser DEFINITION
  PUBLIC FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    " OData version constants
    CONSTANTS:
      BEGIN OF gc_version,
        v2 TYPE i VALUE 2,
        v4 TYPE i VALUE 4,
      END OF gc_version.

    " Token type constants (internal)
    CONSTANTS:
      BEGIN OF gc_token_type,
        field       TYPE string VALUE 'FIELD',
        operator    TYPE string VALUE 'OPERATOR',
        value       TYPE string VALUE 'VALUE',
        logical     TYPE string VALUE 'LOGICAL',
        paren_open  TYPE string VALUE 'PAREN_OPEN',
        paren_close TYPE string VALUE 'PAREN_CLOSE',
        func_call   TYPE string VALUE 'FUNC_CALL',
        negation    TYPE string VALUE 'NOT',
        comma       TYPE string VALUE 'COMMA',
        in_list     TYPE string VALUE 'IN_LIST',
      END OF gc_token_type.

    " Single parsed condition
    TYPES:
      BEGIN OF ty_condition,
        fieldname TYPE string,
        sign      TYPE ddsign,
        option    TYPE ddoption,
        low       TYPE string,
        high      TYPE string,
      END OF ty_condition,
      tt_conditions TYPE STANDARD TABLE OF ty_condition WITH EMPTY KEY.

    " Range entry compatible with standard select options
    TYPES:
      BEGIN OF ty_range_entry,
        sign   TYPE ddsign,
        option TYPE ddoption,
        low    TYPE string,
        high   TYPE string,
      END OF ty_range_entry,
      tt_range TYPE STANDARD TABLE OF ty_range_entry WITH EMPTY KEY.

    " Select option grouped by property
    TYPES:
      BEGIN OF ty_select_option,
        property       TYPE string,
        select_options TYPE tt_range,
      END OF ty_select_option,
      tt_select_options TYPE STANDARD TABLE OF ty_select_option WITH EMPTY KEY.

    " Token structure (internal)
    TYPES:
      BEGIN OF ty_token,
        type  TYPE string,
        value TYPE string,
      END OF ty_token,
      tt_tokens TYPE STANDARD TABLE OF ty_token WITH EMPTY KEY.

    "! Constructor
    "! @parameter iv_filter  | OData $filter string
    "! @parameter iv_version | OData version - use gc_version-v2 or gc_version-v4
    METHODS constructor
      IMPORTING iv_filter  TYPE string
                iv_version TYPE i DEFAULT gc_version-v4.

    "! Get all select options grouped by field name
    "! @parameter rt_result | Select options table
    METHODS get_select_options
      RETURNING VALUE(rt_result) TYPE tt_select_options
      RAISING   cx_sy_move_cast_error.

    "! Get range for a specific field
    "! @parameter iv_field  | Field name (case-sensitive, as in CDS)
    "! @parameter rt_range  | Range table for the field
    METHODS get_range
      IMPORTING iv_field        TYPE string
      RETURNING VALUE(rt_range) TYPE tt_range.

    "! Get all parsed conditions as flat list
    "! @parameter rt_conditions | All conditions
    METHODS get_conditions
      RETURNING VALUE(rt_conditions) TYPE tt_conditions.

    "! Static: parse and return select options
    "! @parameter iv_filter  | OData $filter string
    "! @parameter iv_version | OData version
    "! @parameter rt_result  | Select options table
    CLASS-METHODS parse_to_select_options
      IMPORTING iv_filter        TYPE string
                iv_version       TYPE i DEFAULT gc_version-v4
      RETURNING VALUE(rt_result) TYPE tt_select_options.

    "! Static: get range for one field
    "! @parameter iv_filter  | OData $filter string
    "! @parameter iv_field   | Field name
    "! @parameter iv_version | OData version
    "! @parameter rt_range   | Range table
    CLASS-METHODS get_range_for_field
      IMPORTING iv_filter       TYPE string
                iv_field        TYPE string
                iv_version      TYPE i DEFAULT gc_version-v4
      RETURNING VALUE(rt_range) TYPE tt_range.

  PRIVATE SECTION.

    DATA mv_filter     TYPE string.
    DATA mv_version    TYPE i.
    DATA mt_tokens     TYPE tt_tokens.
    DATA mt_conditions TYPE tt_conditions.
    DATA mv_parsed     TYPE abap_bool.
    DATA mv_position   TYPE i.

    METHODS tokenize.

    METHODS parse_expression
      IMPORTING iv_negate TYPE abap_bool DEFAULT abap_false.

    METHODS parse_condition
      IMPORTING iv_negate TYPE abap_bool DEFAULT abap_false.

    METHODS parse_function
      IMPORTING iv_func_name TYPE string
                iv_negate    TYPE abap_bool DEFAULT abap_false.

    METHODS parse_in_list
      IMPORTING iv_field  TYPE string
                iv_negate TYPE abap_bool DEFAULT abap_false.

    METHODS ensure_parsed.

    METHODS current_token
      RETURNING VALUE(rs_token) TYPE ty_token.

    METHODS peek_token
      IMPORTING iv_offset       TYPE i DEFAULT 1
      RETURNING VALUE(rs_token) TYPE ty_token.

    METHODS advance.

    METHODS has_more_tokens
      RETURNING VALUE(rv_result) TYPE abap_bool.

    CLASS-METHODS strip_quotes
      IMPORTING iv_value         TYPE string
      RETURNING VALUE(rv_result) TYPE string.

    CLASS-METHODS is_v4_function
      IMPORTING iv_name          TYPE string
      RETURNING VALUE(rv_result) TYPE abap_bool.

    CLASS-METHODS is_comparison_operator
      IMPORTING iv_value         TYPE string
      RETURNING VALUE(rv_result) TYPE abap_bool.

    CLASS-METHODS is_logical_operator
      IMPORTING iv_value         TYPE string
      RETURNING VALUE(rv_result) TYPE abap_bool.

ENDCLASS.



CLASS ZCL_ODATA_FILTER_PARSER IMPLEMENTATION.


  METHOD advance.
    mv_position = mv_position + 1.
  ENDMETHOD.


  METHOD constructor.
    mv_filter   = iv_filter.
    mv_version  = iv_version.
    mv_parsed   = abap_false.
    mv_position = 0.
  ENDMETHOD.


  METHOD current_token.
    IF mv_position < lines( mt_tokens ).
      rs_token = mt_tokens[ mv_position + 1 ].
    ENDIF.
  ENDMETHOD.


  METHOD ensure_parsed.
    IF mv_parsed = abap_true. RETURN. ENDIF.
    CLEAR mt_conditions.
    mv_position = 0.
    IF mv_filter IS INITIAL.
      mv_parsed = abap_true.
      RETURN.
    ENDIF.
    tokenize( ).
    mv_position = 0.
    parse_expression( ).
    mv_parsed = abap_true.
  ENDMETHOD.


  METHOD get_conditions.
    ensure_parsed( ).
    rt_conditions = mt_conditions.
  ENDMETHOD.


  METHOD get_range.
    ensure_parsed( ).
    LOOP AT mt_conditions INTO DATA(ls_cond)
      WHERE fieldname = iv_field.
      APPEND VALUE #( sign   = ls_cond-sign
                      option = ls_cond-option
                      low    = ls_cond-low
                      high   = ls_cond-high ) TO rt_range.
    ENDLOOP.
  ENDMETHOD.


  METHOD get_range_for_field.
    DATA(lo_parser) = NEW zcl_odata_filter_parser(
      iv_filter  = iv_filter
      iv_version = iv_version ).
    rt_range = lo_parser->get_range( iv_field ).
  ENDMETHOD.


  METHOD get_select_options.
    ensure_parsed( ).
    DATA ls_selopt TYPE ty_select_option.
    DATA ls_range  TYPE ty_range_entry.
    LOOP AT mt_conditions INTO DATA(ls_cond).
      READ TABLE rt_result ASSIGNING FIELD-SYMBOL(<ls_so>)
        WITH KEY property = ls_cond-fieldname.
      IF sy-subrc <> 0.
        ls_selopt-property = ls_cond-fieldname.
        CLEAR ls_selopt-select_options.
        APPEND ls_selopt TO rt_result.
        READ TABLE rt_result ASSIGNING <ls_so>
          WITH KEY property = ls_cond-fieldname.
      ENDIF.
      ls_range-sign   = ls_cond-sign.
      ls_range-option = ls_cond-option.
      ls_range-low    = ls_cond-low.
      ls_range-high   = ls_cond-high.
      APPEND ls_range TO <ls_so>-select_options.
    ENDLOOP.
  ENDMETHOD.


  METHOD has_more_tokens.
    rv_result = xsdbool( mv_position < lines( mt_tokens ) ).
  ENDMETHOD.


  METHOD is_comparison_operator.
    CASE iv_value.
      WHEN 'EQ' OR 'NE' OR 'GT' OR 'GE' OR 'LT' OR 'LE'.
        rv_result = abap_true.
      WHEN OTHERS.
        rv_result = abap_false.
    ENDCASE.
  ENDMETHOD.


  METHOD is_logical_operator.
    CASE iv_value.
      WHEN 'AND' OR 'OR'.
        rv_result = abap_true.
      WHEN OTHERS.
        rv_result = abap_false.
    ENDCASE.
  ENDMETHOD.


  METHOD is_v4_function.
    CASE iv_name.
      WHEN 'CONTAINS' OR 'STARTSWITH' OR 'ENDSWITH'
        OR 'TOLOWER' OR 'TOUPPER'
        OR 'TRIM' OR 'LENGTH' OR 'INDEXOF' OR 'SUBSTRING'
        OR 'CONCAT'
        OR 'YEAR' OR 'MONTH' OR 'DAY' OR 'HOUR' OR 'MINUTE' OR 'SECOND'
        OR 'DATE' OR 'TIME'
        OR 'ROUND' OR 'FLOOR' OR 'CEILING'.
        rv_result = abap_true.
      WHEN OTHERS.
        rv_result = abap_false.
    ENDCASE.
  ENDMETHOD.


  METHOD parse_condition.
    DATA ls_cond   TYPE ty_condition.
    DATA lv_negate TYPE abap_bool.

    lv_negate = iv_negate.

    IF has_more_tokens( ) = abap_false. RETURN. ENDIF.
    DATA(ls_tok) = current_token( ).

    " Handle NOT
    IF ls_tok-type = gc_token_type-negation.
      IF lv_negate = abap_true.
        lv_negate = abap_false.
      ELSE.
        lv_negate = abap_true.
      ENDIF.
      advance( ).
      IF has_more_tokens( ) = abap_false. RETURN. ENDIF.
      ls_tok = current_token( ).
    ENDIF.

    " Parenthesized group
    IF ls_tok-type = gc_token_type-paren_open.
      advance( ).
      parse_expression( lv_negate ).
      IF has_more_tokens( ) = abap_true.
        IF current_token( )-type = gc_token_type-paren_close.
          advance( ).
        ENDIF.
      ENDIF.
      RETURN.
    ENDIF.

    " V4 function call
    IF ls_tok-type = gc_token_type-func_call.
      DATA(lv_func) = ls_tok-value.
      advance( ).
      IF has_more_tokens( ) = abap_true.
        IF current_token( )-type = gc_token_type-paren_open.
          advance( ).
        ENDIF.
      ENDIF.
      parse_function( iv_func_name = lv_func
                      iv_negate    = lv_negate ).
      RETURN.
    ENDIF.

    " Standard comparison: field operator value
    IF ls_tok-type = gc_token_type-field OR ls_tok-type = gc_token_type-value.
      DATA(lv_field) = ls_tok-value.
      advance( ).

      IF has_more_tokens( ) = abap_false. RETURN. ENDIF.
      ls_tok = current_token( ).

      " V4 'in' operator
      IF ls_tok-type = gc_token_type-in_list.
        advance( ).
        parse_in_list( iv_field  = lv_field
                       iv_negate = lv_negate ).
        RETURN.
      ENDIF.

      " Comparison operator
      IF ls_tok-type = gc_token_type-operator.
        DATA(lv_operator) = ls_tok-value.
        advance( ).

        IF has_more_tokens( ) = abap_false. RETURN. ENDIF.
        ls_tok = current_token( ).

        DATA(lv_value) = ls_tok-value.
        advance( ).

        ls_cond-fieldname = lv_field.
        ls_cond-low = strip_quotes( lv_value ).

        " Handle negation
        IF lv_negate = abap_true.
          ls_cond-sign = 'E'.
          CASE lv_operator.
            WHEN 'EQ'. ls_cond-option = 'EQ'.
            WHEN 'NE'. ls_cond-sign = 'I'. ls_cond-option = 'EQ'.
            WHEN 'GT'. ls_cond-sign = 'I'. ls_cond-option = 'LE'.
            WHEN 'GE'. ls_cond-sign = 'I'. ls_cond-option = 'LT'.
            WHEN 'LT'. ls_cond-sign = 'I'. ls_cond-option = 'GE'.
            WHEN 'LE'. ls_cond-sign = 'I'. ls_cond-option = 'GT'.
          ENDCASE.
        ELSE.
          ls_cond-sign = 'I'.
          CASE lv_operator.
            WHEN 'EQ'.
              IF ls_cond-low CA '*'.
                ls_cond-option = 'CP'.
              ELSE.
                ls_cond-option = 'EQ'.
              ENDIF.
            WHEN 'NE'.
              ls_cond-sign = 'E'.
              IF ls_cond-low CA '*'.
                ls_cond-option = 'CP'.
              ELSE.
                ls_cond-option = 'EQ'.
              ENDIF.
            WHEN OTHERS.
              ls_cond-option = lv_operator.
          ENDCASE.
        ENDIF.

        " V4 date format YYYY-MM-DD
        IF strlen( ls_cond-low ) = 10.
          IF ls_cond-low+4(1) = '-' AND ls_cond-low+7(1) = '-'.
            ls_cond-low = |{ ls_cond-low(4) }{ ls_cond-low+5(2) }{ ls_cond-low+8(2) }|.
          ENDIF.
        ENDIF.

        " V2 datetime / datetimeoffset format
        DATA(lv_low_upper) = to_upper( ls_cond-low ).
        DATA(lv_low_len) = strlen( lv_low_upper ).
        IF lv_low_len > 15.
          IF lv_low_upper(15) = 'DATETIMEOFFSET'''.
            DATA(lv_dt) = ls_cond-low+15.
            DATA(lv_dtlen) = strlen( lv_dt ) - 1.
            IF lv_dtlen > 0.
              lv_dt = lv_dt(lv_dtlen).
            ENDIF.
            REPLACE ALL OCCURRENCES OF '-' IN lv_dt WITH ''.
            REPLACE ALL OCCURRENCES OF 'T' IN lv_dt WITH ''.
            REPLACE ALL OCCURRENCES OF ':' IN lv_dt WITH ''.
            REPLACE ALL OCCURRENCES OF 'Z' IN lv_dt WITH ''.
            ls_cond-low = lv_dt.
          ELSEIF lv_low_upper(9) = 'DATETIME'''.
            lv_dt = ls_cond-low+9.
            lv_dtlen = strlen( lv_dt ) - 1.
            IF lv_dtlen > 0.
              lv_dt = lv_dt(lv_dtlen).
            ENDIF.
            REPLACE ALL OCCURRENCES OF '-' IN lv_dt WITH ''.
            REPLACE ALL OCCURRENCES OF 'T' IN lv_dt WITH ''.
            REPLACE ALL OCCURRENCES OF ':' IN lv_dt WITH ''.
            REPLACE ALL OCCURRENCES OF 'Z' IN lv_dt WITH ''.
            ls_cond-low = lv_dt.
          ENDIF.
        ELSEIF lv_low_len > 9.
          IF lv_low_upper(9) = 'DATETIME'''.
            lv_dt = ls_cond-low+9.
            lv_dtlen = strlen( lv_dt ) - 1.
            IF lv_dtlen > 0.
              lv_dt = lv_dt(lv_dtlen).
            ENDIF.
            REPLACE ALL OCCURRENCES OF '-' IN lv_dt WITH ''.
            REPLACE ALL OCCURRENCES OF 'T' IN lv_dt WITH ''.
            REPLACE ALL OCCURRENCES OF ':' IN lv_dt WITH ''.
            REPLACE ALL OCCURRENCES OF 'Z' IN lv_dt WITH ''.
            ls_cond-low = lv_dt.
          ENDIF.
        ENDIF.

        APPEND ls_cond TO mt_conditions.
      ENDIF.
    ENDIF.
  ENDMETHOD.


  METHOD parse_expression.
    parse_condition( iv_negate ).
    WHILE has_more_tokens( ) = abap_true.
      DATA(ls_tok) = current_token( ).
      IF ls_tok-type <> gc_token_type-logical.
        EXIT.
      ENDIF.
      advance( ).
      parse_condition( iv_negate ).
    ENDWHILE.
  ENDMETHOD.


  METHOD parse_function.
    DATA ls_cond TYPE ty_condition.

    IF has_more_tokens( ) = abap_false. RETURN. ENDIF.

    DATA(ls_tok) = current_token( ).
    DATA(lv_field) = ls_tok-value.
    advance( ).

    IF has_more_tokens( ) = abap_true.
      IF current_token( )-type = gc_token_type-comma.
        advance( ).
      ENDIF.
    ENDIF.

    IF has_more_tokens( ) = abap_false. RETURN. ENDIF.
    ls_tok = current_token( ).
    DATA(lv_value) = strip_quotes( ls_tok-value ).
    advance( ).

    IF has_more_tokens( ) = abap_true.
      IF current_token( )-type = gc_token_type-paren_close.
        advance( ).
      ENDIF.
    ENDIF.

    " Check for 'eq true/false' after function
    DATA(lv_effective_negate) = iv_negate.
    IF has_more_tokens( ) = abap_true.
      ls_tok = current_token( ).
      IF ls_tok-type = gc_token_type-operator AND ls_tok-value = 'EQ'.
        advance( ).
        IF has_more_tokens( ) = abap_true.
          DATA(lv_bool_val) = to_upper( current_token( )-value ).
          IF lv_bool_val = 'FALSE'.
            IF iv_negate = abap_true.
              lv_effective_negate = abap_false.
            ELSE.
              lv_effective_negate = abap_true.
            ENDIF.
          ENDIF.
          advance( ).
        ENDIF.
      ENDIF.
    ENDIF.

    ls_cond-fieldname = lv_field.
    IF lv_effective_negate = abap_true.
      ls_cond-sign = 'E'.
    ELSE.
      ls_cond-sign = 'I'.
    ENDIF.

    CASE iv_func_name.
      WHEN 'CONTAINS'.
        ls_cond-option = 'CP'.
        ls_cond-low = |*{ lv_value }*|.
      WHEN 'STARTSWITH'.
        ls_cond-option = 'CP'.
        ls_cond-low = |{ lv_value }*|.
      WHEN 'ENDSWITH'.
        ls_cond-option = 'CP'.
        ls_cond-low = |*{ lv_value }|.
      WHEN 'TOLOWER' OR 'TOUPPER'.
        ls_cond-option = 'EQ'.
        ls_cond-low = lv_value.
      WHEN OTHERS.
        ls_cond-option = 'EQ'.
        ls_cond-low = lv_value.
    ENDCASE.

    APPEND ls_cond TO mt_conditions.
  ENDMETHOD.


  METHOD parse_in_list.
    DATA ls_cond TYPE ty_condition.

    IF has_more_tokens( ) = abap_true.
      IF current_token( )-type = gc_token_type-paren_open.
        advance( ).
      ENDIF.
    ENDIF.

    WHILE has_more_tokens( ) = abap_true.
      DATA(ls_tok) = current_token( ).

      IF ls_tok-type = gc_token_type-paren_close.
        advance( ).
        EXIT.
      ENDIF.

      IF ls_tok-type = gc_token_type-comma.
        advance( ).
        CONTINUE.
      ENDIF.

      ls_cond-fieldname = iv_field.
      ls_cond-low = strip_quotes( ls_tok-value ).

      IF iv_negate = abap_true.
        ls_cond-sign = 'E'.
      ELSE.
        ls_cond-sign = 'I'.
      ENDIF.

      IF ls_cond-low CA '*'.
        ls_cond-option = 'CP'.
      ELSE.
        ls_cond-option = 'EQ'.
      ENDIF.

      " Date format
      IF strlen( ls_cond-low ) = 10.
        IF ls_cond-low+4(1) = '-' AND ls_cond-low+7(1) = '-'.
          ls_cond-low = |{ ls_cond-low(4) }{ ls_cond-low+5(2) }{ ls_cond-low+8(2) }|.
        ENDIF.
      ENDIF.

      APPEND ls_cond TO mt_conditions.
      advance( ).
    ENDWHILE.
  ENDMETHOD.


  METHOD parse_to_select_options.
    DATA(lo_parser) = NEW zcl_odata_filter_parser(
      iv_filter  = iv_filter
      iv_version = iv_version ).
    rt_result = lo_parser->get_select_options( ).
  ENDMETHOD.


  METHOD peek_token.
    DATA(lv_peek) = mv_position + iv_offset.
    IF lv_peek < lines( mt_tokens ).
      rs_token = mt_tokens[ lv_peek + 1 ].
    ENDIF.
  ENDMETHOD.


  METHOD strip_quotes.
    rv_result = iv_value.
    DATA(lv_len) = strlen( rv_result ).
    IF lv_len >= 2.
      DATA(lv_last_pos) = lv_len - 1.
      IF rv_result(1) = '''' AND rv_result+lv_last_pos(1) = ''''.
        rv_result = rv_result+1.
        DATA(lv_inner_len) = strlen( rv_result ) - 1.
        IF lv_inner_len > 0.
          rv_result = rv_result(lv_inner_len).
        ELSE.
          CLEAR rv_result.
        ENDIF.
        REPLACE ALL OCCURRENCES OF '''''' IN rv_result WITH ''''.
      ENDIF.
    ENDIF.
  ENDMETHOD.


  METHOD tokenize.
    DATA lv_filter    TYPE string.
    DATA lv_len       TYPE i.
    DATA lv_pos       TYPE i.
    DATA lv_char      TYPE c LENGTH 1.
    DATA lv_buffer    TYPE string.
    DATA lv_in_string TYPE abap_bool.
    DATA ls_token     TYPE ty_token.

    lv_filter    = mv_filter.
    lv_len       = strlen( lv_filter ).
    lv_pos       = 0.
    lv_in_string = abap_false.
    CLEAR mt_tokens.

    WHILE lv_pos < lv_len.
      lv_char = lv_filter+lv_pos(1).

      " Inside string literal - collect until closing quote
      IF lv_in_string = abap_true.
        IF lv_char = ''''.
          DATA(lv_next_pos) = lv_pos + 1.
          IF lv_next_pos < lv_len.
            IF lv_filter+lv_next_pos(1) = ''''.
              lv_buffer = |{ lv_buffer }''|.
              lv_pos = lv_pos + 2.
              CONTINUE.
            ENDIF.
          ENDIF.
          lv_buffer = |{ lv_buffer }'|.
          lv_in_string = abap_false.
          ls_token-type  = gc_token_type-value.
          ls_token-value = lv_buffer.
          APPEND ls_token TO mt_tokens.
          CLEAR lv_buffer.
          lv_pos = lv_pos + 1.
          CONTINUE.
        ELSE.
          CONCATENATE lv_buffer lv_char INTO lv_buffer RESPECTING BLANKS.
          lv_pos = lv_pos + 1.
          CONTINUE.
        ENDIF.
      ENDIF.

      CASE lv_char.
        WHEN ''''.
          IF lv_buffer IS NOT INITIAL.
            " V2: datetime'...' and datetimeoffset'...' are single value tokens
            DATA(lv_buf_check) = to_upper( lv_buffer ).
            IF lv_buf_check = 'DATETIME' OR lv_buf_check = 'DATETIMEOFFSET'.
              " Keep buffer as prefix of string literal
              lv_buffer = |{ lv_buffer }'|.
              lv_in_string = abap_true.
            ELSE.
              ls_token-type  = gc_token_type-field.
              ls_token-value = lv_buffer.
              APPEND ls_token TO mt_tokens.
              CLEAR lv_buffer.
              lv_buffer    = |'|.
              lv_in_string = abap_true.
            ENDIF.
          ELSE.
            lv_buffer    = |'|.
            lv_in_string = abap_true.
          ENDIF.

        WHEN '('.
          IF lv_buffer IS NOT INITIAL.
            DATA(lv_buf_upper) = to_upper( lv_buffer ).
            IF mv_version >= gc_version-v4 AND is_v4_function( lv_buf_upper ).
              ls_token-type  = gc_token_type-func_call.
              ls_token-value = lv_buf_upper.
            ELSE.
              ls_token-type  = gc_token_type-field.
              ls_token-value = lv_buffer.
            ENDIF.
            APPEND ls_token TO mt_tokens.
            CLEAR lv_buffer.
          ENDIF.
          ls_token-type  = gc_token_type-paren_open.
          ls_token-value = '('.
          APPEND ls_token TO mt_tokens.

        WHEN ')'.
          IF lv_buffer IS NOT INITIAL.
            ls_token-type  = gc_token_type-value.
            ls_token-value = lv_buffer.
            APPEND ls_token TO mt_tokens.
            CLEAR lv_buffer.
          ENDIF.
          ls_token-type  = gc_token_type-paren_close.
          ls_token-value = ')'.
          APPEND ls_token TO mt_tokens.

        WHEN ','.
          IF lv_buffer IS NOT INITIAL.
            ls_token-type  = gc_token_type-value.
            ls_token-value = lv_buffer.
            APPEND ls_token TO mt_tokens.
            CLEAR lv_buffer.
          ENDIF.
          ls_token-type  = gc_token_type-comma.
          ls_token-value = ','.
          APPEND ls_token TO mt_tokens.

        WHEN space.
          IF lv_buffer IS NOT INITIAL.
            lv_buf_upper = to_upper( lv_buffer ).
            CASE lv_buf_upper.
              WHEN 'AND' OR 'OR'.
                ls_token-type  = gc_token_type-logical.
                ls_token-value = lv_buf_upper.
              WHEN 'NOT'.
                ls_token-type  = gc_token_type-negation.
                ls_token-value = 'NOT'.
              WHEN 'EQ' OR 'NE' OR 'GT' OR 'GE' OR 'LT' OR 'LE'.
                ls_token-type  = gc_token_type-operator.
                ls_token-value = lv_buf_upper.
              WHEN 'IN'.
                IF mv_version >= gc_version-v4.
                  ls_token-type  = gc_token_type-in_list.
                  ls_token-value = 'IN'.
                ELSE.
                  ls_token-type  = gc_token_type-field.
                  ls_token-value = lv_buffer.
                ENDIF.
              WHEN 'NULL' OR 'TRUE' OR 'FALSE'.
                ls_token-type  = gc_token_type-value.
                ls_token-value = lv_buf_upper.
              WHEN OTHERS.
                IF mv_version >= gc_version-v4 AND is_v4_function( lv_buf_upper ).
                  ls_token-type  = gc_token_type-func_call.
                  ls_token-value = lv_buf_upper.
                ELSE.
                  ls_token-type  = gc_token_type-field.
                  ls_token-value = lv_buffer.
                ENDIF.
            ENDCASE.
            APPEND ls_token TO mt_tokens.
            CLEAR lv_buffer.
          ENDIF.

        WHEN OTHERS.
          CONCATENATE lv_buffer lv_char INTO lv_buffer.
      ENDCASE.

      lv_pos = lv_pos + 1.
    ENDWHILE.

    IF lv_buffer IS NOT INITIAL.
      lv_buf_upper = to_upper( lv_buffer ).
      IF is_comparison_operator( lv_buf_upper ).
        ls_token-type  = gc_token_type-operator.
        ls_token-value = lv_buf_upper.
      ELSEIF is_logical_operator( lv_buf_upper ).
        ls_token-type  = gc_token_type-logical.
        ls_token-value = lv_buf_upper.
      ELSE.
        ls_token-type  = gc_token_type-value.
        ls_token-value = lv_buffer.
      ENDIF.
      APPEND ls_token TO mt_tokens.
    ENDIF.
  ENDMETHOD.
ENDCLASS.
