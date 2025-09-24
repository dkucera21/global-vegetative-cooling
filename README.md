# Global Weakening of Urban Vegetative Cooling (1990–2024)

Reproducible code and data workflow for the manuscript **Global Weakening of Urban Vegetative Cooling (1990–2024)**.

- **Scope:** 311 cities worldwide; 1990–2024 warm seasons (May–Sep NH, Nov–Mar SH)
- **Responses:** city‐level **NDVI**, **LST**, and **vegetative cooling** (slope of LST ~ NDVI; °C per NDVI), summarized as long-term **means** and **trends**
- **Sources:** Landsat C2 L2 (L4/5/7/8/9), TerraClimate, ERA5-Land, GHSL, GPW, YCEO SUHI
- **Toolchain:** Google Earth Engine (JavaScript) for data extraction; MATLAB R2024b for analysis & figures

---

## Repository Layout
global-vegetative-cooling/
├─ README.md
├─ LICENSE
├─ data/                         # CSV/GeoTIFF inputs created by GEE exports
│  ├─ medians_standardized.csv
│  ├─ trends_standardized.csv
│  └─ (other .csv/.tif produced by GEE)
├─ code/
│  ├─ gee/                       # GEE JavaScript (run in the Code Editor)
│  │  ├─ landsat_ndvi_lst.js
│  │  ├─ terraclimate_aridity_index.js
│  │  ├─ terraclimate_cumulative_precip.js
│  │  ├─ era5_monthly_timeseries.js
│  │  ├─ spei_extract.js
│  │  ├─ yceo_summer_uhi_means.js
│  │  └─ ghsl_built_env_population.js
│  └─ matlab/
│     ├─ run_feature_selection.m
│     ├─ compute_importance.m
│     ├─ plot_partial_dependence.m
│     ├─ figure_S1_gam_ndvi_vs_cooling.m
│     ├─ figure_S2_medians_biome_koppen.m
│     └─ figure_S3_trends_biome_koppen.m
├─ outputs/
│  ├─ TopPredictors.mat
│  ├─ TopPredictors.csv
│  ├─ FinalModels.mat
│  └─ figures/ (PNG/PDF exports)
└─ docs/
   └─ CITATION.cff


---

## Prerequisites

### Google Earth Engine
- Active account and access to the public datasets listed below.
- Provide a folder of **city boundary FeatureCollections** (one per city) or a single multi-feature collection.
- In each `.js` script, set your asset path and Google Drive export folder.

### MATLAB R2024b (or ≥ R2022a)
- **Toolboxes:** *Statistics and Machine Learning* (required; `fitrgam` used in Fig S1). *Curve Fitting* optional.
- **Memory:** enough to load city-level tables (MBs to tens of MBs).

### Storage
- Several GB if you keep all GeoTIFFs; CSV exports are much smaller.

---

## Data Inputs Created by GEE
*(Export to Google Drive, then place under `/data/`.)*

### A) City-level rasters (composites by city and year/period)
- **Landsat:** NDVI and LST (°C) composites.
- **GHSL:** built volume, built surface (total and non-residential), population counts/density.
- *(Optional)* **WSF** settlement footprint.

### B) City-level CSV time series
- **ERA5-Land** monthly means for selected variables (per city).
- **TerraClimate** cumulative precipitation windows (1–12 months) per month.
- **Aridity Index (AI)** = precipitation / PET (monthly).
- **SPEI** multi-scale band means.
- **YCEO SUHI** day/night annual means (2003–2018).

### C) Two analysis-ready CSV tables (assembled from exports)
- `data/medians_standardized.csv` — city medians (1990–2024) of responses & predictors  
- `data/trends_standardized.csv` — city slopes (1990–2024) of responses & predictors

**Notes**
- **Responses:** `mean_NDVI_raw`, `mean_LST_raw`, `VegetativeCooling` (slope of LST~NDVI; °C per NDVI).
- **Predictors:** per Methods (SRTM, TerraClimate, ERA5, GHSL, SUHI, cumulative precip logs, etc.).
- Standardize numeric predictors (z-score) as in MATLAB scripts, *or* feed raw and let scripts standardize.

---

## Google Earth Engine Scripts (in `code/gee/`)
Each script has a repository-ready header and placeholders to edit.

### `landsat_ndvi_lst_stacks.js`
- QA masking; reflectance harmonization across L4/5/7/8/9 (Roy et al., 2016; L9 treated like L8)
- Builds warm-season mosaics, filters by valid-pixel fraction, computes NDVI and converts ST to °C
- Excludes Landsat-7 after **2003-05-31** (SLC-off)
- Exports per-city NDVI/LST composites (Cloud-Optimized GeoTIFFs)
- **Edit:** `ASSET_FOLDER` (your FeatureCollections), `OUTPUT_FOLDER` (Drive), `fracKeep` if desired

### `terraclimate_cumulative_precip.js`
- For each month/year, computes cumulative precipitation over 1–12 months
- Exports per-city CSV with columns `cumulative_00_months` … `cumulative_12_months`
- Supports later **log-transform** for saturating responses

### `terraclimate_aridity_index.js`
- Monthly **AI = pr / pet** from TerraClimate; exports per-city CSV

### `era5_monthly_timeseries.js`
- Extracts monthly means for selected ERA5-Land variables; exports per-city CSV with a `date` column

### `spei_extract.js`
- Averages SPEI bands over each city; exports per-city CSV

### `yceo_summer_uhi_means.js`
- Exports SUHI (day/night) annual means by city (2003–2018) as CSV

### `ghsl_built_env_population.js`
- Exports GHSL built volume/surfaces and population stacks as multi-band GeoTIFFs  
- *Note:* Köppen layer removed (not a GEE collection)

**General**
- Replace **`ASSET_FOLDER`** and **`OUTPUT_FOLDER`** placeholders.
- If boundaries are a single multi-feature collection, iterate features instead of listing assets.
- Prefer **Cloud-Optimized GeoTIFF** for large rasters.

---

## Data Sources (GEE collection IDs / descriptions)

- **Landsat C2 L2 Surface Reflectance + ST:** `LANDSAT/LT04…`, `LT05…`, `LE07…`, `LC08…`, `LC09…`
- **TerraClimate monthly:** `IDAHO_EPSCOR/TERRACLIMATE` (VPD, PET, AET, DEF, pr, tmmn, tmmx, srad, etc.)
- **ERA5-Land monthly aggregates:** `ECMWF/ERA5_LAND/MONTHLY_AGGR`
- **SPEI:** `CSIC/SPEI/2_10`
- **Yale YCEO SUHI:** `YALE/YCEO/UHI/Summer_UHI_yearly_pixel/v4`
- **GHSL 2023A series:** `JRC/GHSL/P2023A/GHS_BUILT_V`, `…/GHS_BUILT_S`, `…/GHS_BUILT_C`, `…/GHS_POP`, `…/GHS_SMOD`
- **Population (GPW v4.11):** `CIESIN/GPWv411/GPW_Population_Count`, `…/GPW_UNWPP-Adjusted_Population_Density`
- **SRTM DEM:** `USGS/SRTMGL1_003`

---

## Reproduction Steps (Quick Start)

### 1) In GEE
1. Open each `.js` in `code/gee/`.
2. Set `ASSET_FOLDER` (your city boundaries) and `OUTPUT_FOLDER` (Drive export folder).
3. Run exports (multiple tasks).  
   Download finished outputs and place under **`/data/`** (or sync via Drive).

### 2) Build analysis tables
Combine per-city exports into:

data/medians_standardized.csv
data/trends_standardized.csv


Include at minimum:
- **Responses:** `mean_NDVI_raw`, `mean_LST_raw`, `VegetativeCooling`
- **Predictors:** elevation/terrain, TerraClimate + AI, **cumulative precip logs**, ERA5 fields, GHSL built metrics, SUHI, population, etc.

Standardize numeric columns (z-score) if not done in MATLAB scripts.

### 3) In MATLAB
- **Feature selection & models:** `code/matlab/run_feature_selection.m`  
  - 5-fold **LASSO → forward-only stepwise** to top-7 predictors per response (means & trends)  
  - Uses **global** and **per-response** exclusion lists to prevent leakage/implausible predictors  
  - Saves: `outputs/TopPredictors.mat`, `outputs/TopPredictors.csv`, `outputs/FinalModels.mat`
- **Relative importance (ΔR²):** `code/matlab/compute_importance.m`  
  - Fits final OLS per response; computes drop-one ΔR²; normalizes to get relative importance  
  - Saves `Importance_*` tables in `/outputs/`
- **Partial dependence plots:** `code/matlab/plot_partial_dependence.m`  
  - Generates tiled PDPs (spatial means & temporal trends) with 95% CIs  
  - Colors tiles by normalized importance; **Biome/Köppen excluded** from PDP fits  
  - Saves figures under `outputs/figures/`
- **Optional supplementary figures**
  - `figure_S1_gam_ndvi_vs_cooling.m` — nonlinear cooling–NDVI (LOESS + GAM PD)  
  - `figure_S2_medians_biome_koppen.m` — medians by Biome & Köppen (significance letters)  
  - `figure_S3_trends_biome_koppen.m` — trends by Biome & Köppen (significance letters)

---

## Key Methodological Choices (mirrors manuscript)

- **Vegetative cooling:** slope of **LST ~ NDVI** within warm-season stacks per city (Δ°C per ΔNDVI); more negative = stronger cooling.
- **Harmonization:** L4–L7 reflectance harmonized to L8 style (Roy et al., 2016); L9 treated like L8 due to near-identical sensors.
- **Thermal:** Landsat ST (C2 L2) → °C via scale/offset; strict QA masking + **dynamic date filtering** by valid pixels.
- **Cumulative precipitation:** month-specific cumulative sums (1–12 months) averaged across years; **log-transform** used in models to capture diminishing returns.
- **Aridity Index:** TerraClimate **AI = pr / pet** (monthly).
- **Modeling:** LASSO → stepwise to 7 predictors → final OLS → ΔR² importance → PDPs (others held at sample means).
- **GAM (Fig S1):** partial dependence of cooling on NDVI with optional city factor.

---

## Placeholders You Must Edit

- **In all GEE `.js` files**
  - `ASSET_FOLDER` — your GEE path containing city polygons  
  - `OUTPUT_FOLDER` — your Google Drive folder for exports
- **In MATLAB**
  - Any hard-coded paths to `/data/` and `/outputs/`  
  - `EXCLUDE_BY_RESPONSE` blocks in `run_feature_selection.m` (tune for collinearity/plausibility)

---

## Configuration Knobs

- GEE date windows by hemisphere (`calendarRange`), QA logic, and valid-pixel threshold (`fracKeep`).
- Which ERA5 variables to extract; which cumulative windows to compute/export.
- MATLAB exclusion lists (global + per-response).
- Number of LASSO CV folds (default 5) and maximum stepwise steps (default 7).

---

## Notes & Best Practices

- Keep **raw exports immutable**; create derived, standardized tables for analysis.
- SUHI covers **2003–2018**; treat as a covariate with its native period.
- Document any city additions/removals in `docs/changelog.txt`.
- Prefer **Cloud-Optimized GeoTIFF** exports for large rasters.
- Archive a tagged release to **Zenodo** to mint a DOI for the repository.

---

## Software & Accounts

- **Google Earth Engine:** <https://earthengine.google.com>  
- **MATLAB** R2024b (or ≥ R2022a) with Statistics and Machine Learning Toolbox  
- *(Optional)* Git/GitHub for versioning

---

## Citations (examples)

- Gorelick et al., 2017 (GEE)  
- USGS/EROS Landsat C2 L2 documentation (2020a–c)  
- Roy et al., 2016; Gross et al., 2022; Masek et al., 2020 (harmonization / L8–L9 continuity)  
- Abatzoglou et al., 2018 (TerraClimate)  
- Hersbach et al., 2023 (ERA5-Land)  
- Farr et al., 2007 (SRTM)  
- Chakraborty & Lee, 2019 (YCEO SUHI)  
- Pesaresi & Politis, 2023; JRC GHSL docs (GHSL)  
- Tibshirani, 1996/2018; Grömping, 2006; Nathans et al., 2012 (LASSO & variable importance)

*(Include full references in your manuscript or `docs/CITATION.cff`.)*

---

## Data & Code Availability

- **Inputs:** all from public, trusted repositories via GEE (see *Data Sources*).
- **Outputs:** place per-city CSVs and GeoTIFFs under `/data/`.
- **Code:** all GEE and MATLAB scripts are provided.  
  When ready, archive a release to **Zenodo** and add the DOI below.

**How to cite this repository (example)**  
Kucera, D., & Jenerette, G. D. (2025). *Global Weakening of Urban Vegetative Cooling (1990–2024): Code and Data.* Version X.Y. DOI: `<add Zenodo DOI here once archived>`.

---

## License

- **Code:** MIT (or your preferred OSI license).  
- **Data products:** may inherit licensing from original sources—please respect provider terms.

---

## Contact

- **Maintainer:** Dion Kucera (University of California, Riverside)  
- **Issues / questions:** open a GitHub Issue or email `<your email here>`

---

## Quick Start (TL;DR)

1. Set `ASSET_FOLDER` and `OUTPUT_FOLDER` in each `code/gee/*.js`; run exports to Drive.  
2. Download exports → build `data/medians_standardized.csv` and `data/trends_standardized.csv`.  
3. In MATLAB, run:

run_feature_selection
compute_importance
plot_partial_dependence
figure_S1_gam_ndvi_vs_cooling
figure_S2_medians_biome_koppen
figure_S3_trends_biome_koppen

4. Find results under `/outputs/` and `/outputs/figures/`.