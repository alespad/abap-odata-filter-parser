ABAP class that parses OData $filter strings into native ABAP range tables (select options).  
Supports both OData V2 and V4 syntax, including V4 functions like contains(), startswith(), endswith() and the in operator.

## Quick Start

### Static one-liner
```abap
DATA(lt_select_options) = zcl_odata_filter_parser=>parse_to_select_options(
  iv_filter  = |Plant eq '1000' and contains(Material,'MAT')|
  iv_version = zcl_odata_filter_parser=>gc_version-v4
).
```

### Get range for a specific field
```abap
DATA(lt_range) = zcl_odata_filter_parser=>get_range_for_field(
  iv_filter  = lv_filter_string
  iv_field   = 'Plant'
  iv_version = zcl_odata_filter_parser=>gc_version-v4
).
```

### Instance-based (multiple fields from same filter)
```abap
DATA(lo_parser) = NEW zcl_odata_filter_parser(
  iv_filter  = lv_filter_string
  iv_version = zcl_odata_filter_parser=>gc_version-v4
).

DATA(lt_r_plant) = lo_parser->get_range( 'Plant' ).
DATA(lt_r_mat)   = lo_parser->get_range( 'Material' ).
DATA(lt_r_date)  = lo_parser->get_range( 'DeliveryDate' ).
```
