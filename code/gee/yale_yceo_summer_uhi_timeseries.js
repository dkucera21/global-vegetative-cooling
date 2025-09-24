/************************************************************
 * File: 07_yale_yceo_summer_uhi_timeseries.js
 * Purpose: Export a yearly summer UHI time series for each
 *          polygon in a user-supplied FeatureCollection.
 *
 * Dataset: YALE/YCEO/UHI/Summer_UHI_yearly_pixel/v4
 * Bands:   Daytime, Nighttime (units as provided by dataset)
 * Output:  One CSV per polygon with columns:
 *          year, suhi_day, suhi_night
 ************************************************************/

// ====================== USER PARAMETERS ======================

// 1) Polygons layer (upload your cities.gpkg/geojson to Assets and paste ID):
var POLYGONS_ASSET = 'users/<your-username>/cities311';   // <-- EDIT

// 2) Name/ID field in polygons (used for filenames):
var NAME_FIELD     = 'name';                               // <-- EDIT

// 3) Time window (years) for filtering the UHI collection:
var START_YEAR     = 2003;  // set to dataset coverage
var END_YEAR       = 2018;  // exclusive upper bound if you prefer filterDate

// 4) Export location and scale:
var OUTPUT_FOLDER  = 'YCEO_SUHI_TS_EXPORTS'; // Google Drive folder
var REDUCE_SCALE_M = 300;                    // YCEO product pixel size (approx)
var MAX_PIXELS     = 1e13;

// 5) Run all polygons or a single one by name?
var RUN_ALL        = true;
var POLY_TO_RUN    = 'Los_Angeles';          // used only if RUN_ALL=false


// ========================= LOAD DATA =========================

var polys = ee.FeatureCollection(POLYGONS_ASSET);
var fc    = RUN_ALL ? polys : polys.filter(ee.Filter.eq(NAME_FIELD, POLY_TO_RUN));

// Build a date range from years
var startDate = ee.Date.fromYMD(START_YEAR, 1, 1);
var endDate   = ee.Date.fromYMD(END_YEAR,   1, 1);

// Yale YCEO Summer UHI (yearly)
var suhiCol = ee.ImageCollection('YALE/YCEO/UHI/Summer_UHI_yearly_pixel/v4')
  .filterDate(startDate, endDate)  // keep to requested window
  .select(['Daytime', 'Nighttime'])
  .sort('system:time_start');

print('Polygons to process:', fc.size());
print('UHI yearly images selected:', suhiCol.size());


// ====================== EXPORT PER POLYGON ===================

var list = fc.toList(fc.size());
var N    = list.size().getInfo();

for (var i = 0; i < N; i++) {
  var feat = ee.Feature(list.get(i));
  var geom = ee.FeatureCollection([feat]).geometry();
  var name = ee.String(feat.get(NAME_FIELD));
  var safe = name.replace(' ', '_').replace('/', '_'); // filename-safe

  // For each year image, compute mean Day/Night UHI over the polygon
  var rows = suhiCol.map(function(img){
    var y     = ee.Date(img.get('system:time_start')).format('YYYY');
    var stats = img.clip(geom).reduceRegion({
      reducer:   ee.Reducer.mean(),
      geometry:  geom,
      scale:     REDUCE_SCALE_M,
      maxPixels: MAX_PIXELS,
      bestEffort: true
    });
    // Build a feature with year + both metrics
    return ee.Feature(null, {
      year:       y,
      suhi_day:   stats.get('Daytime'),
      suhi_night: stats.get('Nighttime')
    });
  })
  // keep only years with data
  .filter(ee.Filter.notNull(['suhi_day', 'suhi_night']));

  var desc = ee.String('YCEO_SUHI_TS_').cat(safe).getInfo();

  Export.table.toDrive({
    collection:    rows,
    description:   desc,
    fileNamePrefix: desc,
    folder:        OUTPUT_FOLDER,
    fileFormat:    'CSV',
    selectors:     ['year', 'suhi_day', 'suhi_night']
  });

  print('Queued export:', desc);
}


// ============================ NOTES ==========================
// • If the dataset’s valid years differ for your region, adjust START_YEAR/END_YEAR.
// • You can export a single combined table by adding the polygon name to each row
//   and exporting once; this script exports one CSV per polygon for clarity.
// • Document units/interpretation for Daytime/Nighttime in your repo README.
