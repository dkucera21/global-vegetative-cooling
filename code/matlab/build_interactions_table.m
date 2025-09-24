%% ================================================================
% Build squared + interaction terms for chosen predictors
% Input: data/medians_standardized.csv (or trends_standardized.csv)
%        outputs/TopPredictors.mat
% Output: outputs/medians_with_interactions.mat / .csv
% ================================================================
clear; clc;

dataFile = fullfile('data','medians_standardized.csv');  % change to trends file if needed
T = readtable(dataFile);

S = load(fullfile('outputs','TopPredictors.mat'));  % contains struct TopPredictors
key = 'LST_median';                                 % <-- choose which set to expand
sel = S.TopPredictors.(key);

baseKeep = unique([{'City','Biome','Koppen'}, sel(:)'],'stable');
baseKeep = baseKeep(ismember(baseKeep, T.Properties.VariableNames));
Tout = T(:, baseKeep);

% add squared (z-scored) terms
for i = 1:numel(sel)
  v = sel{i}; if ~ismember(v, T.Properties.VariableNames), continue; end
  y = T.(v).^2;  y = (y-mean(y,'omitnan'))/std(y,[],'omitnan');
  Tout.(matlab.lang.makeValidName(v+"_sq")) = y;
end

% add pairwise interactions (z-scored)
for i = 1:numel(sel)
  vi = sel{i}; if ~ismember(vi,T.Properties.VariableNames), continue; end
  xi = T.(vi);
  for j = i+1:numel(sel)
    vj = sel{j}; if ~ismember(vj,T.Properties.VariableNames), continue; end
    xj = T.(vj);
    y  = xi.*xj; y = (y-mean(y,'omitnan'))/std(y,[],'omitnan');
    Tout.(matlab.lang.makeValidName(vi+"_x_"+vj)) = y;
  end
end

save(fullfile('outputs','medians_with_interactions.mat'),'Tout');
writetable(Tout, fullfile('outputs','medians_with_interactions.csv'));
fprintf('Wrote %d columns to outputs/medians_with_interactions.*\n', width(Tout));
