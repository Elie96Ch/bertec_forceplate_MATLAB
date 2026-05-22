clear; clc;

%% ============================================================
%  Bertec real-time ground reaction force vector visualization
%
%  Confirmed device:
%  Model:    AM6817-E
%  Channels: Fx, Fy, Fz, Mx, My, Mz
%
%  This script:
%  1. Loads BertecDeviceNET.dll
%  2. Connects to the force plate
%  3. Waits for DEVICES_READY
%  4. Reads Fx, Fy, Fz, Mx, My, Mz
%  5. Computes CoP from moments and Fz
%  6. Visualizes the ground reaction force vector in real time
%% ============================================================

sdkFolder = '\Bertec_Device_SDK_March_2026';
x64Folder = fullfile(sdkFolder, 'x64');
dllPath   = fullfile(x64Folder, 'BertecDeviceNET.dll');

% Make sure MATLAB can find BertecDevice.dll and ftd2xx.dll
setenv('PATH', [x64Folder ';' sdkFolder ';' getenv('PATH')]);

% Load Bertec .NET SDK
NET.addAssembly(char(dllPath));
disp('Bertec .NET SDK loaded.');

bDevice = [];

try
    %% Create and start Bertec device
    bDevice = BertecDeviceNET.BertecDevice();

    fprintf('Starting Bertec device...\n');
    rc = bDevice.Start();
    fprintf('Start return code: %s\n', bertecReturnToText(rc));

    %% Wait until device is ready
    fprintf('Waiting for DEVICES_READY...\n');

    t0 = tic;
    while toc(t0) < 15
        statusText = char(bDevice.Status.ToString());
        fprintf('Status: %s\n', statusText);

        if strcmp(statusText, 'DEVICES_READY')
            break;
        end

        pause(0.25);
    end

    finalStatus = char(bDevice.Status.ToString());

    if ~strcmp(finalStatus, 'DEVICES_READY')
        error('Device did not become ready. Final status: %s', finalStatus);
    end

    fprintf('\nDevice ready.\n');
    fprintf('Device count: %d\n', double(bDevice.DeviceCount));

    %% Read channel names correctly from .NET array
    chNamesNet = bDevice.DeviceChannelNames(0);
    nChannels  = double(chNamesNet.Length);
    chNames    = strings(1, nChannels);

    fprintf('\nChannel count: %d\n', nChannels);
    fprintf('Channels:\n');

    for k = 0:(nChannels - 1)
        chNames(k + 1) = string(char(chNamesNet.Get(k)));
        fprintf('  %2d: %s\n', k + 1, chNames(k + 1));
    end

    %% Map channel indices
    idxFx = find(strcmpi(chNames, 'Fx'), 1);
    idxFy = find(strcmpi(chNames, 'Fy'), 1);
    idxFz = find(strcmpi(chNames, 'Fz'), 1);
    idxMx = find(strcmpi(chNames, 'Mx'), 1);
    idxMy = find(strcmpi(chNames, 'My'), 1);
    idxMz = find(strcmpi(chNames, 'Mz'), 1);

    if isempty(idxFx) || isempty(idxFy) || isempty(idxFz) || ...
       isempty(idxMx) || isempty(idxMy) || isempty(idxMz)
        error('Could not find all required channels Fx, Fy, Fz, Mx, My, Mz.');
    end

    fprintf('\nChannel mapping:\n');
    fprintf('Fx index: %d\n', idxFx);
    fprintf('Fy index: %d\n', idxFy);
    fprintf('Fz index: %d\n', idxFz);
    fprintf('Mx index: %d\n', idxMx);
    fprintf('My index: %d\n', idxMy);
    fprintf('Mz index: %d\n', idxMz);

    %% Optional zero/tare
    fprintf('\nMake sure the force plate is unloaded.\n');
    fprintf('Zeroing in 2 seconds...\n');
    pause(2);

    rcZero = bDevice.ZeroNow();
    fprintf('ZeroNow return code: %s\n', bertecReturnToText(rcZero));

    pause(1);

    %% Start data stream
    % For single force plate / no sync, Bertec documentation uses
    % StartDataStream(null). In MATLAB, [] is passed as .NET null.
    rcStream = bDevice.StartDataStream([]);
    fprintf('StartDataStream return code: %s\n', bertecReturnToText(rcStream));

    %% Prepare figure
    fig = figure( ...
        'Name', 'Bertec Real-Time Ground Reaction Force Vector', ...
        'NumberTitle', 'off', ...
        'Color', 'w');

    hold on;
    grid on;
    axis equal;
    view(3);

    xlabel('X (m)');
    ylabel('Y (m)');
    zlabel('Z (m)');
    title('Real-Time Ground Reaction Force Vector');

    % Approximate force plate dimensions.
    % Adjust these values if you know the exact active surface dimensions.
    plateLength = 0.60;   % meters
    plateWidth  = 0.40;   % meters

    % Draw force plate surface
    plateX = [-plateLength/2,  plateLength/2,  plateLength/2, -plateLength/2];
    plateY = [-plateWidth/2,  -plateWidth/2,   plateWidth/2,   plateWidth/2];
    plateZ = [0, 0, 0, 0];

    patch(plateX, plateY, plateZ, [0.9 0.9 0.9], ...
        'EdgeColor', 'k', ...
        'LineWidth', 2, ...
        'FaceAlpha', 0.35);

    % Center lines
    plot3([-plateLength/2, plateLength/2], [0, 0], [0, 0], 'k:');
    plot3([0, 0], [-plateWidth/2, plateWidth/2], [0, 0], 'k:');

    % Origin marker
    plot3(0, 0, 0, 'k+', 'MarkerSize', 10, 'LineWidth', 1.5);

    % Center of pressure marker
    hCop = plot3(0, 0, 0, 'ko', ...
        'MarkerFaceColor', 'k', ...
        'MarkerSize', 8);

    % Ground reaction force vector
    hVec = quiver3(0, 0, 0, 0, 0, 0, ...
        'LineWidth', 3, ...
        'MaxHeadSize', 0.5, ...
        'AutoScale', 'off');

    % Text readout
    hText = text(-0.48, -0.35, 1.35, '', ...
        'FontSize', 11, ...
        'VerticalAlignment', 'top', ...
        'BackgroundColor', 'w', ...
        'EdgeColor', [0.7 0.7 0.7]);

    xlim([-0.5 0.5]);
    ylim([-0.5 0.5]);
    zlim([0 1.5]);

    %% Runtime parameters
    forceScale  = 0.001;  % meters per Newton for visualization
    fzThreshold = 20;     % N, hide vector below this load
    alpha       = 0.20;   % exponential smoothing for display only

    FxFilt = 0;
    FyFilt = 0;
    FzFilt = 0;
    MxFilt = 0;
    MyFilt = 0;
    MzFilt = 0;

    plotPeriod = 1 / 60;  % target visual update rate
    lastPlotTime = tic;

    % Allocate .NET DataFrame array
    dataFrames = NET.createArray('BertecDeviceNET.DataFrame', 0);

    fprintf('\nRunning visualization.\n');
    fprintf('Close the figure window to stop.\n\n');

    %% Main acquisition + visualization loop
    while ishandle(fig)

        % ReadBufferedDataStream uses a ref argument.
        % In most MATLAB versions, the updated .NET array is returned
        % as the second output.
        try
            [nRead, dataFrames] = bDevice.ReadBufferedDataStream(dataFrames);
        catch
            % Fallback for MATLAB versions that do not expose the ref output.
            nRead = bDevice.ReadBufferedDataStream(dataFrames);
        end

        if nRead > 0

            nFrames = double(dataFrames.Length);

            if nFrames < 1
                pause(0.001);
                continue;
            end

            % Use newest frame
            frame = dataFrames.Get(nFrames - 1);

            % Read forceData from .NET array
            fdNet = frame.forceData;
            nFd = double(fdNet.Length);
            fd = zeros(1, nFd);

            for k = 0:(nFd - 1)
                fd(k + 1) = double(fdNet.Get(k));
            end

            Fx = fd(idxFx);
            Fy = fd(idxFy);
            Fz = fd(idxFz);
            Mx = fd(idxMx);
            My = fd(idxMy);
            Mz = fd(idxMz);

            % Smooth values for visualization only
            FxFilt = alpha * Fx + (1 - alpha) * FxFilt;
            FyFilt = alpha * Fy + (1 - alpha) * FyFilt;
            FzFilt = alpha * Fz + (1 - alpha) * FzFilt;
            MxFilt = alpha * Mx + (1 - alpha) * MxFilt;
            MyFilt = alpha * My + (1 - alpha) * MyFilt;
            MzFilt = alpha * Mz + (1 - alpha) * MzFilt;

            % Limit graphic updates
            if toc(lastPlotTime) >= plotPeriod
                lastPlotTime = tic;

                if abs(FzFilt) > fzThreshold

                    % ----------------------------------------------------
                    % Center of pressure estimate
                    %
                    % Common force-plate convention:
                    % COPx = -My / Fz
                    % COPy =  Mx / Fz
                    %
                    % If CoP movement is mirrored, flip signs below.
                    % ----------------------------------------------------
                    COPx = -MyFilt / FzFilt;
                    COPy =  MxFilt / FzFilt;

                    % Keep CoP display within a reasonable range
                    % This avoids the marker flying away during transients.
                    if abs(COPx) > 2 || abs(COPy) > 2
                        COPx = 0;
                        COPy = 0;
                    end

                    % Update CoP marker
                    set(hCop, ...
                        'XData', COPx, ...
                        'YData', COPy, ...
                        'ZData', 0);

                    % Update GRF vector
                    set(hVec, ...
                        'XData', COPx, ...
                        'YData', COPy, ...
                        'ZData', 0, ...
                        'UData', FxFilt * forceScale, ...
                        'VData', FyFilt * forceScale, ...
                        'WData', FzFilt * forceScale);

                    % Update text
                    set(hText, 'String', sprintf([ ...
                        'Fx: %+8.2f N\n' ...
                        'Fy: %+8.2f N\n' ...
                        'Fz: %+8.2f N\n' ...
                        'Mx: %+8.2f Nm\n' ...
                        'My: %+8.2f Nm\n' ...
                        'Mz: %+8.2f Nm\n' ...
                        'CoP X: %+7.4f m\n' ...
                        'CoP Y: %+7.4f m'], ...
                        FxFilt, FyFilt, FzFilt, ...
                        MxFilt, MyFilt, MzFilt, ...
                        COPx, COPy));

                else
                    % No meaningful vertical load
                    set(hVec, ...
                        'XData', 0, ...
                        'YData', 0, ...
                        'ZData', 0, ...
                        'UData', 0, ...
                        'VData', 0, ...
                        'WData', 0);

                    set(hCop, ...
                        'XData', 0, ...
                        'YData', 0, ...
                        'ZData', 0);

                    set(hText, 'String', sprintf([ ...
                        'Below threshold\n' ...
                        'Fz: %+8.2f N'], FzFilt));
                end

                drawnow limitrate;
            end

        else
            pause(0.001);
        end
    end

    %% Clean shutdown
    fprintf('\nStopping Bertec device...\n');
    bDevice.Stop();
    bDevice.Dispose();
    fprintf('Done.\n');

catch ME

    fprintf('\nError occurred. Cleaning up Bertec device...\n');

    if ~isempty(bDevice)
        try
            bDevice.Stop();
        catch
        end

        try
            bDevice.Dispose();
        catch
        end
    end

    rethrow(ME);
end

%% ============================================================
%  Helper function
%% ============================================================
function txt = bertecReturnToText(rc)
    try
        txt = char(rc.ToString());
    catch
        if isnumeric(rc)
            txt = num2str(rc);
        else
            txt = char(string(rc));
        end
    end
end