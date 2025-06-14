%% smartFitnessTracker.m – v2 Full Integration with Fitness Metrics + GPS Route
% Hackathon 2025 – GPS + IMU workout analytics
% -------------------------------------------------------------------
clear; clc; close all
addpath(genpath(pwd));

%% 1. Load sensor data
load PositionandAcceleration.mat
posT = Position; accT = Acceleration;
posT.t = timeElapsed(posT.Timestamp);
accT.t = timeElapsed(accT.Timestamp);

%% 2. Distance & stride estimate
dMiles = sum(haversineMiles( ...
            posT.latitude(1:end-1), posT.longitude(1:end-1), ...
            posT.latitude(2:end  ), posT.longitude(2:end  )));
stepsStride = dMiles * 5280 / 2.5;
fprintf('▶ Total distance : %.2f mi   ≈ %.0f steps (stride estimate)\n', ...
        dMiles, stepsStride)

%% 3. Resample accelerometer to 100 Hz
Fs = 100;
accT = retime(accT, 'regular', 'linear', 'TimeStep', seconds(1/Fs));

%% 4. Windowed features (2 s windows, 50 %% overlap)
win = Fs * 2; olap = win / 2;
rawX = accT{:,["X","Y","Z"]};
[featMat, featNames] = windowFeatures(rawX, win, olap);

%% 5. Train classifier using bagged trees
load ActivityLogs.mat
[trainT, featNames] = preprocessActivityLogs( ...
        sitAcceleration, walkAcceleration, runAcceleration, Fs);
cvp = cvpartition(trainT.Activity, 'Holdout', 0.2);
mdl = fitcensemble(trainT{cvp.training,featNames}, ...
                   trainT.Activity(cvp.training), ...
                   'Method','Bag', 'NumLearningCycles', 60);
valAcc = mean(predict(mdl,trainT{cvp.test,featNames}) == ...
              trainT.Activity(cvp.test));
fprintf('▶ Validation accuracy : %.1f %%\n', 100 * valAcc)

%% 6. Classify session windows
yPred = predict(mdl, featMat);

%% 6-bis. Peak-based step counting (robust version)
prom = 1.0; minLag = 0.3;
mag = vecnorm(accT{:,["X","Y","Z"]},2,2);
[pks, locs] = findpeaks(mag, 'MinPeakProminence', prom, ...
                             'MinPeakDistance', Fs * minLag);
validPk = pks > 11;
locs = locs(validPk);
hop = Fs;
winIdx = floor((locs - 1) / hop) + 1;
winIdx = winIdx(winIdx <= numel(yPred));
peakLabs = categorical(yPred(winIdx));
stepTbl = groupcounts(peakLabs);
if istable(stepTbl)
    stepTbl.Properties.VariableNames = {'Activity','StepCount'};
else
    warning('⚠️ No valid steps detected from acceleration peaks.');
    stepTbl = table(categorical.empty(0,1), zeros(0,1), ...
                    'VariableNames', {'Activity','StepCount'});
end

%% 6-ter. Raw data preview
disp("▶ Raw Accelerometer Preview:")
disp(head(timetable2table(Acceleration, "ConvertRowTimes", false), 5))
disp("▶ Raw GPS Position Preview:")
disp(head(timetable2table(Position, "ConvertRowTimes", false), 5))

%% 7. Dashboard plots
figure('Name','Smart Fitness Tracker','NumberTitle','off');
tiledlayout(2,1,'Padding','compact')
nexttile
plot(accT.t,accT.X), hold on
plot(accT.t,accT.Y), plot(accT.t,accT.Z)
legend X Y Z, xlabel('t [s]'), ylabel('a [m s^{-2}]')
title('Linear acceleration (100 Hz)'), grid on

nexttile
bar(1:numel(yPred), double(yPred), 'FaceColor', [0.3 0.6 0.8])
cats = categories(yPred);
xlabel('Window #'), ylabel('Predicted activity')
yticks(1:numel(cats)), yticklabels(cats)
ylim([0.5 numel(cats)+0.5])
title('Sliding-window activity classification'), grid on

figure('Name','Activity Distribution'); pie(categorical(yPred))
title('Activity share for this session')

%% 8. Session summaries
fprintf('▶ Session breakdown (window counts):\n')
tbl = tabulate(categorical(yPred));
tbl = cell2table(tbl,'VariableNames',{'Activity','WindowCount','Percent'});
tbl.Percent = round(tbl.Percent,2);
disp(tbl)

fprintf('\n▶ Step count per activity (peak based, magnitude-filtered):\n')
disp(stepTbl)

%% 8-bis. External GPS map via plotLongandLat()
try
    plotLongandLat();  % must exist in the same folder
catch ME
    warning('⚠️ Could not display GPS route map: %s', ME.message);
end

%% 9. Fitness Metrics Summary
fitnessMetricsSummary(accT, Fs, sum(stepTbl.StepCount), dMiles, posT);

% ------------------------ Helper functions ------------------------------
function d = haversineMiles(lat1, lon1, lat2, lon2)
R = 3958.8;
phi1 = deg2rad(lat1); phi2 = deg2rad(lat2);
a = sin(deg2rad(lat2-lat1)/2).^2 + ...
    cos(phi1).*cos(phi2).*sin(deg2rad(lon2-lon1)/2).^2;
d = 2 * R * asin(min(1, sqrt(a)));
end

function [trainT, featNames] = preprocessActivityLogs(sitT, walkT, runT, Fs)
labels = ["sitting", "walking", "running"];
logs = {sitT, walkT, runT};
for k = 1:3
    tt = retime(logs{k}, 'regular', 'linear', 'TimeStep', seconds(1/Fs));
    [fm, fn] = windowFeatures(tt{:,["X","Y","Z"]}, Fs*2, Fs);
    if k == 1, featNames = fn; end
    ft = array2table(fm, 'VariableNames', fn);
    ft.Activity = repmat(categorical(labels(k)), height(ft), 1);
    featTbl{k} = ft;
end
trainT = vertcat(featTbl{:});
end

function [featMat, featNames] = windowFeatures(X, win, olap)
bX = buffer(X(:,1), win, olap, 'nodelay');
bY = buffer(X(:,2), win, olap, 'nodelay');
bZ = buffer(X(:,3), win, olap, 'nodelay');
valid = all(~isnan(bX));
stat  = @(v)[mean(v); std(v); range(v); rms(v)];
for i = find(valid)
    feat(:,i) = [stat(bX(:,i)); stat(bY(:,i)); stat(bZ(:,i))];
end
featMat = feat.';
featNames = ["muX","sigmaX","rangeX","rmsX", ...
             "muY","sigmaY","rangeY","rmsY", ...
             "muZ","sigmaZ","rangeZ","rmsZ"];
end
