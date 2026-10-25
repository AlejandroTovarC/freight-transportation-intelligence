-- =========================================================
-- BRONZE LAYER: raw landing zone
-- Direct extraction from source (operational DB / CSVs), no transformation.
-- Every column is kept as text; only metadata columns are added.
-- =========================================================

\connect freight_transportation_intelligence;

CREATE SCHEMA IF NOT EXISTS bronze;
SET search_path TO bronze;

CREATE TABLE bronze.state (
    state_fips_id   text,
    state_abbr      text,
    state_name      text,
    census_region   text,
    census_division text,
    _source_file    text,
    _loaded_at      timestamp NOT NULL DEFAULT now()
);

CREATE TABLE bronze.cfs_area (
    cfs_area_code text,
    state_fips    text,
    ma_code       text,
    area_name     text,
    _source_file  text,
    _loaded_at    timestamp NOT NULL DEFAULT now()
);

CREATE TABLE bronze.facility (
    facility_id   text,
    facility_name text,
    facility_type text,
    cfs_area_code text,
    city          text,
    _source_file  text,
    _loaded_at    timestamp NOT NULL DEFAULT now()
);

CREATE TABLE bronze.event_type (
    event_type_id text,
    event_code    text,
    event_name    text,
    is_exception  text,
    _source_file  text,
    _loaded_at    timestamp NOT NULL DEFAULT now()
);

CREATE TABLE bronze.shipment_event (
    event_id      text,
    shipment_id   text,
    event_type_id text,
    event_ts      text,
    facility_id   text,
    _source_file  text,
    _loaded_at    timestamp NOT NULL DEFAULT now()
);

CREATE TABLE bronze.industry_sector (
    sector_code_id text,
    sector_name    text,
    _source_file   text,
    _loaded_at     timestamp NOT NULL DEFAULT now()
);

CREATE TABLE bronze.customer (
    customer_id     text,
    customer_name   text,
    sector_code     text,
    hq_state_fips   text,
    customer_since  text,
    is_active       text,
    _source_file    text,
    _loaded_at      timestamp NOT NULL DEFAULT now()
);

CREATE TABLE bronze.customer_profile_history (
    customer_id    text,
    effective_from text,
    effective_to   text,
    segment        text,
    credit_tier    text,
    _source_file   text,
    _loaded_at     timestamp NOT NULL DEFAULT now()
);

CREATE TABLE bronze.carrier (
    carrier_id     text,
    carrier_name   text,
    scac_code      text,
    carrier_type   text,
    safety_rating  text,
    is_active      text,
    _source_file   text,
    _loaded_at     timestamp NOT NULL DEFAULT now()
);

CREATE TABLE bronze.transport_mode (
    mode_code_id text,
    mode_name    text,
    mode_group   text,
    _source_file text,
    _loaded_at   timestamp NOT NULL DEFAULT now()
);

CREATE TABLE bronze.carrier_mode (
    carrier_id   text,
    mode_code    text,
    _source_file text,
    _loaded_at   timestamp NOT NULL DEFAULT now()
);

CREATE TABLE bronze.carrier_rate (
    rate_id            text,
    carrier_id         text,
    mode_code          text,
    effective_from     text,
    effective_to       text,
    rate_per_mile      text,
    rate_per_cwt       text,
    min_charge         text,
    fuel_surcharge_pct text,
    _source_file       text,
    _loaded_at         timestamp NOT NULL DEFAULT now()
);

CREATE TABLE bronze.sctg_commodity (
    sctg_code_id text,
    sctg_name    text,
    sctg_group   text,
    _source_file text,
    _loaded_at   timestamp NOT NULL DEFAULT now()
);

CREATE TABLE bronze.shipment (
    shipment_id        text,
    cfs_shipment_id    text,
    data_origin        text,
    customer_id        text,
    carrier_id         text,
    mode_code          text,
    sctg_code          text,
    origin_facility_id text,
    dest_facility_id   text,
    ship_date          text,
    delivery_date      text,
    shipment_value     text,
    shipment_weight    text,
    dist_great_circle  text,
    temp_controlled    text,
    hazmat_code        text,
    is_export          text,
    export_country     text,
    survery_weight     text,
    _source_file       text,
    _loaded_at         timestamp NOT NULL DEFAULT now()
);

CREATE TABLE bronze.invoice (
    invoice_id      text,
    shipment_id     text,
    invoice_number  text,
    invoice_date    text,
    due_date        text,
    invoice_status  text,
    _source_file    text,
    _loaded_at      timestamp NOT NULL DEFAULT now()
);

CREATE TABLE bronze.invoice_line (
    invoice_id      text,
    line_no         text,
    charge_type_id  text,
    billed_amount   text,
    _source_file    text,
    _loaded_at      timestamp NOT NULL DEFAULT now()
);

CREATE TABLE bronze.charge_type (
    charge_type_id text,
    charge_code    text,
    charge_name    text,
    _source_file   text,
    _loaded_at     timestamp NOT NULL DEFAULT now()
);

CREATE TABLE bronze.payment (
    payment_id      text,
    invoice_id      text,
    payment_date    text,
    amount_paid     text,
    payment_method  text,
    _source_file    text,
    _loaded_at      timestamp NOT NULL DEFAULT now()
);

-- Example load (repeat per CSV, via psql \copy or a Talend/Python job):
-- \copy bronze.shipment(shipment_id, cfs_shipment_id, data_origin, customer_id, carrier_id,
--   mode_code, sctg_code, origin_facility_id, dest_facility_id, ship_date, delivery_date,
--   shipment_value, shipment_weight, dist_great_circle, temp_controlled, hazmat_code,
--   is_export, export_country, survery_weight)
--   FROM 'data/synthetic/shipment.csv' WITH (FORMAT csv, HEADER true);
-- UPDATE bronze.shipment SET _source_file = 'shipment.csv' WHERE _source_file IS NULL;
