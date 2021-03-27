% Copyright 2018-2020 The MathWorks, Inc.
classdef DeepNeuralNetworkDetectorOptions < handle
    
    properties
        backgroundColor;
        textColor;
        fontSize;
        faceMargin;
        bboxLineWidth;
        numFacesBatch;
        faceDetectionFrameRate;
        genderMovingAverageWindow;
        ageMovingAverageWindow;
        emotionMovingAverageWindow;
        debugMode;
        useYOLO;
        useEyes;
    end
    
    methods
        function opts = DeepNeuralNetworkDetectorOptions(varargin)
            defaultBackgroundColor = [0,150,0]; % Background color for the text and the box
            defaultTextColor = [255,255,255]; % Text color          
            defaultFontSize = 20; % Bounding box font size
            defaultFaceMargin = 0.3; % Face Margin. This value has an effect on age and emotion detection. Use carefully
            defaultBboxLineWidth = 4; % Bounding Box Line Width
            defaultNumFacesBatch = [5,10]; % Range of faces to run in batch mode. 
            defaultFaceDetectionFrameRate = 10; % Frame rate for Face Detection       
            defaultGenderMovingAverageWindow = 15; % Number of observations considered for gender moving average
            defaultAgeMovingAverageWindow = 15; % Number of observations considered for age moving average
            defaultEmotionMovingAverageWindow = 15; % Number of observations considered for emotion moving average
            defaultDebugMode = false; % For debugging purposes
            defaultUseYOLO = true; % Use YOLO for Face Detection
            defaultUseEyes = true; % Use Eyes Detection to improve Face Detections

            parser = inputParser;
            parser.KeepUnmatched = true;
            parser.addParameter('backgroundColor',defaultBackgroundColor,@opts.isColor);
            parser.addParameter('textColor',defaultTextColor,@opts.isColor);
            parser.addParameter('fontSize',defaultFontSize,@opts.isScalarIntegerGreaterEqualThanZero);
            parser.addParameter('faceMargin',defaultFaceMargin,@opts.isScalarBetweenZeroAndPointFive);
            parser.addParameter('bboxLineWidth',defaultBboxLineWidth,@opts.isScalarIntegerGreaterEqualThanZero);
            parser.addParameter('numFacesBatch',defaultNumFacesBatch,@opts.isNumericVectorSizeTwo);            
            parser.addParameter('faceDetectionFrameRate',defaultFaceDetectionFrameRate,@opts.isScalarIntegerGreaterEqualThanZero);
            parser.addParameter('genderMovingAverageWindow',defaultGenderMovingAverageWindow,@opts.isScalarIntegerGreaterEqualThanZero);
            parser.addParameter('ageMovingAverageWindow',defaultAgeMovingAverageWindow,@opts.isScalarIntegerGreaterEqualThanZero);
            parser.addParameter('emotionMovingAverageWindow',defaultEmotionMovingAverageWindow,@opts.isScalarIntegerGreaterEqualThanZero);
            parser.addParameter('debugMode',defaultDebugMode,@opts.isScalarLogical);
            parser.addParameter('useYOLO',defaultUseYOLO,@opts.isScalarLogical);
            parser.addParameter('useEyes',defaultUseEyes,@opts.isScalarLogical);
            
            parser.parse(varargin{:});
            
            opts.backgroundColor = parser.Results.backgroundColor;
            opts.textColor = parser.Results.textColor;
            opts.fontSize = parser.Results.fontSize;    
            opts.faceMargin = parser.Results.faceMargin;
            opts.bboxLineWidth = parser.Results.bboxLineWidth;
            opts.numFacesBatch = parser.Results.numFacesBatch;            
            opts.faceDetectionFrameRate = parser.Results.faceDetectionFrameRate;
            opts.genderMovingAverageWindow = parser.Results.genderMovingAverageWindow;
            opts.ageMovingAverageWindow = parser.Results.ageMovingAverageWindow;
            opts.emotionMovingAverageWindow = parser.Results.emotionMovingAverageWindow;
            opts.debugMode = parser.Results.debugMode;
            opts.useYOLO = parser.Results.useYOLO;
            opts.useEyes = parser.Results.useEyes;
        end
    end
    methods (Static = true, Access = private)
        function tf = isColor(x)
            tf = size(x,1) == 1 && size(x,2) == 3 && all(mod(x,1)==0) && all(x>=0) && all(x<=255);
        end
        
        function tf = isScalarIntegerGreaterEqualThanZero(x)
            tf = isscalar(x) && isreal(x) && isnumeric(x) && all(mod(x,1)==0) && (x>=0);
        end
        
        function tf = isNumericVectorSizeTwo(x)
            tf = isreal(x) && isnumeric(x) && all(mod(x,1)==0) && all(x>0) && x(2)>x(1);
        end
        
        function tf = isScalarBetweenZeroAndPointFive(x)
            tf = isscalar(x) && isreal(x) && isnumeric(x) && x>=0 && x<=0.5;
        end
        
        function tf = isScalarLogical(x)
            tf = isscalar(x) && (islogical(x) || (x==1) || (x==0));
        end
    end
end