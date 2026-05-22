clear; clc;

load_bertec_sdk();

bDevice = [];

try
    bDevice = BertecDeviceNET.BertecDevice();

    rc = bDevice.Start();
    fprintf('Start return code: %s\n', char(rc.ToString()));

    while ~strcmp(char(bDevice.Status.ToString()), 'DEVICES_READY')
        fprintf('Status: %s\n', char(bDevice.Status.ToString()));
        pause(0.25);
    end

    fprintf('\nDevice count: %d\n', double(bDevice.DeviceCount));

    chNames = bDevice.DeviceChannelNames(0);
    nChannels = double(chNames.Length);

    fprintf('\nChannel count: %d\n', nChannels);
    fprintf('Channels:\n');

    for k = 0:(nChannels - 1)
        fprintf('  %2d: %s\n', k + 1, char(chNames.Get(k)));
    end

    bDevice.Stop();
    bDevice.Dispose();

catch ME
    if ~isempty(bDevice)
        try
            bDevice.Stop();
            bDevice.Dispose();
        catch
        end
    end
    rethrow(ME);
end