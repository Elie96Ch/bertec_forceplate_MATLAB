function load_bertec_sdk()
sdkFolder = 'C:\Users\elie.chebel\Documents\projects\bertec realtime visualization\Bertec_Device_SDK_March_2026';
x64Folder = fullfile(sdkFolder, 'x64');

dllPath = fullfile(x64Folder, 'BertecDeviceNET.dll');

setenv('PATH', [x64Folder ';' sdkFolder ';' getenv('PATH')]);

NET.addAssembly(char(dllPath));

disp('Bertec .NET SDK loaded.');
end