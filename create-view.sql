-- Create a view to merge the previous tables:
-- - sum the quantities
-- - add the mate fields as new entries: mate_vendor --> vendor,
--   mate_vendor_part_number --> vendor_part_number

DROP VIEW IF EXISTS pcb_all;
CREATE VIEW pcb_all AS
WITH source_rows AS (
UNION_SELECT_FROM_ALL_TABLES
),
all_parts AS (
    SELECT
        vendor,
        vendor_part_number,
        quantity,
        comp_value,
        partnumber,
        description,
        comment,
        footprint,
        parts_per_sales_unit
    FROM source_rows
    WHERE NULLIF(TRIM(vendor), '') IS NOT NULL
      AND NULLIF(TRIM(vendor_part_number), '') IS NOT NULL
    UNION ALL
    SELECT
        NULLIF(TRIM(mate_vendor), '') AS vendor,
        NULLIF(TRIM(mate_vendor_part_number), '') AS vendor_part_number,
        quantity,
        comp_value,
        partnumber,
        description,
        comment,
        footprint,
        NULLIF(TRIM(mate_parts_per_sales_unit), '') AS parts_per_sales_unit
    FROM source_rows
    WHERE NULLIF(TRIM(mate_vendor), '') IS NOT NULL
      AND NULLIF(TRIM(mate_vendor_part_number), '') IS NOT NULL
)
SELECT
    vendor,
    vendor_part_number,
    SUM(quantity) AS quantity,
    MAX(comp_value) AS comp_value,
    MAX(partnumber) AS partnumber,
    MAX(description) AS description,
    MAX(comment) AS comment,
    MAX(footprint) AS footprint,
    MAX(parts_per_sales_unit) AS parts_per_sales_unit
FROM all_parts
GROUP BY vendor, vendor_part_number;
