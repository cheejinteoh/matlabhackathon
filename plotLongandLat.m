function plotLongandLat()
% plotLongandLat  Load LongandLat.mat and plot GPS route on a real map

    if ~isfile('SENSOR.mat')
        error('❌ File "SENSOR.mat" not found.');
    end

    S = load('SENSOR.mat');

    % Option 1: raw lat/lon vectors
    if isfield(S, 'lat') && isfield(S, 'lon')
        lat = S.lat;
        lon = S.lon;

    % Option 2: Position timetable with lower- or upper-case names
    elseif isfield(S, 'Position') && istimetable(S.Position)
        vars = S.Position.Properties.VariableNames;

        % Match case-insensitive
        latVar = vars{contains(lower(vars), 'lat', 'IgnoreCase', true)};
        lonVar = vars{contains(lower(vars), 'lon', 'IgnoreCase', true)};

        lat = S.Position.(latVar);
        lon = S.Position.(lonVar);

    else
        error('❌ No recognizable lat/lon data found.');
    end

    % Haversine formula for distance
    R = 6371e3;
    latRad = deg2rad(lat);
    lonRad = deg2rad(lon);
    dLat = diff(latRad);
    dLon = diff(lonRad);
    a = sin(dLat/2).^2 + cos(latRad(1:end-1)) .* cos(latRad(2:end)) .* sin(dLon/2).^2;
    c = 2 * atan2(sqrt(a), sqrt(1 - a));
    distance = sum(R * c);  % meters
    distanceKm = distance / 1000;

    % Plot
    figure('Name', 'GPS Route');
    geoscatter(lat, lon, 10, 'r', 'filled'); hold on
    h = geoplot(lat, lon, 'b-', 'DisplayName', ...
        sprintf('Total Distance: %.2f km', distanceKm));
    geobasemap streets
    legend(h, 'Location', 'best')
    title('GPS Route from LongandLat.mat')
end
