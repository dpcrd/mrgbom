-- Before importing, replace "" with 0 in columns sourced and placed

CREATE TABLE IF NOT EXISTS pcbbom1(
	rownum INTEGER,
    sourced INTEGER NOT NULL DEFAULT 0 CHECK (sourced IN (0, 1)),
    placed INTEGER NOT NULL DEFAULT 0 CHECK (placed IN (0, 1)),
    comp_ref TEXT,
    vendor TEXT NOT NULL,
    vendor_part_number TEXT NOT NULL,
    comp_value TEXT,
    partnumber TEXT,
    description TEXT,
    comment TEXT,
    footprint TEXT,
    price_per_part REAL,
    parts_per_sales_unit INTEGER,
    manufacturer TEXT,
    manufacturer_part_number TEXT,
    mate_manufacturer TEXT,
    mate_manufacturer_part_number TEXT,
    mate_vendor TEXT,
    mate_vendor_part_number TEXT,
    mate_price_per_part REAL,
    mate_parts_per_sales_unit INTEGER,
    box_id INTEGER,
    box_row INTEGER,
    box_column INTEGER,
    quantity INTEGER,
    PRIMARY KEY (vendor, vendor_part_number)
);

CREATE TABLE IF NOT EXISTS pcbbom2(
	rownum INTEGER,
    sourced INTEGER NOT NULL DEFAULT 0 CHECK (sourced IN (0, 1)),
    placed INTEGER NOT NULL DEFAULT 0 CHECK (placed IN (0, 1)),
    comp_ref TEXT,
    vendor TEXT NOT NULL,
    vendor_part_number TEXT NOT NULL,
    comp_value TEXT,
    partnumber TEXT,
    description TEXT,
    comment TEXT,
    footprint TEXT,
    price_per_part REAL,
    parts_per_sales_unit INTEGER,
    manufacturer TEXT,
    manufacturer_part_number TEXT,
    mate_manufacturer TEXT,
    mate_manufacturer_part_number TEXT,
    mate_vendor TEXT,
    mate_vendor_part_number TEXT,
    mate_price_per_part REAL,
    mate_parts_per_sales_unit INTEGER,
    box_id INTEGER,
    box_row INTEGER,
    box_column INTEGER,
    quantity INTEGER,
    PRIMARY KEY (vendor, vendor_part_number)
);


-- Create a view to merge the previous tables:
-- - sum the quantities
-- - add the mate fields as new entries: mate_vendor --> vendor,
--   mate_vendor_part_number --> vendor_part_number

DROP VIEW IF EXISTS pcb_all;
CREATE VIEW pcb_all AS
WITH source_rows AS (
    SELECT * FROM pcbbom1
    UNION ALL
    SELECT * FROM pcbbom2
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
