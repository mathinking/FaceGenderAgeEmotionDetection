% Copyright 2019 The MathWorks, Inc.

% This wrapper is not meant to be executed directly.
% Please run generateCodeForJetson.m to deploy it on a JETSON

function faceGenderAgeEmotionDetectionOnJetson(detectGender, detectAge, detectEmotion)
% This demo showcases the use of different deep neural networks to:
%   1. Detect faces
%   2. Classify detected faces between male and female
%   3. Predict age of detected faces
%   4. Predict emotion of detected faces

if nargin < 1
    detectGender = false;
end
if nargin < 2
    detectAge = false;
end
if nargin < 3
    detectEmotion = false;
end

if coder.target('MATLAB')
    warning("This wrapper is not meant to be executed directly. Please run generateCodeForJetson.m instead")
end

resolution = [640,480];

% Connect to webcam
hwobj = jetson; % To redirect to the code generatable functions.
wcam = webcam(hwobj,1,[num2str(resolution(1)),'x',num2str(resolution(2))]);
player = imageDisplay(hwobj);

% Create an instance of the detector using the input parameters and the
% selected resolution
detector = DeepNeuralNetworkDetector(detectGender,detectAge,detectEmotion,resolution);

while true
    image(player,detect(detector,snapshot(wcam)));
end

end