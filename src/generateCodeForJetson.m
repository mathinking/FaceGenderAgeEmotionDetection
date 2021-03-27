% Copyright 2018-2019 The MathWorks, Inc.
%% Generate CUDA Code for the JETSON Using GPU Coder

% Create a dummy instance to make sure that the MAT files have been
% downloaded prior to codegen
detector = DeepNeuralNetworkDetector(false, false, false, [0 0]);
detector.verifyMATFiles();
delete(detector)

% Generate CUDA code
cfg = coder.gpuConfig('exe');

cfg.Hardware = coder.hardware('NVIDIA Jetson');
cfg.Hardware.DeviceAddress = '172.16.21.229';
cfg.Hardware.Username = 'nvidia';
cfg.Hardware.Password = 'nvidia';
cfg.Hardware.BuildDir = '~/remoteBuildDir';
cfg.CustomSource = fullfile('cudaFilesForJetson','main.cu');

% After the code generation takes place on the host, the generated files are copied over and built on the target.
codegen('-config ',cfg,'faceGenderAgeEmotionDetectionOnJetson','-report', '-v','-args',{true,false,false});

%% Run the executable on the target
hwobj = jetson('172.16.21.229','nvidia','nvidia');
exe = [hwobj.workspaceDir '/faceGenderAgeEmotionDetectionOnJetson.elf'];
procID = runExecutable(hwobj,exe,'true false false');

% To set the maximum clock speed on the target and increase performance:
% openShell(hwobj)
% and run 'sudo ~nvidia/jetson_clocks.sh'

%% Stop the executable
% killApplication(hwobj,exe)