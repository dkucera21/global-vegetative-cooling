%% ================================================================
%  Figure S2: Two-panel significance-annotated barplots on medians
%  Inputs : CSV or MAT table with variables:
%           Biome (categorical/string), Koppen (categorical/string),
%           mean_NDVI_raw, mean_LST_raw, VegetativeCooling
%  Output : ./figures/FigS2_median_bars.png (and .svg)
%           ./outputs/FigS2_summary_stats.csv
%  Requires: Statistics and Machine Learning Toolbox (anova1, multcompare)
% ================================================================

clear; clc;

%% ---------------- User settings ----------------
inFile      = fullfile('data', 'A_HYPO_RAW_TRENDS_STANDARDIZED.csv');   % <— EDIT if needed
outFigDir   = fullfile('figures');
outTabDir   = fullfile('outputs');
outFigBase  = 'FigS2_median_bars';
minPerBiome = 2;          % drop biomes with <2 observations
nBoot       = 1000;       % bootstrap reps for median SE
rng(42);                  % reproducibility

vars = {'mean_NDVI_raw','mean_LST_raw','VegetativeCooling'};
varLabels = {'NDVI (\times100)','LST','Vegetative Cooling'};

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

% Coerce to string for grouping
if ~isstring(T.Biome);   T.Biome  = string(T.Biome);  end
if ~isstring(T.Koppen);  T.Koppen = string(T.Koppen); end

%% ---------------- Filter groups ----------------
% keep only biomes with >= minPerBiome
[Gbiome, allBiomes] = findgroups(T.Biome);
countsB = splitapply(@numel, T.Biome, Gbiome);
validB  = allBiomes(countsB >= minPerBiome);
nB      = numel(validB);

% drop missing Köppen
koppenAll = unique(T.Koppen,'stable');
validK    = koppenAll(~ismissing(koppenAll));
nK        = numel(validK);

%% ---------------- Containers -------------------
med_b = nan(nB, numel(vars));  se_b = nan(nB, numel(vars));  cld_b = strings(nB, numel(vars));
med_k = nan(nK, numel(vars));  se_k = nan(nK, numel(vars));  cld_k = strings(nK, numel(vars));

bootMedianSE = @(x) std( arrayfun(@(~) median(x(randi(numel(x),numel(x),1)),'omitnan'), 1:nBoot) );

%% ---------------- Biome stats ------------------
for v = 1:numel(vars)
  x = T.(vars{v});
  if strcmp(vars{v},'mean_NDVI_raw'); x = x*100; end

  for i = 1:nB
    xi = x(T.Biome==validB(i));
    med_b(i,v) = median(xi,'omitnan');
    se_b(i,v)  = numel(xi)>1 ? bootMedianSE(xi) : 0;
  end

  % compact-letter display (Tukey–Kramer)
  cld = getCLD(x, T.Biome);
  gnames = categories(categorical(T.Biome));
  cmap = containers.Map(gnames, cellstr(cld));
  for i = 1:nB
    cld_b(i,v) = string( cmap(char(validB(i))) );
  end
end

%% ---------------- Köppen stats -----------------
for v = 1:numel(vars)
  x = T.(vars{v});
  if strcmp(vars{v},'mean_NDVI_raw'); x = x*100; end

  for i = 1:nK
    xi = x(T.Koppen==validK(i));
    med_k(i,v) = median(xi,'omitnan');
    se_k(i,v)  = numel(xi)>1 ? bootMedianSE(xi) : 0;
  end

  cld = getCLD(x, T.Koppen);
  gnames = categories(categorical(T.Koppen));
  cmap = containers.Map(gnames, cellstr(cld));
  for i = 1:nK
    cld_k(i,v) = string( cmap(char(validK(i))) );
  end
end

%% ---------------- Plot (Figure S2) --------------
f = figure('Color','w','Position',[100 100 950 1050]);
cmap     = lines(3);
barWidth = 0.25;

% Panel a) Biomes
ax1 = subplot(2,1,1); hold(ax1,'on');
for v = 1:3
  xOff = (v-2)*barWidth;
  b = bar(ax1, (1:nB)+xOff, med_b(:,v), barWidth, ...
          'FaceColor',cmap(v,:), 'EdgeColor','none');
  errorbar(ax1, b.XEndPoints, med_b(:,v), se_b(:,v), 'k','LineStyle','none','CapSize',0);
  pad = 0.02 * max(abs(med_b(:,v))+se_b(:,v));
  text(ax1, b.XEndPoints, med_b(:,v)+se_b(:,v)+pad, cld_b(:,v), ...
       'HorizontalAlignment','center','FontWeight','bold');
end
hold(ax1,'off');
ax1.XTick              = 1:nB;
ax1.XTickLabel         = validB;
ax1.XTickLabelRotation = 35;
ylabel(ax1,'Median value');
title(ax1,'a) Median NDVI (\times100), LST, and Vegetative Cooling by Biome');
legend(ax1, varLabels, 'Location','northoutside','Orientation','horizontal','Box','off');

% Panel b) Köppen
ax2 = subplot(2,1,2); hold(ax2,'on');
for v = 1:3
  xOff = (v-2)*barWidth;
  b = bar(ax2, (1:nK)+xOff, med_k(:,v), barWidth, ...
          'FaceColor',cmap(v,:), 'EdgeColor','none');
  errorbar(ax2, b.XEndPoints, med_k(:,v), se_k(:,v), 'k','LineStyle','none','CapSize',0);
  pad = 0.02 * max(abs(med_k(:,v))+se_k(:,v));
  text(ax2, b.XEndPoints, med_k(:,v)+se_k(:,v)+pad, cld_k(:,v), ...
       'HorizontalAlignment','center','FontWeight','bold');
end
hold(ax2,'off');
ax2.XTick              = 1:nK;
ax2.XTickLabel         = validK;
ax2.XTickLabelRotation = 35;
ylabel(ax2,'Median value');
title(ax2,'b) Median NDVI (\times100), LST, and Vegetative Cooling by Köppen');

set(findall(f,'-property','FontSize'),'FontSize',12);

% Save figure
exportgraphics(f, fullfile(outFigDir, [outFigBase '.png']), 'Resolution', 300);
exportgraphics(f, fullfile(outFigDir, [outFigBase '.svg']));

%% ---------------- Save summary table ------------
% Long format summary for reproducibility
rows = [];
for v = 1:numel(vars)
  % biome rows
  rows = [rows; table(repmat("Biome",nB,1), validB, repmat(string(varLabels{v}),nB,1), ...
                      med_b(:,v), se_b(:,v), cld_b(:,v), ...
                      'VariableNames',{'GroupType','Group','Variable','Median','SE','CLD'})];
  % koppen rows
  rows = [rows; table(repmat("Koppen",nK,1), validK, repmat(string(varLabels{v}),nK,1), ...
                      med_k(:,v), se_k(:,v), cld_k(:,v), ...
                      'VariableNames',{'GroupType','Group','Variable','Median','SE','CLD'})];
end
writetable(rows, fullfile(outTabDir,'FigS2_summary_stats.csv'));

disp('Figure S2 completed and saved.');

%% ================================================================
% Helper: compact-letter display via Tukey–Kramer
% Returns a char array of letters aligned to group order in 'groups'.
function letters = getCLD(response, groups)
    % Ensure column vectors
    response = response(:);
    groups   = groups(:);

    % ANOVA + Tukey–Kramer
    [~,~,stats] = anova1(response, groups, 'off');
    c = multcompare(stats, 'CType','tukey-kramer', 'Display','off');

    % Build letters
    n       = numel(stats.gnames);
    letters = repmat(' ', n, 1);
    curr    = 'a';
    used    = false(n,1);
    for i = 1:n
        if ~used(i)
            letters(i) = curr; used(i) = true;
            for j = i+1:n
                idx = ( (c(:,1)==i & c(:,2)==j) | (c(:,1)==j & c(:,2)==i) );
                if any(idx) && c(idx,6) >= 0.05   % Not significantly different
                    letters(j) = curr; used(j) = true;
                end
            end
            curr = char(curr + 1);
        end
    end
end
