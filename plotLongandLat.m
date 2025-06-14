function plotLongandLat()
% plotLongandLat - Load SENSOR.mat and plot GPS & acceleration data

    % 1. Load file
    if ~isfile('SENSOR2.mat')
        error('❌ File "SENSOR2.mat" not found.');
    end
    S = load('SENSOR2.mat');

    %% === Extract GPS Data ===
    if isfield(S, 'Position') && istimetable(S.Position)
        Position = S.Position;

        % Identify lat, lon, alt, speed, timestamp
        lat = Position.latitude;
        lon = Position.longitude;
        alt = Position.altitude;
        speed = Position.speed * 3.6;  % m/s to km/h
        t = Position.Timestamp;

        %% === Calculate Distance with Haversine Formula ===
        R = 6371e3; % Earth radius in meters
        latRad = deg2rad(lat);
        lonRad = deg2rad(lon);
        dLat = diff(latRad);
        dLon = diff(lonRad);
        a = sin(dLat/2).^2 + cos(latRad(1:end-1)) .* cos(latRad(2:end)) .* sin(dLon/2).^2;
        c = 2 * atan2(sqrt(a), sqrt(1 - a));
        distance = sum(R * c);
        distanceKm = distance / 1000;

        %% === Plot GPS Route ===
        figure('Name', 'GPS Route');
        geoscatter(lat, lon, 10, 'r', 'filled'); hold on;
        h = geoplot(lat, lon, 'b-', 'DisplayName', ...
            sprintf('Total Distance: %.2f km', distanceKm));
        geobasemap streets;
        legend(h, 'Location', 'best');
        title(' GPS Route');

        %% === Speed vs Time ===
        figure;
        plot(t, speed, 'b');
        xlabel('Time'); ylabel('Speed (km/h)');
        title(' Speed vs Time');
        grid on;

        %% === Altitude vs Time ===
        figure;
        plot(t, alt, 'g');
        xlabel('Time'); ylabel('Altitude (m)');
        title('Altitude vs Time');
        grid on;

    else
        warning('⚠️ No GPS Position data found in SENSOR.mat.');
    end

    %% === Extract Acceleration Data ===
    if isfield(S, 'Acceleration') && istimetable(S.Acceleration)
        Acc = S.Acceleration;
        tAcc = Acc.Timestamp;
        accX = Acc.X;
        accY = Acc.Y;
        accZ = Acc.Z;

        %% === Plot X, Y, Z Acceleration vs Time ===
        figure;
        plot(tAcc, accX, 'r', 'DisplayName', 'X-axis'); hold on;
        plot(tAcc, accY, 'g', 'DisplayName', 'Y-axis');
        plot(tAcc, accZ, 'b', 'DisplayName', 'Z-axis');
        xlabel('Time');
        ylabel('Acceleration (m/s²)');
        title('Acceleration vs Time');
        legend('show');
        grid on;

    else
        warning('⚠️ No Acceleration data found in SENSOR2.mat.');
    end

end
