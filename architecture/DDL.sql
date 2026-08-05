-- =====================================================================
-- CelRevive Formulation Catalog — PostgreSQL Schema (target: BCNF)
-- Source: Top15_Active_Database.xlsx
-- =====================================================================
-- Design notes on normalization are in the accompanying README.md.
-- Every table below has a single candidate key per determinant, i.e.
-- every non-trivial functional dependency's left-hand side is a
-- superkey of the table it lives in — the BCNF test.
-- =====================================================================

CREATE SCHEMA IF NOT EXISTS celrevive;
SET search_path TO celrevive;

-- ---------------------------------------------------------------------
-- PART 1 — CATALOG (directly sourced from the workbook)
-- ---------------------------------------------------------------------

-- 1. Supplier -----------------------------------------------------------
CREATE TABLE supplier (
    supplier_id     SERIAL PRIMARY KEY,
    supplier_name   TEXT NOT NULL UNIQUE
);

-- 2. Primary category (from "AI Taxonomy" sheet) -------------------------
-- Pulled out of Active because ai_matching_notes / identified_by depend
-- only on category_name, not on the individual active — leaving them on
-- Active would be a non-key (transitive) dependency and break 3NF/BCNF.
CREATE TABLE primary_category (
    category_id         SERIAL PRIMARY KEY,
    category_name        TEXT NOT NULL UNIQUE,
    ai_matching_notes    TEXT,          -- "When to use in AI matching"
    identified_by        TEXT CHECK (identified_by IN
                              ('Image', 'Questionnaire',
                               'Image + Questionnaire')),
    severity_notes        TEXT
);

-- 3. Skin concern taxonomy (anodiam_skin_concern_detection) -------------
CREATE TABLE skin_concern (
    skin_concern_id             TEXT PRIMARY KEY,   -- e.g. 'SC0001'
    concern_name                TEXT NOT NULL UNIQUE,
    detectable_by_selfie        BOOLEAN NOT NULL DEFAULT FALSE,
    detectable_by_questionnaire BOOLEAN NOT NULL DEFAULT FALSE
);

-- 4. Base formulas (Bases sheet) -----------------------------------------
CREATE TABLE base (
    base_id                   SERIAL PRIMARY KEY,
    base_name                 TEXT NOT NULL UNIQUE,
    price_tier                TEXT CHECK (price_tier IN ('$','$$','$$$','$$$$')),
    cost_per_gram              NUMERIC(10,4),        -- populate once client confirms actual cost
    age_min                    SMALLINT,
    age_max                    SMALLINT,              -- NULL = no upper bound ("35+")
    skin_type                  TEXT,
    skin_moisture               TEXT,
    acne_suitable               BOOLEAN,
    retinoid_compatible         BOOLEAN,
    sensory_preference          TEXT,
    ph_min                     NUMERIC(3,1),
    ph_max                     NUMERIC(3,1),
    spreadability                TEXT,
    solubility_compatibility    TEXT CHECK (solubility_compatibility IN
                                   ('Water', 'Oil', 'Water/Oil')),
    climate                    TEXT,
    layering_rating             TEXT,
    occlusivity                 TEXT
);

-- 5. Active ingredients (Actives + Top 15 Actives Detail, merged) --------
-- The two sheets describe the same 20 candidate slots at different
-- levels of detail; they are the same entity and collapse to one table.
CREATE TABLE active (
    active_id                  SERIAL PRIMARY KEY,
    active_name                TEXT NOT NULL UNIQUE,
    supplier_id                INT REFERENCES supplier(supplier_id),
    category_id                INT REFERENCES primary_category(category_id),
    cost_per_gram              NUMERIC(10,4),          -- NULL while "TBC"
    inci_composition           TEXT,
    category_detail            TEXT,
    key_claims                 TEXT,
    mechanism_of_action        TEXT,
    evidence_summary           TEXT,
    usage_level_text           TEXT,                   -- original free text, e.g. "0.3-2%"
    usage_level_min_pct        NUMERIC(5,3),
    usage_level_max_pct        NUMERIC(5,3),
    grams_per_100g             NUMERIC(6,3),            -- "Grams per 100g total active + base"
    ph_min                     NUMERIC(4,2),
    ph_max                     NUMERIC(4,2),
    appearance                 TEXT,
    solubility                 TEXT CHECK (solubility IN ('Water', 'Oil', 'Water/Oil')),
    phase_to_add                TEXT,
    natural_synthetic_notes     TEXT,
    key_highlights               TEXT,
    key_benefits                TEXT,
    suitable_for                 TEXT,
    implementation_phase         TEXT,
    -- Free-text formulation caution that isn't (yet) a structured pairing,
    -- e.g. "avoid combining with copper or iron ions". Structured
    -- active-active conflicts live in active_incompatibility below.
    formulation_caution_notes    TEXT
);

-- 6. Benefit dimensions (the ~20 score columns in "Top 15 Actives Detail")
-- Turning the 20 wide columns into rows removes a repeating group
-- (1NF) and lets a score's key be (active_id, benefit_id) instead of
-- forcing 20 nullable columns onto every active row.
CREATE TABLE benefit_dimension (
    benefit_id      SERIAL PRIMARY KEY,
    benefit_name    TEXT NOT NULL UNIQUE      -- 'Increase hydration', 'Reduce redness', ...
);

CREATE TABLE active_benefit_score (
    active_id       INT NOT NULL REFERENCES active(active_id)  ON DELETE CASCADE,
    benefit_id      INT NOT NULL REFERENCES benefit_dimension(benefit_id),
    score           SMALLINT NOT NULL CHECK (score BETWEEN 0 AND 20),
    PRIMARY KEY (active_id, benefit_id)
);

-- 7. Tags — unifies "Primary Skin Concerns Covered", "AI Tags" and
-- "AI Tags 2" (all comma-separated free text in the sheet) into one
-- tag vocabulary, distinguished by tag_type. Storing comma-separated
-- text in a single column is a 1NF violation (not atomic); this is
-- the fix.
CREATE TABLE tag (
    tag_id      SERIAL PRIMARY KEY,
    tag_text    TEXT NOT NULL,
    tag_type    TEXT NOT NULL CHECK (tag_type IN ('primary_concern', 'ai_tag')),
    UNIQUE (tag_text, tag_type)
);

CREATE TABLE active_tag (
    active_id   INT NOT NULL REFERENCES active(active_id) ON DELETE CASCADE,
    tag_id      INT NOT NULL REFERENCES tag(tag_id),
    PRIMARY KEY (active_id, tag_id)
);

-- 8. Source documents ("Source file" column, semicolon-separated PDFs) --
CREATE TABLE source_document (
    doc_id      SERIAL PRIMARY KEY,
    filename    TEXT NOT NULL UNIQUE
);

CREATE TABLE active_source_document (
    active_id   INT NOT NULL REFERENCES active(active_id) ON DELETE CASCADE,
    doc_id      INT NOT NULL REFERENCES source_document(doc_id),
    PRIMARY KEY (active_id, doc_id)
);

-- 9. Compatibility (from the "Compatibility" matrix sheet) --------------
-- The sheet is a single sparse Base/Active x Base/Active grid holding
-- two different relationships. They are split into two tables because
-- they relate different entity pairs and have different meaning:
CREATE TABLE base_active_compatibility (
    base_id         INT NOT NULL REFERENCES base(base_id),
    active_id       INT NOT NULL REFERENCES active(active_id) ON DELETE CASCADE,
    is_compatible   BOOLEAN NOT NULL,
    PRIMARY KEY (base_id, active_id)
);

CREATE TABLE active_incompatibility (
    active_id_low   INT NOT NULL REFERENCES active(active_id) ON DELETE CASCADE,
    active_id_high  INT NOT NULL REFERENCES active(active_id) ON DELETE CASCADE,
    is_compatible   BOOLEAN NOT NULL DEFAULT FALSE,
    note            TEXT,
    PRIMARY KEY (active_id_low, active_id_high),
    CHECK (active_id_low < active_id_high)   -- store each unordered pair once
);

-- ---------------------------------------------------------------------
-- PART 2 — OPERATIONAL TABLES (proposed extension, not in the workbook)
-- Included so the catalog above is actually usable by the pipeline
-- described earlier (photo + questionnaire -> concern scores ->
-- formulation -> audit log). Drop this part if you only need the
-- static catalog.
-- ---------------------------------------------------------------------

CREATE TABLE customer_session (
    session_id      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    consent_given   BOOLEAN NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Fills in what "anodiam_user_skin_concern_score" was templated for:
-- one row per session per detected concern.
CREATE TABLE session_skin_concern_score (
    session_id       UUID NOT NULL REFERENCES customer_session(session_id) ON DELETE CASCADE,
    skin_concern_id  TEXT NOT NULL REFERENCES skin_concern(skin_concern_id),
    score            NUMERIC(5,2) NOT NULL,
    detected_by      TEXT NOT NULL CHECK (detected_by IN ('selfie', 'questionnaire', 'both')),
    PRIMARY KEY (session_id, skin_concern_id)
);

CREATE TABLE formulation (
    formulation_id    SERIAL PRIMARY KEY,
    session_id        UUID NOT NULL REFERENCES customer_session(session_id) ON DELETE CASCADE,
    base_id            INT NOT NULL REFERENCES base(base_id),
    total_cost         NUMERIC(10,4),
    explanation_text    TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE formulation_active (
    formulation_id   INT NOT NULL REFERENCES formulation(formulation_id) ON DELETE CASCADE,
    active_id        INT NOT NULL REFERENCES active(active_id),
    grams_per_100g   NUMERIC(6,3) NOT NULL,
    cost             NUMERIC(10,4),
    PRIMARY KEY (formulation_id, active_id)
);

CREATE TABLE audit_log (
    audit_id     BIGSERIAL PRIMARY KEY,
    session_id   UUID REFERENCES customer_session(session_id) ON DELETE SET NULL,
    event_type   TEXT NOT NULL,     -- e.g. 'concern_detection', 'active_retrieval'
    payload      JSONB NOT NULL,    -- why flagged/retrieved/excluded, per the explainability log
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------
-- Helpful indexes
-- ---------------------------------------------------------------------
CREATE INDEX idx_active_benefit_score_benefit ON active_benefit_score(benefit_id);
CREATE INDEX idx_active_tag_tag              ON active_tag(tag_id);
CREATE INDEX idx_session_concern_session     ON session_skin_concern_score(session_id);
CREATE INDEX idx_formulation_session         ON formulation(session_id);
CREATE INDEX idx_audit_log_session           ON audit_log(session_id);
