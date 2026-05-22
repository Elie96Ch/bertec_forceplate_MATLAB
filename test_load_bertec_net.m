% test_load_bertec_net_x64_v2.m
clear; clc;

sdkFolder = 'C:\Users\elie.chebel\Documents\projects\bertec realtime visualization\Bertec_Device_SDK_March_2026';
x64Folder = fullfile(sdkFolder, 'x64');

dllPath = fullfile(x64Folder, 'BertecDeviceNET.dll');

fprintf('MATLAB arch: %s\n', computer('arch'));
fprintf('DLL path: %s\n', dllPath);
fprintf('DLL exists: %d\n', exist(dllPath, 'file'));

setenv('PATH', [x64Folder ';' sdkFolder ';' getenv('PATH')]);

NET.addAssembly(char(dllPath));

disp('BertecDeviceNET.dll loaded successfully.');