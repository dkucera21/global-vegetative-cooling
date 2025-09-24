%% ================================================================
% LASSO + Forward-Only Stepwise Selection (top-7 predictors)
% Adds per-response exclusion blocks.
% Outputs: outputs/TopPredictors.mat, outputs/FinalModels.mat, TopPredictors.csv
% ================================================================
clear; clc; rng(42);

dataDir = 'data'; outDir = 'outputs';
if ~exist(outDir,'dir'); mkdir(outDir); end
Tmed = readtable(fullfile(dataDir,'medians_standardized.csv'));
Ttrn = readtable(fullfile(dataDir,'trends_standardized.csv'));

% ---------- Targets ----------
respList = { ...
  'NDVI_median',   'mean_NDVI_raw',    Tmed; ...
  'LST_median',    'mean_LST_raw',     Tmed; ...
  'VegCool_median','VegetativeCooling',Tmed};

respListTr = { ...
  'NDVI_trend',    'mean_NDVI_raw',    Ttrn; ...
  'LST_trend',     'mean_LST_raw',     Ttrn; ...
  'VegCool_trend', 'VegetativeCooling',Ttrn};

% ================================================================
% 1) MASTER (global) EXCLUSIONS
%    (robust to missing cols; prefixes handled below)
% ================================================================
MASTER_NEVER = string([ ...
  "City","Biome","Koppen","Stratum","Paradigm","Lineage","SPL_Code", ...
  "Longitude","Latitude","TravelTime", ...
  "VegCooling_stand","VegetativeCooling_standardized","VegetativeCooling_ru", ...
  "mean_LST_raw_stand","mean_LST_ru","mean_LST_stand", ...
  "SUHI_DAY_MEAN","SUHI_NIGHT_MEAN" ...
]);

% drop anything that CONTAINS any of these substrings (case-insensitive)
MASTER_CONTAINS_BLACKLIST = lower([ ...
  "mean_spei_", "slope_savi","slope_evi","coefvar","cv_", ...
  "chirts_", "surface_latent_heat_flux_sum","surface_net_solar_radiation_sum", ...
  "latent_flux","sensible_flux","net_solar_flux", ...
  "soil_temperature","volumetric_soil_water","potential_evaporation_max", ...
  "urbanization_builtsurface","urbanization_builtsurface_nres", ...
  "soil_", "ai_trend","map_z","sum_cumulative_00_months" ...
]);

% strip prefixes
MASTER_PREFIX_BLACKLIST = ["LC_","GLDAS_","GroupCount"];

% ================================================================
% 2) PER-RESPONSE EXCLUSIONS
%    (exact-name and substring lists; edit freely)
%    Keys are the RESPONSE column names.
% ================================================================
PER_NEVER = containers.Map( ...
  {'mean_NDVI_raw','mean_LST_raw','VegetativeCooling'}, ...
  { ...
    % When NDVI is the response, exclude greenness/greenness-derivatives
    string([ "mean_NDVI_raw","mean_mean_NDVI","mean_mean_EVI","mean_mean_SAVI", ...
             "mean_cv_NDVI","mean_cv_EVI","mean_cv_SAVI","tree_cover","ndvi_" ...
           ]), ...
    % When LST is the response, exclude LST-like or directly derived fields
    string([ "mean_LST_raw","mean_LST_ru","mean_LST_stand","lst_", ...
             "skin_temperature" ...
           ]), ...
    % When VegetativeCooling (LST~NDVI slope) is the response, exclude
    % direct components to avoid leakage
    string([ "VegetativeCooling","mean_NDVI_raw","mean_LST_raw", ...
             "mean_mean_NDVI","mean_mean_EVI","mean_mean_SAVI","lst_", "ndvi_" ...
           ]) ...
  } ...
);

PER_CONTAINS = containers.Map( ...
  {'mean_NDVI_raw','mean_LST_raw','VegetativeCooling'}, ...
  { ...
    lower([ "ndvi","evi","savi","tree","leaf_area_index" ]), ... % NDVI resp
    lower([ "lst","skin_temperature","land_surface_temperature" ]), ... % LST resp
    lower([ "ndvi","evi","savi","lst","skin_temperature" ])  ... % VegCool resp
  } ...
);

% ================================================================
% Helper: build predictor list honoring master + per-response blocks
% ================================================================
function preds = buildPredictors(T, responseName, MASTER_NEVER, MASTER_CONTAINS_BLACKLIST, MASTER_PREFIX_BLACKLIST, PER_NEVER, PER_CONTAINS)
  allVars = string(T.Properties.VariableNames);

  % start from everything but response itself
  keep = allVars(~strcmpi(allVars, responseName));

  % master exact-name drop
  keep = keep(~ismember(keep, MASTER_NEVER));

  % master substring drop
  drop = false(size(keep));
  lowKeep = lower(keep);
  for s = MASTER_CONTAINS_BLACKLIST
    drop = drop | contains(lowKeep, s);
  end
  keep = keep(~drop);

  % master prefix drop
  for p = MASTER_PREFIX_BLACKLIST
    keep = keep(~startsWith(keep, p));
  end

  % per-response exact-name drop
  if PER_NEVER.isKey(responseName)
    keep = keep(~ismember(keep, PER_NEVER(responseName)));
  end

  % per-response substring drop
  if PER_CONTAINS.isKey(responseName)
    drop = false(size(keep));
    lowKeep = lower(keep);
    for s = PER_CONTAINS(responseName)
      drop = drop | contains(lowKeep, s);
    end
    keep = keep(~drop);
  end

  preds = cellstr(keep);
end

% ================================================================
% Core selector (LASSO → forward stepwise to 7)
% ================================================================
function [top7, mdlFinal, lassoKeep] = selectTop7(T, responseName, preds)
  X = zscore(T{:, preds});  % z-score predictors
  y = T{:, responseName};

  if isempty(gcp('nocreate')), try, parpool; catch, end, end
  usePar = ~isempty(gcp('nocreate'));
  opts   = statset('UseParallel', usePar);

  [B,FitInfo] = lasso(X, y, 'CV',5, 'Alpha',1, 'Standardize',false, 'Options',opts);
  coef = B(:, FitInfo.IndexMinMSE);
  lassoKeep = preds(coef~=0);
  if isempty(lassoKeep)
    error('LASSO retained 0 predictors for %s. Relax exclusions or check data.', responseName);
  end

  T2 = T; T2.y = y;
  upperForm = sprintf('y ~ %s', strjoin(lassoKeep,' + '));
  mdlStep = stepwiselm(T2, 'y ~ 1', 'Upper',upperForm, ...
            'PEnter',0, 'PRemove',-Inf, 'NSteps',7, ...
            'Criterion','rsquared','Verbose',0);

  cand = setdiff(mdlStep.PredictorNames,'(Intercept)','stable');
  if numel(cand) < 7
    warning('%s: stepwise added %d < 7; using all.', responseName, numel(cand));
    top7 = cand;
  else
    top7 = cand(1:7);
  end

  mdlFinal = fitlm(T, sprintf('%s ~ %s', responseName, strjoin(top7,' + ')));
end

% ================================================================
% Run for medians
% ================================================================
TopPredictors = struct(); FinalModels = struct(); LassoKept = struct();

for i = 1:size(respList,1)
  key  = respList{i,1};
  resp = respList{i,2};
  T    = respList{i,3};

  preds = buildPredictors(T, resp, MASTER_NEVER, MASTER_CONTAINS_BLACKLIST, MASTER_PREFIX_BLACKLIST, PER_NEVER, PER_CONTAINS);
  [top7, mdlF, lkeep] = selectTop7(T, resp, preds);

  TopPredictors.(key) = top7;
  FinalModels.(key)   = mdlF;
  LassoKept.(key)     = lkeep;
  fprintf('%s | Final OLS R^2 = %.3f (adj %.3f) | pool = %d | LASSO = %d\n', ...
          key, mdlF.Rsquared.Ordinary, mdlF.Rsquared.Adjusted, numel(preds), numel(lkeep));
end

% ================================================================
% Run for trends
% ================================================================
for i = 1:size(respListTr,1)
  key  = respListTr{i,1};
  resp = respListTr{i,2};
  T    = respListTr{i,3};

  preds = buildPredictors(T, resp, MASTER_NEVER, MASTER_CONTAINS_BLACKLIST, MASTER_PREFIX_BLACKLIST, PER_NEVER, PER_CONTAINS);
  [top7, mdlF, lkeep] = selectTop7(T, resp, preds);

  TopPredictors.(key) = top7;
  FinalModels.(key)   = mdlF;
  LassoKept.(key)     = lkeep;
  fprintf('%s | Final OLS R^2 = %.3f (adj %.3f) | pool = %d | LASSO = %d\n', ...
          key, mdlF.Rsquared.Ordinary, mdlF.Rsquared.Adjusted, numel(preds), numel(lkeep));
end

% Save
save(fullfile(outDir,'TopPredictors.mat'),'TopPredictors','LassoKept');
save(fullfile(outDir,'FinalModels.mat'),'FinalModels');

% human-readable CSV
F = fieldnames(TopPredictors);
rows = cellfun(@(k) {k, strjoin(TopPredictors.(k),', ')}, F, 'uni',0);
struct2table(cell2struct(rows, {'Target','Top7'}, 2)).writetable(fullfile(outDir,'TopPredictors.csv'));