%% ================================================================
% Partial Dependence Panels for Medians & Trends (Figs 3 & 4)
% Inputs: data/*.csv, outputs/TopPredictors.mat, outputs/Importance_*.csv
% Outputs: figures/Fig3_PDP_Medians.*, figures/Fig4_PDP_Trends.*
% ================================================================
clear; clc;

dataMed = readtable(fullfile('data','medians_standardized.csv'));
dataTrn = readtable(fullfile('data','trends_standardized.csv'));
S = load(fullfile('outputs','TopPredictors.mat'));
figDir = 'figures'; if ~exist(figDir,'dir'); mkdir(figDir); end

cmap = parula(256);

function plotPanel(T, resp, key, preds, impFile, outName)
  cmap = parula(256);
  Timp = readtable(impFile);  % columns: Predictor, DeltaR2, RelImportance
  [~,loc] = ismember(preds(:), Timp.Predictor);
  imp = Timp.RelImportance(loc);
  imp = imp ./ max(imp);     % 0–1

  f = figure('Color','w','Position',[80 80 1600 700]);
  tiledlayout(3,8,'TileSpacing','compact','Padding','compact');
  colormap(cmap);

  for i = 1:3
    % row per response? here resp is one, so only one block -> we replicate pattern:
  end

  % 1) histogram
  ax1 = nexttile([1 2]);
  v = T.(resp);
  xLo = prctile(v,5); xHi = prctile(v,95);
  histogram(ax1, v, 'FaceColor',[.7 .7 .7],'EdgeColor','none');
  xlim(ax1,[xLo xHi]); grid(ax1,'on');
  title(ax1, sprintf('%s distribution', strrep(resp,'_','\_')),'FontSize',10);
  ylabel(ax1,'# cities'); xlabel(ax1, strrep(resp,'_','\_'));

  % 2) PDPs
  mdl = fitlm(T, sprintf('%s ~ %s', resp, strjoin(preds,' + ')));
  for j = 1:numel(preds)
    ax = nexttile([1 1]);
    ax.Color = cmap(max(min(round(imp(j)*255)+1,256),1),:);
    vpred = T.(preds{j});
    xLo2 = prctile(vpred,5); xHi2 = prctile(vpred,95);
    x    = linspace(xLo2,xHi2,120)';
    M    = mean(T{:,preds},1,'omitnan');
    P    = array2table(repmat(M,120,1),'VariableNames',preds);
    P.(preds{j}) = x;
    [yHat, yCI] = predict(mdl, P, 'Alpha',0.05,'Prediction','curve');

    hold(ax,'on');
      plot(ax,x,yHat,'k-','LineWidth',1.5);
      fill(ax,[x;flipud(x)],[yCI(:,1);flipud(yCI(:,2))], ...
           'k','FaceAlpha',0.18,'EdgeColor','none');
    hold(ax,'off'); grid(ax,'on');
    title(ax, sprintf('Imp=%.2f', imp(j)),'FontSize',9);
    xlabel(ax, strrep(preds{j},'_','\_'));
    if j==1, ylabel(ax, strrep(resp,'_','\_')); end
  end

  sgtitle(strrep(key,'_','\_'), 'FontWeight','bold');
  exportgraphics(f, fullfile(figDir,[outName '.png']), 'Resolution', 300);
  exportgraphics(f, fullfile(figDir,[outName '.svg']));
end

% ---------- Medians (Fig 3) ----------
pairsMed = { 'NDVI_median','mean_NDVI_raw'; ...
             'LST_median','mean_LST_raw'; ...
             'VegCool_median','VegetativeCooling'};

for i = 1:size(pairsMed,1)
  key  = pairsMed{i,1}; resp = pairsMed{i,2};
  preds = S.TopPredictors.(key)(:).';
  impFile = fullfile('outputs', ['Importance_' key '.csv']);
  plotPanel(dataMed, resp, key, preds, impFile, ['Fig3_PDP_' key]);
end

% ---------- Trends (Fig 4) ----------
pairsTr = { 'NDVI_trend','mean_NDVI_raw'; ...
            'LST_trend','mean_LST_raw'; ...
            'VegCool_trend','VegetativeCooling'};

for i = 1:size(pairsTr,1)
  key  = pairsTr{i,1}; resp = pairsTr{i,2};
  preds = S.TopPredictors.(key)(:).';
  impFile = fullfile('outputs', ['Importance_' key '.csv']);
  plotPanel(dataTrn, resp, key, preds, impFile, ['Fig4_PDP_' key]);
end
