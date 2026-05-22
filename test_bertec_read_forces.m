clear; clc;

%% ============================================================
%  Test Bertec live force reading from MATLAB
%  Reads and prints Fx, Fy, Fz, Mx, My, Mz for 5 seconds
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
    %% Create and start device
    bDevice = BertecDeviceNET.BertecDevice();

    fprintf('Starting Bertec device...\n');
    rc = bDevice.Start();
    fprintf('Start return code: %s\n', bertecReturnToText(rc));

    %% Wait until ready
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

    %% zero
    fprintf('\nMake sure the force plate is unloaded.\n');
    fprintf('Zeroing in 2 seconds...\n');
    pause(2);

    rcZero = bDevice.ZeroNow();
    fprintf('ZeroNow return code: %s\n', bertecReturnToText(rcZero));

    pause(1);

    %% Start data stream

    rcStream = bDevice.StartDataStream([]);
    fprintf('StartDataStream return code: %s\n', bertecReturnToText(rcStream));

    %% Read buffered live data
    dataFrames = NET.createArray('BertecDeviceNET.DataFrame', 0);

    fprintf('\nReading live data for 5 seconds...\n\n');

    tRead = tic;

    while toc(tRead) < 5

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

            % Use the newest frame
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

            fprintf('Fx = %+9.2f   Fy = %+9.2f   Fz = %+9.2f   Mx = %+9.2f   My = %+9.2f   Mz = %+9.2f\n', ...
                Fx, Fy, Fz, Mx, My, Mz);

        else
            pause(0.002);
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