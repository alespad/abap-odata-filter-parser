"! Unit tests for ZCL_ODATA_FILTER_PARSER
CLASS ltcl_odata_filter_parser DEFINITION FINAL
  FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.

    " Helper to assert a single range entry
    METHODS assert_range
      IMPORTING
        iv_msg    TYPE string
        it_range  TYPE zcl_odata_filter_parser=>tt_range
        iv_index  TYPE i DEFAULT 1
        iv_sign   TYPE ddsign
        iv_option TYPE ddoption
        iv_low    TYPE string
        iv_high   TYPE string OPTIONAL.

    " V4 basic
    METHODS v4_simple_eq FOR TESTING.
    METHODS v4_multiple_eq_same_field FOR TESTING.
    METHODS v4_ne_as_exclusion FOR TESTING.
    METHODS v4_comparison_gt_ge_lt_le FOR TESTING.

    " V4 functions
    METHODS v4_contains FOR TESTING.
    METHODS v4_startswith FOR TESTING.
    METHODS v4_endswith FOR TESTING.
    METHODS v4_not_contains FOR TESTING.

    " V4 in operator
    METHODS v4_in_list FOR TESTING.
    METHODS v4_not_in_list FOR TESTING.

    " Parentheses and groups
    METHODS v4_parenthesized_or FOR TESTING.

    " Wildcards
    METHODS v4_wildcard_eq FOR TESTING.
    METHODS v4_wildcard_ne FOR TESTING.

    " Date handling
    METHODS v4_date_iso FOR TESTING.
    METHODS v2_datetime FOR TESTING.
    METHODS v2_datetimeoffset FOR TESTING.

    " Negation
    METHODS v4_not_eq FOR TESTING.
    METHODS v4_double_negation FOR TESTING.

    " Mixed / complex
    METHODS v4_mixed_filter FOR TESTING.

    " Static methods
    METHODS static_parse_to_select_options FOR TESTING.
    METHODS static_get_range_for_field FOR TESTING.

    " Edge cases
    METHODS empty_filter FOR TESTING.
    METHODS single_condition FOR TESTING.
    METHODS get_select_options_grouping FOR TESTING.

    " Short string - no dump on datetime check
    METHODS short_value_no_dump FOR TESTING.

ENDCLASS.


CLASS ltcl_odata_filter_parser IMPLEMENTATION.

  METHOD assert_range.
    DATA(lv_lines) = lines( it_range ).
    cl_abap_unit_assert=>assert_true(
      act = xsdbool( lv_lines >= iv_index )
      msg = |{ iv_msg }: expected at least { iv_index } entries, got { lv_lines }| ).

    DATA(ls_actual) = it_range[ iv_index ].

    cl_abap_unit_assert=>assert_equals(
      exp = iv_sign  act = ls_actual-sign
      msg = |{ iv_msg }: sign| ).
    cl_abap_unit_assert=>assert_equals(
      exp = iv_option  act = ls_actual-option
      msg = |{ iv_msg }: option| ).
    cl_abap_unit_assert=>assert_equals(
      exp = iv_low  act = ls_actual-low
      msg = |{ iv_msg }: low| ).
    IF iv_high IS SUPPLIED.
      cl_abap_unit_assert=>assert_equals(
        exp = iv_high  act = ls_actual-high
        msg = |{ iv_msg }: high| ).
    ENDIF.
  ENDMETHOD.

  METHOD v4_simple_eq.
    DATA(lo) = NEW zcl_odata_filter_parser(
      iv_filter = |Plant eq '1000'| iv_version = 4 ).
    DATA(lt) = lo->get_range( 'Plant' ).
    cl_abap_unit_assert=>assert_equals( exp = 1 act = lines( lt ) ).
    assert_range( iv_msg = 'simple eq' it_range = lt
                  iv_sign = 'I' iv_option = 'EQ' iv_low = '1000' ).
  ENDMETHOD.

  METHOD v4_multiple_eq_same_field.
    DATA(lo) = NEW zcl_odata_filter_parser(
      iv_filter = |Plant eq '1000' or Plant eq '2000'| iv_version = 4 ).
    DATA(lt) = lo->get_range( 'Plant' ).
    cl_abap_unit_assert=>assert_equals( exp = 2 act = lines( lt ) ).
    assert_range( iv_msg = 'multi eq #1' it_range = lt iv_index = 1
                  iv_sign = 'I' iv_option = 'EQ' iv_low = '1000' ).
    assert_range( iv_msg = 'multi eq #2' it_range = lt iv_index = 2
                  iv_sign = 'I' iv_option = 'EQ' iv_low = '2000' ).
  ENDMETHOD.

  METHOD v4_ne_as_exclusion.
    DATA(lo) = NEW zcl_odata_filter_parser(
      iv_filter = |Status ne 'X'| iv_version = 4 ).
    DATA(lt) = lo->get_range( 'Status' ).
    assert_range( iv_msg = 'ne' it_range = lt
                  iv_sign = 'E' iv_option = 'EQ' iv_low = 'X' ).
  ENDMETHOD.

  METHOD v4_comparison_gt_ge_lt_le.
    DATA(lo) = NEW zcl_odata_filter_parser(
      iv_filter = |Qty gt 10 and Qty le 100| iv_version = 4 ).
    DATA(lt) = lo->get_range( 'Qty' ).
    cl_abap_unit_assert=>assert_equals( exp = 2 act = lines( lt ) ).
    assert_range( iv_msg = 'gt' it_range = lt iv_index = 1
                  iv_sign = 'I' iv_option = 'GT' iv_low = '10' ).
    assert_range( iv_msg = 'le' it_range = lt iv_index = 2
                  iv_sign = 'I' iv_option = 'LE' iv_low = '100' ).
  ENDMETHOD.

  METHOD v4_contains.
    DATA(lo) = NEW zcl_odata_filter_parser(
      iv_filter = |contains(Material,'MAT')| iv_version = 4 ).
    DATA(lt) = lo->get_range( 'Material' ).
    assert_range( iv_msg = 'contains' it_range = lt
                  iv_sign = 'I' iv_option = 'CP' iv_low = '*MAT*' ).
  ENDMETHOD.

  METHOD v4_startswith.
    DATA(lo) = NEW zcl_odata_filter_parser(
      iv_filter = |startswith(Description,'SAP')| iv_version = 4 ).
    DATA(lt) = lo->get_range( 'Description' ).
    assert_range( iv_msg = 'startswith' it_range = lt
                  iv_sign = 'I' iv_option = 'CP' iv_low = 'SAP*' ).
  ENDMETHOD.

  METHOD v4_endswith.
    DATA(lo) = NEW zcl_odata_filter_parser(
      iv_filter = |endswith(DocNumber,'001')| iv_version = 4 ).
    DATA(lt) = lo->get_range( 'DocNumber' ).
    assert_range( iv_msg = 'endswith' it_range = lt
                  iv_sign = 'I' iv_option = 'CP' iv_low = '*001' ).
  ENDMETHOD.

  METHOD v4_not_contains.
    DATA(lo) = NEW zcl_odata_filter_parser(
      iv_filter = |not contains(Material,'OBSOLETE')| iv_version = 4 ).
    DATA(lt) = lo->get_range( 'Material' ).
    assert_range( iv_msg = 'not contains' it_range = lt
                  iv_sign = 'E' iv_option = 'CP' iv_low = '*OBSOLETE*' ).
  ENDMETHOD.

  METHOD v4_in_list.
    DATA(lo) = NEW zcl_odata_filter_parser(
      iv_filter = |Plant in ('1000','2000','3000')| iv_version = 4 ).
    DATA(lt) = lo->get_range( 'Plant' ).
    cl_abap_unit_assert=>assert_equals( exp = 3 act = lines( lt ) ).
    assert_range( iv_msg = 'in #1' it_range = lt iv_index = 1
                  iv_sign = 'I' iv_option = 'EQ' iv_low = '1000' ).
    assert_range( iv_msg = 'in #2' it_range = lt iv_index = 2
                  iv_sign = 'I' iv_option = 'EQ' iv_low = '2000' ).
    assert_range( iv_msg = 'in #3' it_range = lt iv_index = 3
                  iv_sign = 'I' iv_option = 'EQ' iv_low = '3000' ).
  ENDMETHOD.

  METHOD v4_not_in_list.
    DATA(lo) = NEW zcl_odata_filter_parser(
      iv_filter = |not (Plant in ('9000','9999'))| iv_version = 4 ).
    DATA(lt) = lo->get_range( 'Plant' ).
    cl_abap_unit_assert=>assert_equals( exp = 2 act = lines( lt ) ).
    assert_range( iv_msg = 'not in #1' it_range = lt iv_index = 1
                  iv_sign = 'E' iv_option = 'EQ' iv_low = '9000' ).
    assert_range( iv_msg = 'not in #2' it_range = lt iv_index = 2
                  iv_sign = 'E' iv_option = 'EQ' iv_low = '9999' ).
  ENDMETHOD.

  METHOD v4_parenthesized_or.
    DATA(lo) = NEW zcl_odata_filter_parser(
      iv_filter = |(Plant eq '1000' or Plant eq '2000') and Material eq 'MAT001'|
      iv_version = 4 ).
    DATA(lt_p) = lo->get_range( 'Plant' ).
    DATA(lt_m) = lo->get_range( 'Material' ).
    cl_abap_unit_assert=>assert_equals( exp = 2 act = lines( lt_p ) ).
    cl_abap_unit_assert=>assert_equals( exp = 1 act = lines( lt_m ) ).
    assert_range( iv_msg = 'paren plant' it_range = lt_p iv_index = 1
                  iv_sign = 'I' iv_option = 'EQ' iv_low = '1000' ).
    assert_range( iv_msg = 'paren mat' it_range = lt_m
                  iv_sign = 'I' iv_option = 'EQ' iv_low = 'MAT001' ).
  ENDMETHOD.

  METHOD v4_wildcard_eq.
    DATA(lo) = NEW zcl_odata_filter_parser(
      iv_filter = |Material eq 'MAT*'| iv_version = 4 ).
    DATA(lt) = lo->get_range( 'Material' ).
    assert_range( iv_msg = 'wildcard eq' it_range = lt
                  iv_sign = 'I' iv_option = 'CP' iv_low = 'MAT*' ).
  ENDMETHOD.

  METHOD v4_wildcard_ne.
    DATA(lo) = NEW zcl_odata_filter_parser(
      iv_filter = |Material ne 'OBS*'| iv_version = 4 ).
    DATA(lt) = lo->get_range( 'Material' ).
    assert_range( iv_msg = 'wildcard ne' it_range = lt
                  iv_sign = 'E' iv_option = 'CP' iv_low = 'OBS*' ).
  ENDMETHOD.

  METHOD v4_date_iso.
    DATA(lo) = NEW zcl_odata_filter_parser(
      iv_filter = |DeliveryDate ge 2024-01-15 and DeliveryDate le 2024-12-31|
      iv_version = 4 ).
    DATA(lt) = lo->get_range( 'DeliveryDate' ).
    cl_abap_unit_assert=>assert_equals( exp = 2 act = lines( lt ) ).
    assert_range( iv_msg = 'date ge' it_range = lt iv_index = 1
                  iv_sign = 'I' iv_option = 'GE' iv_low = '20240115' ).
    assert_range( iv_msg = 'date le' it_range = lt iv_index = 2
                  iv_sign = 'I' iv_option = 'LE' iv_low = '20241231' ).
  ENDMETHOD.

  METHOD v2_datetime.
    DATA(lo) = NEW zcl_odata_filter_parser(
      iv_filter = |CreationDate ge datetime'2024-01-15T00:00:00'|
      iv_version = 2 ).
    DATA(lt) = lo->get_range( 'CreationDate' ).
    assert_range( iv_msg = 'v2 datetime' it_range = lt
                  iv_sign = 'I' iv_option = 'GE' iv_low = '20240115000000' ).
  ENDMETHOD.

  METHOD v2_datetimeoffset.
    DATA(lo) = NEW zcl_odata_filter_parser(
      iv_filter = |CreationDate le datetimeoffset'2024-12-31T23:59:59Z'|
      iv_version = 2 ).
    DATA(lt) = lo->get_range( 'CreationDate' ).
    assert_range( iv_msg = 'v2 datetimeoffset' it_range = lt
                  iv_sign = 'I' iv_option = 'LE' iv_low = '20241231235959' ).
  ENDMETHOD.

  METHOD v4_not_eq.
    DATA(lo) = NEW zcl_odata_filter_parser(
      iv_filter = |not (Plant eq '9999')| iv_version = 4 ).
    DATA(lt) = lo->get_range( 'Plant' ).
    assert_range( iv_msg = 'not eq' it_range = lt
                  iv_sign = 'E' iv_option = 'EQ' iv_low = '9999' ).
  ENDMETHOD.

  METHOD v4_double_negation.
    DATA(lo) = NEW zcl_odata_filter_parser(
      iv_filter = |not (Status ne 'A')| iv_version = 4 ).
    DATA(lt) = lo->get_range( 'Status' ).
    " not ne = eq (double negation)
    assert_range( iv_msg = 'double neg' it_range = lt
                  iv_sign = 'I' iv_option = 'EQ' iv_low = 'A' ).
  ENDMETHOD.

  METHOD v4_mixed_filter.
    DATA(lv_filter) =
      |Plant eq '1000' and Plant eq '2000'| &&
      | and contains(Material,'MAT')| &&
      | and DeliveryDate ge 2024-01-01 and DeliveryDate le 2024-12-31| &&
      | and ShipToParty in ('CUST001','CUST002','CUST003')|.

    DATA(lo) = NEW zcl_odata_filter_parser(
      iv_filter = lv_filter iv_version = 4 ).

    DATA(lt_plant) = lo->get_range( 'Plant' ).
    DATA(lt_mat)   = lo->get_range( 'Material' ).
    DATA(lt_date)  = lo->get_range( 'DeliveryDate' ).
    DATA(lt_ship)  = lo->get_range( 'ShipToParty' ).

    cl_abap_unit_assert=>assert_equals( exp = 2 act = lines( lt_plant ) msg = 'Plant count' ).
    cl_abap_unit_assert=>assert_equals( exp = 1 act = lines( lt_mat )   msg = 'Material count' ).
    cl_abap_unit_assert=>assert_equals( exp = 2 act = lines( lt_date )  msg = 'Date count' ).
    cl_abap_unit_assert=>assert_equals( exp = 3 act = lines( lt_ship )  msg = 'ShipTo count' ).

    assert_range( iv_msg = 'mixed mat' it_range = lt_mat
                  iv_sign = 'I' iv_option = 'CP' iv_low = '*MAT*' ).
    assert_range( iv_msg = 'mixed ship #3' it_range = lt_ship iv_index = 3
                  iv_sign = 'I' iv_option = 'EQ' iv_low = 'CUST003' ).
  ENDMETHOD.

  METHOD static_parse_to_select_options.
    DATA(lt_so) = zcl_odata_filter_parser=>parse_to_select_options(
      iv_filter = |Plant eq '1000' and Material eq 'MAT001'|
      iv_version = 4 ).
    cl_abap_unit_assert=>assert_equals( exp = 2 act = lines( lt_so ) ).
    cl_abap_unit_assert=>assert_equals(
      exp = 'Plant' act = lt_so[ 1 ]-property msg = 'static selopt field 1' ).
    cl_abap_unit_assert=>assert_equals(
      exp = 'Material' act = lt_so[ 2 ]-property msg = 'static selopt field 2' ).
  ENDMETHOD.

  METHOD static_get_range_for_field.
    DATA(lt) = zcl_odata_filter_parser=>get_range_for_field(
      iv_filter = |Plant eq '1000' and Material eq 'MAT001'|
      iv_field  = 'Material'
      iv_version = 4 ).
    cl_abap_unit_assert=>assert_equals( exp = 1 act = lines( lt ) ).
    assert_range( iv_msg = 'static range' it_range = lt
                  iv_sign = 'I' iv_option = 'EQ' iv_low = 'MAT001' ).
  ENDMETHOD.

  METHOD empty_filter.
    DATA(lo) = NEW zcl_odata_filter_parser(
      iv_filter = || iv_version = 4 ).
    DATA(lt) = lo->get_conditions( ).
    cl_abap_unit_assert=>assert_equals( exp = 0 act = lines( lt ) msg = 'empty filter' ).
  ENDMETHOD.

  METHOD single_condition.
    DATA(lo) = NEW zcl_odata_filter_parser(
      iv_filter = |Name eq 'Test'| iv_version = 4 ).
    DATA(lt) = lo->get_conditions( ).
    cl_abap_unit_assert=>assert_equals( exp = 1 act = lines( lt ) msg = 'single condition' ).
  ENDMETHOD.

  METHOD get_select_options_grouping.
    DATA(lo) = NEW zcl_odata_filter_parser(
      iv_filter = |Plant eq '1000' and Plant eq '2000' and Material eq 'A'|
      iv_version = 4 ).
    DATA(lt_so) = lo->get_select_options( ).
    " Should group: Plant (2 entries), Material (1 entry)
    cl_abap_unit_assert=>assert_equals( exp = 2 act = lines( lt_so ) msg = 'grouping count' ).
    cl_abap_unit_assert=>assert_equals(
      exp = 2 act = lines( lt_so[ 1 ]-select_options ) msg = 'Plant has 2 ranges' ).
    cl_abap_unit_assert=>assert_equals(
      exp = 1 act = lines( lt_so[ 2 ]-select_options ) msg = 'Material has 1 range' ).
  ENDMETHOD.

  METHOD short_value_no_dump.
    " Values like '1000' (4 chars) must not cause STRING_LENGTH_TOO_LARGE
    " when checking for datetime prefix (9+ chars)
    TRY.
        DATA(lo) = NEW zcl_odata_filter_parser(
          iv_filter = |Plant eq '1000' and Status eq 'A' and Qty eq 5|
          iv_version = 4 ).
        DATA(lt) = lo->get_conditions( ).
        cl_abap_unit_assert=>assert_equals(
          exp = 3 act = lines( lt ) msg = 'short values no dump' ).
      CATCH cx_root INTO DATA(lx).
        cl_abap_unit_assert=>fail(
          msg = |Unexpected exception: { lx->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
