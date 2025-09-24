%% ================================================================
%  Figure S3: Two-panel significance-annotated barplots (trends)
%  Inputs : CSV or MAT table with variables:
%           Biome, Koppen, mean_NDVI_raw, mean_LST_raw, VegetativeCooling
%           (columns hold the trend metrics you want to visualize)
%  Output : ./figures/FigS3_trend_bars.png (and .svg)
%           ./outputs/FigS3_trend_bars_summary.csv
%  Requires: Statistics and Machine Learning Toolbox
% ================================================================

clear; clc;

%% ---------------- User settings ----------------
inFile      = fullfile('data','A_HYPO_RAW_TRENDS_STANDARDIZED.csv'); % <— EDIT if needed
outFigDir   = fullfile('figures');
outTabDir   = fullfile('outputs');
outFigBase  = 'FigS3_trend_bars';
minPerBiome = 2;  % drop biomes with <2 observations

vars      = {'mean_NDVI_raw','mean_LST_raw','VegetativeCooling'};
varLabels = {'NDVI (trend, ×100)','LST (trend)','Vegetative Cooling (trend)'};

if ~exist(outFigDir,'dir'); mkdir(outFigDir); end
if ~exist(outTabDir,'dir'); mkdir(outTabDir); end

%% ---------------- Load data --------------------
[~,~,ext] = fileparts(inFile);
switch lower(ext)
  case '.csv'
    T = readtable(inFile);
  case '.mat'
    S = load(inFile); fn = fieldnames(S); T = S.(fn{1});
  otherwise
    error('Unsupported input type: %s', ext);
end

% Grouping to string for safety
if ~isstring(T.Biome),  T.Biome  = string(T.Biome);  end
if ~isstring(T.Koppen), T.Koppen = string(T.Koppen); end

%% ---------------- Filter groups ----------------
% Keep biomes with sufficient n
[Gbiome, allBiomes] = findgroups(T.Biome);
countsB = splitapply(@numel, T.Biome, Gbiome);
validB  = allBiomes(countsB >= minPerBiome);
nB      = numel(validB);

% Drop missing Köppen
koppenAll = unique(T.Koppen,'stable');
validK    = koppenAll(~ismissing(koppenAll));
nK        = numel(validK);

%% ---------------- Compute normalized medians ----------------
normmed_b = nan(nB, numel(vars));
normmed_k = nan(nK, numel(vars));
cld_b     = strings(nB, numel(vars));
cld_k     = strings(nK, numel(vars));

for v = 1:numel(vars)
  x = T.(vars{v});
  if strcmp(vars{v},'mean_NDVI_raw'), x = x*100; end  % scale NDVI for readability

  % Min–max normalize (guard against zero range)
  xmin = min(x,[],'omitnan'); xmax = max(x,[],'omitnan');
  if xmax > xmin
    gx = (x - xmin) ./ (xmax - xmin);
  else
    gx = zeros(size(x));  % constant vector -> all zeros after norm
  end

  % Biome medians
  for i = 1:nB
    mask = (T.Biome==validB(i));
    normmed_b(i,v) = median(gx(mask),'omitnan');
  end

  % Köppen medians
  for i = 1:nK
    mask = (T.Koppen==validK(i));
    normmed_k(i,v) = median(gx(mask),'omitnan');
  end

  % Compact-letter display (un-normalized values for inference)
  lettersB = getCLD(x, T.Biome);
  lettersK = getCLD(x, T.Koppen);

  % Map letters to the retained group order
  gnamesB = categories(categorical(T.Biome));
  mapB    = containers.Map(gnamesB, cellstr(lettersB));
  for i = 1:nB, cld_b(i,v) = string( mapB(char(validB(i))) ); end

  gnamesK = categories(categorical(T.Koppen));
  mapK    = containers.Map(gnamesK, cellstr(lettersK));
  for i = 1:nK, cld_k(i,v) = string( mapK(char(validK(i))) ); end
end

%% ---------------- Plot (Figure S3) --------------
f = figure('Color','w','Position',[100 100 950 1050]);
cmap = lines(3);

% a) Biomes
ax1 = subplot(2,1,1);
b1  = bar(ax1, normmed_b, 'FaceColor','flat');
for v=1:3, b1(v).CData = cmap(v,:); end
hold(ax1,'on');
for v=1:3
  xt = b1(v).XEndPoints; yt = b1(v).YEndPoints;
  text(ax1, xt, yt+0.02, cld_b(:,v), 'HorizontalAlignment','center','FontWeight','bold');
end
hold(ax1,'off');
ax1.XTick = 1:nB; ax1.XTickLabel = validB; ax1.XTickLabelRotation = 35;
ylabel(ax1,'Normalized median (0–1)');
title(ax1,'a) Normalized trend medians by Biome');
legend(ax1, {'NDVI','LST','Veg. cooling'}, 'Location','northoutside', ...
       'Orientation','horizontal','Box','off');

% b) Köppen
ax2 = subplot(2,1,2);
b2  = bar(ax2, normmed_k, 'FaceColor','flat');
for v=1:3, b2(v).CData = cmap(v,:); end
hold(ax2,'on');
for v=1:3
  xt = b2(v).XEndPoints; yt = b2(v).YEndPoints;
  text(ax2, xt, yt+0.02, cld_k(:,v), 'HorizontalAlignment','center','FontWeight','bold');
end
hold(ax2,'off');
ax2.XTick = 1:nK; ax2.XTickLabel = validK; ax2.XTickLabelRotation = 35;
ylabel(ax2,'Normalized median (0–1)');
title(ax2,'b) Normalized trend medians by Köppen');

set(findall(f,'-property','FontSize'),'FontSize',12);

% Save figure
exportgraphics(f, fullfile(outFigDir, [outFigBase '.png']), 'Resolution', 300);
exportgraphics(f, fullfile(outFigDir, [outFigBase '.svg']));

%% ---------------- Save summary table ------------
rows = [];
for v = 1:numel(vars)
  rows = [rows; table(repmat("Biome",nB,1),  validB, repmat(string(varLabels{v}),nB,1), ...
                      normmed_b(:,v), cld_b(:,v), ...
                      'VariableNames',{'GroupType','Group','Variable','NormMedian','CLD'})];
  rows = [rows; table(repmat("Koppen",nK,1), validK, repmat(string(varLabels{v}),nK,1), ...
                      normmed_k(:,v), cld_k(:,v), ...
                      'VariableNames',{'GroupType','Group','Variable','NormMedian','CLD'})];
end
writetable(rows, fullfile(outTabDir,'FigS3_trend_bars_summary.csv'));

disp('Figure S3 completed and saved.');

%% ================================================================
% Helper: compact-letter display via Tukey–Kramer
function letters = getCLD(response, groups)
    response = response(:);
    groups   = groups(:);
    if all(ismissing(groups))
        error('All groups are missing; cannot compute CLD.');
    end
    [~,~,stats] = anova1(response, groups, 'off');
    c = multcompare(stats, 'CType','tukey-kramer', 'Display','off');
    n = numel(stats.gnames);
    letters = repmat(' ', n, 1);
    curr = 'a'; used = false(n,1);
    for i = 1:n
        if ~used(i)
            letters(i) = curr; used(i) = true;
            for j = i+1:n
                idx = ( (c(:,1)==i & c(:,2)==j) | (c(:,1)==j & c(:,2)==i) );
                if any(idx) && c(idx,6) >= 0.05  % not significantly different
                    letters(j) = curr; used(j) = true;
                end
            end
            curr = char(curr + 1);
        end
    end
end
