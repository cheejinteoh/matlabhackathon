function fitnessMetricsSummary(accT, Fs, totalSteps, dMiles, posT)
    %% 1.  Get user input
    [weightKg, heightM] = getUserInfo();

    %% 2.  BMI
    [bmi, category] = calculateBMI(weightKg, heightM);
    fprintf('\n▶ BMI: %.2f (%s)\n', bmi, category);

    %% 3.  Calories
    calories = estimateCalories(accT, weightKg);
    fprintf('▶ Estimated Calories Burned: %.2f kcal\n', calories);

    %% 4.  Session duration
    durationSec = getSessionDuration(posT);
    fprintf('▶ Session Duration: %.2f seconds (%.2f minutes)\n', ...
            durationSec, durationSec/60);

    %% 5.  Stride ratio
    strideRatio = stepToStrideRatio(totalSteps, dMiles);
    fprintf('▶ Step-to-Stride Ratio: %.2f (1 ≈ normal)\n', strideRatio);

    %% 6.  Average pace
    pace = calculatePace(dMiles, durationSec);
    fprintf('▶ Average Pace: %.2f min/mile\n', pace);

    %% 7.  Intensity check
    if detectHighActivity(accT)
        disp('⚠️  High running intensity detected!');
    else
        disp('✅  Moderate-intensity session.');
    end
end

% ====================== helper functions ===============================

function [weightKg, heightM] = getUserInfo()
    weightKg = askPositive('Enter your weight (kg): ');
    heightM  = askPositive('Enter your height (m): ');
end

function v = askPositive(prompt)
    while true
        v = input(prompt);
        if isnumeric(v) && v>0, break, end
        disp('⚠️  Please enter a positive number.');
    end
end

function [bmi, cat] = calculateBMI(w,h)
    bmi = w/(h^2);
    if     bmi<18.5, cat='Underweight';
    elseif bmi<25,   cat='Normal';
    elseif bmi<30,   cat='Overweight';
    else             cat='Obese';
    end
end

function kcal = estimateCalories(accT, weightKg)
    % crude MET estimate from average acceleration magnitude
    mag  = sqrt(sum(accT{:,["X","Y","Z"]}.^2,2));
    MET  = 1 + mean(mag)/9.81;               % 1 MET rest + extra per g
    durHr= (accT.t(end)-accT.t(1)) / 3600;   % seconds ➔ hours (numeric)
    kcal = MET * weightKg * durHr;
end

function sec = getSessionDuration(posT)
    sec = posT.t(end) - posT.t(1);   % t column already numeric seconds
end

function ratio = stepToStrideRatio(steps, miles)
    expected = miles*5280/2.5;       % avg 2.5 ft stride
    ratio    = steps/expected;
end

function pace = calculatePace(miles, sec)
    if miles==0, pace=Inf; else, pace=(sec/60)/miles; end
end

function high = detectHighActivity(accT)
    mag  = sqrt(sum(accT{:,["X","Y","Z"]}.^2,2));
    high = sum(mag>20) > 10;         % >20 m/s² peaks more than 10×
end
