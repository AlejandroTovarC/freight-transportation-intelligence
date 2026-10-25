-- =========================================================
-- SILVER LAYER: cleansed, typed, conformed
-- One table per source entity (not yet dimensional/star-shaped).
-- Bad/placeholder values resolved, text-typed numerics cast properly,
-- first business-rule calculations applied. Metadata retained.
-- =========================================================

\connect freight_transportation_intelligence;

CREATE SCHEMA IF NOT EXISTS silver;
SET search_path TO silver;

CREATE TABLE silver.state (
    state_fips_id   smallint PRIMARY KEY,
    state_abbr      varchar(2) NOT NULL,
    state_name      varchar(50) NOT NULL,
    census_region   varchar(30),
    census_division varchar(30),
    _loaded_at      timestamp NOT NULL DEFAULT now()
);

-- NOTE: cfs_area_code is alphanumeric in the actual data (e.g. "04-536" = state
-- FIPS + area number), not numeric. The partner's operational.cfs_area /
-- operational.facility declare it `bigint`, which will fail to load this data
-- as-is -- flag this to them. Silver/gold here use varchar to be safe.
CREATE TABLE silver.cfs_area (
    cfs_area_code varchar(10) PRIMARY KEY,
    state_fips    smallint REFERENCES silver.state(state_fips_id),
    ma_code       bigint,
    area_name     varchar(100),
    _loaded_at    timestamp NOT NULL DEFAULT now()
);

CREATE TABLE silver.facility (
    facility_id   bigint PRIMARY KEY,
    facility_name varchar(100),
    facility_type varchar(50),
    cfs_area_code varchar(10) REFERENCES silver.cfs_area(cfs_area_code),
    city          varchar(100),
    _loaded_at    timestamp NOT NULL DEFAULT now()
);

CREATE TABLE silver.event_type (
    event_type_id bigint PRIMARY KEY,
    event_code    varchar(20) NOT NULL UNIQUE,
    event_name    varchar(100),
    is_exception  boolean NOT NULL DEFAULT false,
    _loaded_at    timestamp NOT NULL DEFAULT now()
);

CREATE TABLE silver.shipment_event (
    event_id      bigint PRIMARY KEY,
    shipment_id   bigint NOT NULL,
    event_type_id bigint REFERENCES silver.event_type(event_type_id),
    event_ts      timestamp,
    facility_id   bigint REFERENCES silver.facility(facility_id),
    _loaded_at    timestamp NOT NULL DEFAULT now()
);

CREATE TABLE silver.industry_sector (
    sector_code_id bigint PRIMARY KEY,
    sector_name    varchar(100),
    _loaded_at     timestamp NOT NULL DEFAULT now()
);

CREATE TABLE silver.customer (
    customer_id    bigint PRIMARY KEY,
    customer_name  varchar(150) NOT NULL,
    sector_code    bigint REFERENCES silver.industry_sector(sector_code_id),
    hq_state_fips  smallint REFERENCES silver.state(state_fips_id),
    customer_since date,
    is_active      boolean NOT NULL DEFAULT true,
    _loaded_at     timestamp NOT NULL DEFAULT now()
);

-- Already effective-dated in the source; silver just cleans types.
-- This is the direct feed for the Dim_Customer SCD2 build in gold.
CREATE TABLE silver.customer_profile_history (
    customer_id    bigint NOT NULL REFERENCES silver.customer(customer_id),
    effective_from date NOT NULL,
    effective_to   date,
    segment        varchar(30),
    credit_tier    varchar(10),
    _loaded_at     timestamp NOT NULL DEFAULT now(),
    PRIMARY KEY (customer_id, effective_from)
);

CREATE TABLE silver.carrier (
    carrier_id     bigint PRIMARY KEY,
    carrier_name   varchar(150) NOT NULL,
    scac_code      varchar(10) NOT NULL UNIQUE,
    carrier_type   varchar(50),
    safety_rating  varchar(20),
    is_active      boolean NOT NULL DEFAULT true,
    _loaded_at     timestamp NOT NULL DEFAULT now()
);

CREATE TABLE silver.transport_mode (
    mode_code_id bigint PRIMARY KEY,
    mode_name    varchar(50) NOT NULL,
    mode_group   varchar(50),
    _loaded_at   timestamp NOT NULL DEFAULT now()
);

CREATE TABLE silver.carrier_mode (
    carrier_id bigint NOT NULL REFERENCES silver.carrier(carrier_id),
    mode_code  bigint NOT NULL REFERENCES silver.transport_mode(mode_code_id),
    _loaded_at timestamp NOT NULL DEFAULT now(),
    PRIMARY KEY (carrier_id, mode_code)
);

CREATE TABLE silver.carrier_rate (
    rate_id             bigint PRIMARY KEY,
    carrier_id          bigint NOT NULL,
    mode_code           bigint NOT NULL,
    effective_from      date NOT NULL,
    effective_to        date,
    rate_per_mile       numeric(8,2),
    rate_per_cwt        numeric(8,2),
    min_charge          numeric(10,2),
    fuel_surcharge_pct  numeric(5,2),             -- cast from text, e.g. "20.25" -> 20.25
    _loaded_at          timestamp NOT NULL DEFAULT now(),
    FOREIGN KEY (carrier_id, mode_code) REFERENCES silver.carrier_mode(carrier_id, mode_code)
);

CREATE TABLE silver.sctg_commodity (
    sctg_code_id bigint PRIMARY KEY,
    sctg_name    varchar(150),
    sctg_group   varchar(100),
    _loaded_at   timestamp NOT NULL DEFAULT now()
);

CREATE TABLE silver.shipment (
    shipment_id           bigint PRIMARY KEY,
    cfs_shipment_id       bigint,
    data_origin           varchar(20),
    customer_id           bigint NOT NULL REFERENCES silver.customer(customer_id),
    carrier_id            bigint NOT NULL,
    mode_code             bigint NOT NULL,
    sctg_code             bigint NOT NULL REFERENCES silver.sctg_commodity(sctg_code_id),
    origin_facility_id    bigint NOT NULL REFERENCES silver.facility(facility_id),
    dest_facility_id      bigint NOT NULL REFERENCES silver.facility(facility_id),
    ship_date             date NOT NULL,
    delivery_date         date,
    shipment_value        numeric(12,2),           -- cast from text
    shipment_weight_lbs   numeric(10,2),           -- cast from text, renamed for clarity
    dist_great_circle_mi  numeric(10,2),           -- cast from text, renamed for clarity
    temp_controlled       boolean NOT NULL DEFAULT false,
    hazmat_code           bigint,
    is_export             boolean NOT NULL DEFAULT false,
    export_country        varchar(5),
    survey_weight_factor  numeric(10,4),           -- cast from text ("survery_weight" typo fixed)
    transit_days          numeric(6,2) GENERATED ALWAYS AS (delivery_date - ship_date) STORED,
    _loaded_at            timestamp NOT NULL DEFAULT now(),
    FOREIGN KEY (carrier_id, mode_code) REFERENCES silver.carrier_mode(carrier_id, mode_code)
);

CREATE TABLE silver.invoice (
    invoice_id      bigint PRIMARY KEY,
    shipment_id     bigint NOT NULL REFERENCES silver.shipment(shipment_id),
    invoice_number  bigint NOT NULL UNIQUE,
    invoice_date    date NOT NULL,
    due_date        date,
    invoice_status  varchar(20) NOT NULL,          -- fixed from mis-typed "char"
    _loaded_at      timestamp NOT NULL DEFAULT now()
);

CREATE TABLE silver.charge_type (
    charge_type_id bigint PRIMARY KEY,
    charge_code    bigint NOT NULL UNIQUE,
    charge_name    varchar(50) NOT NULL,           -- fixed from mis-typed "char"
    _loaded_at     timestamp NOT NULL DEFAULT now()
);

CREATE TABLE silver.invoice_line (
    invoice_id       bigint NOT NULL REFERENCES silver.invoice(invoice_id),
    line_no          bigint NOT NULL,
    charge_type_id   bigint NOT NULL REFERENCES silver.charge_type(charge_type_id),
    billed_amount    numeric(12,2) NOT NULL,
    contract_amount  numeric(12,2),                -- NEW: populated from carrier_rate x shipment distance/weight
    variance_amount  numeric(12,2) GENERATED ALWAYS AS (billed_amount - contract_amount) STORED,
    _loaded_at       timestamp NOT NULL DEFAULT now(),
    PRIMARY KEY (invoice_id, line_no)
);

CREATE TABLE silver.payment (
    payment_id      bigint PRIMARY KEY,
    invoice_id      bigint NOT NULL REFERENCES silver.invoice(invoice_id),
    payment_date    date NOT NULL,
    amount_paid     numeric(12,2) NOT NULL,
    payment_method  varchar(20),
    _loaded_at      timestamp NOT NULL DEFAULT now()
);

-- Example bronze -> silver transform (shipment): cast + clean in one pass
-- INSERT INTO silver.shipment (
--     shipment_id, cfs_shipment_id, data_origin, customer_id, carrier_id, mode_code,
--     sctg_code, origin_facility_id, dest_facility_id, ship_date, delivery_date,
--     shipment_value, shipment_weight_lbs, dist_great_circle_mi, temp_controlled,
--     hazmat_code, is_export, export_country, survey_weight_factor
-- )
-- SELECT
--     shipment_id::bigint, cfs_shipment_id::bigint, data_origin, customer_id::bigint,
--     carrier_id::bigint, mode_code::bigint, sctg_code::bigint, origin_facility_id::bigint,
--     dest_facility_id::bigint, ship_date::date, delivery_date::date,
--     NULLIF(shipment_value, '')::numeric, NULLIF(shipment_weight, '')::numeric,
--     NULLIF(dist_great_circle, '')::numeric, (temp_controlled)::boolean,
--     NULLIF(hazmat_code, '')::bigint, (is_export)::boolean, export_country,
--     NULLIF(survery_weight, '')::numeric
-- FROM bronze.shipment
-- WHERE shipment_id IS NOT NULL;
