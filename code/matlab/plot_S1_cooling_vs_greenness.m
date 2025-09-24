%% ================================================================
%  Figure S1: Cooling scales nonlinearly with greenness
%  Panels:
%    A) LOESS fit with 95% bootstrap CI (city medians)
%    B) GAM partial dependence of VegetativeCooling on NDVI (with City)
%
%  Inputs (CSV or MAT) in ./data:
%    - A_HYPO_RAW_MEDIANS.{csv|mat} with columns:
%        mean_NDVI_raw, VegetativeCooling
%    - A_HYPO_TABLE_FULL.{csv|mat} with columns:
%        mean_NDVI_raw, VegetativeCooling, City (optional)
%
%  Outputs:
%    ./figures/FigS1_cooling_vs_greenness.png (and .svg)
%    ./outputs/FigS1_curves_panelA.csv  (xi, mu, lo, hi)
%    ./outputs/FigS1_curves_panelB.csv  (xq, mu, lo, hi)
%
%  Requires: Statistics and Machine Learning Toolbox
% ================================================================

clear; clc;
rng(42);  % reproducibility for bootstraps

%% ---------------- User paths ----------------
dataDir   = 'data';
outFigDir = 'figures';
outTabDir = 'outputs';
if ~exist(outFigDir,'dir'); mkdir(outFigDir); end
if ~exist(outTabDir,'dir'); mkdir(outTabDir); end

fileMed  = fullfile(dataDir,'A_HYPO_RAW_MEDIANS.csv');     % or .mat
fileFull = fullfile(dataDir,'A_HYPO_TABLE_FULL.csv');      % or .mat

%% ---------------- Load data helper ----------------
loadTable = @(p) ...
  ( ...
    @(fext) ...
      (strcmpi(fext,'.csv') * readtable(p) + ...
       strcmpi(fext,'.mat') * ( ...
          (function() ...
             S = load(p); fn = fieldnames(S); T = S.(fn{1}); T; ...
           end)() ) ) ...
  )(lower(extractAfter(p, strfind(p,'.', 'last'))));

% Fallback to .mat if .csv missing
if ~isfile(fileMed),  fileMed  = strrep(fileMed,'.csv','.mat');  end
if ~isfile(fileFull), fileFull = strrep(fileFull,'.csv','.mat'); end

Tmed = loadTable(fileMed);
Tall = loadTable(fileFull);

%% ---------------- Assertions & coercions ----------------
needA = {'mean_NDVI_raw','VegetativeCooling'};
assert(all(ismember(needA, Tmed.Properties.VariableNames)), ...
  'A_HYPO_RAW_MEDIANS must contain: %s', strjoin(needA,', '));
Tmed = rmmissing(Tmed(:,needA));

needB = {'mean_NDVI_raw','VegetativeCooling'};
hasCity = ismember('City', Tall.Properties.VariableNames);
keepB = needB;
if hasCity, keepB{end+1} = 'City'; end
Tall = rmmissing(Tall(:,keepB));
if hasCity, Tall.City = categorical(Tall.City); end

xA = Tmed.mean_NDVI_raw;           yA = Tmed.VegetativeCooling;
xAll = Tall.mean_NDVI_raw;

%% ---------------- Panel A: LOESS + bootstrap CI -------------
span = 0.30;     % loess span
B    = 500;      % bootstrap reps
xiA  = linspace(min(xA), max(xA), 200)';

% Sort & smooth
[xs, ord] = sort(xA(:)); ys = yA(:); ys = ys(ord);
yhat = smooth(xs, ys, span, 'loess');

% Interpolate to common grid with unique x
[xsu, ia] = unique(xs, 'stable');  yhat_u = yhat(ia);
ybase     = interp1(xsu, yhat_u, xiA, 'linear', 'extrap');

% Bootstrap loess curves
nA = numel(xA);
bootCurves = zeros(numel(xiA), B);
for b = 1:B
  id = randsample(nA, nA, true);
  xb = xA(id); yb = yA(id);
  [xsb, ordb] = sort(xb(:)); ysb = yb(:); ysb = ysb(ordb);
  yhatb = smooth(xsb, ysb, span, 'loess');
  [xsb_u, iab] = unique(xsb, 'stable');
  bootCurves(:,b) = interp1(xsb_u, yhatb(iab), xiA, 'linear', 'extrap');
end
muA = mean(bootCurves, 2);
loA = prctile(bootCurves, 2.5,  2);
hiA = prctile(bootCurves, 97.5, 2);

% Correlations
[rP,pP] = corr(xA, yA, 'Type','Pearson','Rows','complete');
[rS,pS] = corr(xA, yA, 'Type','Spearman','Rows','complete');

%% ---------------- Panel B: GAM partial dependence -----------
% Model with/without city effect
if hasCity
  M = fitrgam(Tall, 'VegetativeCooling ~ mean_NDVI_raw + City', ...
              'CategoricalPredictors','City');
else
  M = fitrgam(Tall, 'VegetativeCooling ~ mean_NDVI_raw');
end

xq = linspace(min(xAll), max(xAll), 250)';
[pd0, ~] = partialDependence(M, 'mean_NDVI_raw', 'QueryPoints', xq);

% Bootstrap PD curve
B2 = 200; nAll = height(Tall);
pdBoot = zeros(numel(xq), B2);
for b = 1:B2
  idx = randsample(nAll, nAll, true);
  Tb = Tall(idx,:);
  if hasCity
    Mb = fitrgam(Tb, 'VegetativeCooling ~ mean_NDVI_raw + City', ...
                 'CategoricalPredictors','City');
  else
    Mb = fitrgam(Tb, 'VegetativeCooling ~ mean_NDVI_raw');
  end
  pdBoot(:,b) = partialDependence(Mb, 'mean_NDVI_raw', 'QueryPoints', xq);
end
muB = mean(pdBoot, 2);
loB = prctile(pdBoot, 2.5,  2);
hiB = prctile(pdBoot, 97.5, 2);

%% ---------------- Plot -------------------------
f = figure('Color','w','Position',[100 100 1350 420]);
tiledlayout(1,2,'Padding','compact','TileSpacing','compact');

% A: Cross-sectional association
nexttile; hold on;
scatter(xA, yA, 22, [.2 .2 .2], 'filled', ...
        'MarkerFaceAlpha', 0.6, 'MarkerEdgeColor','none');
fill([xiA; flipud(xiA)], [loA; flipud(hiA)], [0.75 0.85 1], ...
     'EdgeColor','none','FaceAlpha',0.35);
plot(xiA, muA, 'b-', 'LineWidth', 2);
xlabel('NDVI (city median)');
ylabel('Vegetative cooling (LST–NDVI slope, ^\circC / NDVI)');
title('A. Cross-sectional association');
grid on; box on;
yl = ylim;
text(min(xA)+0.02*range(xA), yl(2)-0.05*range(yl), ...
  sprintf('Pearson r = %.2f (p < %.3g)\\nSpearman \\rho = %.2f (p < %.3g)', ...
          rP, pP, rS, pS), ...
  'VerticalAlignment','top','FontSize',10,'BackgroundColor','w');

% B: GAM partial dependence
nexttile; hold on;
fill([xq; flipud(xq)], [loB; flipud(hiB)], [0.85 1 0.85], ...
     'EdgeColor','none','FaceAlpha',0.35);
plot(xq, muB, 'g-', 'LineWidth', 2);
% Rug for NDVI distribution
yl = ylim; y0 = yl(1) + 0.02*range(yl);
plot(xAll, repmat(y0, numel(xAll),1), 'k|', 'MarkerSize', 4, 'Color',[0 0 0 0.25]);
ylim(yl);
xlabel('NDVI');
ylabel('Predicted vegetative cooling (^\circC / NDVI)');
title(hasCity * "B. GAM partial dependence (with city effects)" + ...
     ~hasCity * "B. GAM partial dependence");
grid on; box on;

sgtitle('Cooling scales nonlinearly with greenness','FontWeight','bold');

% Save figure
exportgraphics(f, fullfile(outFigDir,'FigS1_cooling_vs_greenness.png'), 'Resolution', 300);
exportgraphics(f, fullfile(outFigDir,'FigS1_cooling_vs_greenness.svg'));

%% ---------------- Save curves (for full reproducibility) ----
writetable(table(xiA, muA, loA, hiA, ...
  'VariableNames',{'xi','mu','lo','hi'}), ...
  fullfile(outTabDir,'FigS1_curves_panelA.csv'));

writetable(table(xq,  muB, loB, hiB, ...
  'VariableNames',{'xq','mu','lo','hi'}), ...
  fullfile(outTabDir,'FigS1_curves_panelB.csv'));
