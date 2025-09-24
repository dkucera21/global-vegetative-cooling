%% ================================================================
% Drop-one ΔR² importance for each top-7 set (medians & trends)
% Outputs: outputs/Importance_*.csv
% ================================================================
clear; clc;

dataMed = readtable(fullfile('data','medians_standardized.csv'));
dataTrn = readtable(fullfile('data','trends_standardized.csv'));
S = load(fullfile('outputs','TopPredictors.mat'));  % TopPredictors struct

targets = { ...
  'NDVI_median','mean_NDVI_raw', dataMed; ...
  'LST_median','mean_LST_raw',   dataMed; ...
  'VegCool_median','VegetativeCooling', dataMed; ...
  'NDVI_trend','mean_NDVI_raw',  dataTrn; ...
  'LST_trend','mean_LST_raw',    dataTrn; ...
  'VegCool_trend','VegetativeCooling', dataTrn};

for i = 1:size(targets,1)
  key  = targets{i,1};
  resp = targets{i,2};
  T    = targets{i,3};

  preds = S.TopPredictors.(key)(:).';
  tblSel = T(:, [preds, {resp}]);
  tblSel.Properties.VariableNames{end} = 'y';

  mdlFull = fitlm(tblSel, sprintf('y ~ %s', strjoin(preds,' + ')));
  R2_full = mdlFull.Rsquared.Ordinary;

  dR2 = nan(numel(preds),1);
  for j = 1:numel(preds)
    keep = preds; keep(j) = [];
    mdlj = fitlm(tblSel, sprintf('y ~ %s', strjoin(keep,' + ')));
    dR2(j) = R2_full - mdlj.Rsquared.Ordinary;
  end
  relImp = dR2 / sum(dR2);

  Timp = table(preds(:), dR2, relImp, ...
          'VariableNames',{'Predictor','DeltaR2','RelImportance'});
  writetable(Timp, fullfile('outputs', ['Importance_' key '.csv']));
  fprintf('%s: saved outputs/Importance_%s.csv (R^2 full = %.3f)\n', key, key, R2_full);
end
