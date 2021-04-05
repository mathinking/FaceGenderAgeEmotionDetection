% Copyright 2018-2021 The MathWorks, Inc.
function faceGenderAgeEmotionDetection(detectGender, detectAge, detectEmotion)
% This demo showcases the use of different deep neural networks to:
%   1. Detect faces
%   2. Classify detected faces between male and female
%   3. Predict age of detected faces
%   4. Predict emotion of detected faces

clear DeepNeuralNetworkDetector;

if gpuDeviceCount > 1
    gpu = gpuDevice;
    reset(gpu)
else
    warning('MATLAB:faceGenderAgeEmotionDetection:noGpuFound',...
        'No supported GPU device found. Performance may be impacted.')
end

if nargin < 1
    detectGender = false;
end
if nargin < 2
    detectAge = true;
end
if nargin < 3
    detectEmotion = true;
end

resolution = [1920,1080];

% Connect to webcam
wcam = webcam(1);
try % Try Full HD resolution if available
    wcam.Resolution = num2str(resolution(1))+"x"+num2str(resolution(2));
catch
    fprintf(1,'Full HD not available. Using %s resolution.\n',wcam.Resolution)
end
player = vision.DeployableVideoPlayer("Size","Full-screen");

options = DeepNeuralNetworkDetectorOptions("BackgroundColor",[0,150,0],... % Background color for the text and the box
                                           "TextColor",[255,255,255],... % Text color
                                           "FontSize",22,... % Bounding box font size
                                           "FaceMargin",0.3,... % Face Margin. This value has an effect on age and emotion detection. Use carefully
                                           "BboxLineWidth",4,... % Bounding Box Line Width
                                           "NumFacesBatch",[5,10],... % Range of faces to run in batch mode.
                                           "FaceDetectionFrameRate",10,... % Frame rate for Face Detection
                                           "GenderMovingAverageWindow",15,... % Number of observations considered for gender moving average
                                           "AgeMovingAverageWindow",15,... % Number of observations considered for age moving average
                                           "EmotionMovingAverageWindow",15,... % Number of observations considered for emotion moving average
                                           "DebugMode",false,... % For debugging purposes
                                           "UseYOLO",false,... % Use YOLO for Face Detection
                                           "UseEyes",false); % Use Eyes Detection to improve Face Detections

% Create an instance of the detector using the input parameters and the
% selected resolution
detector = DeepNeuralNetworkDetector(detectGender,detectAge,detectEmotion,resolution,options);

% Check that the MAT files have been downloaded
verifyMATFiles(detector);

% Check that the mex files have been generated
verifyMEXFiles(detector);

bufferImg = flip(snapshot(wcam),2);
useBuffer = true;

while true
    [imgOut, bbox] = detect(detector,snapshot(wcam));
    if isempty(bbox) && useBuffer
        player(bufferImg)
        useBuffer = false;
    else
        player(imgOut)
        bufferImg = imgOut;
        useBuffer = true;
    end

    if ~isOpen(player)
        break;
    end
end

release(player)
release(detector);
end
