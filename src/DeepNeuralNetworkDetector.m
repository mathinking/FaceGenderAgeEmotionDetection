% Copyright 2018-2020 The MathWorks, Inc.
classdef DeepNeuralNetworkDetector < handle
    properties (Access = private)

        %--- Default values for these set of properties should not be changed ---%

        % Booleans representing user choices
        detectGender;
        detectAge;
        detectEmotion;

        % Valid ages
        ages = 0:100;

        % Valid genders
        genders = ["Female","Male"];

        % Valid emotions
        emotions = ["Angry","Disgust","Fear","Happy","Sad","Surprise","Neutral"];

        % Camera resolution
        origSize;

        % Filenames of the mex files
        mexFiles = ["predictGender_mex.mexw64","predictFace_mex.mexw64","predictEmotion_mex.mexw64","predictAge_mex.mexw64"];

        % Framerate of the application
        fps = 0;

        % Viola-Jones Face Detector
        faceDetector = vision.CascadeObjectDetector("MergeThreshold", 8);

        % Viola-Jones Eyes Detector
        eyesDetector = vision.CascadeObjectDetector("EyePairSmall");

        % Multi Face Tracker
        tracker = MultiFaceTrackerKLT;

        %--- Values for the following properties are set using DeepNeuralNetworkOptions class ---%

        % Background color for the text and the box
        backgroundColor;

        % Text color
        textColor;

        % Bounding box font size
        fontSize;

        % Face Margin
        faceMargin;

        % Bounding Box Line Width
        bboxLineWidth;

        % Range of faces to run in batch mode.
        numFacesBatch;

        % Frame rate for Face Detection
        faceDetectionFrameRate;

        % Number of observations considered for gender moving average
        genderMovingAverageWindow;

        % Number of observations considered for age moving average
        ageMovingAverageWindow;

        % Number of observations considered for emotion moving average
        emotionMovingAverageWindow;

        % For debugging purposes
        debugMode;

        % Use YOLO for Face Detection
        useYOLO;

        % Use Eyes Detection to improve Face Detections
        useEyes;
    end

    properties (Access = private, Constant)
        % Main folder for the models
        modelsFolder = "models";

        % Filenames of the networks
        matfileFace    = fullfile(DeepNeuralNetworkDetector.modelsFolder,"net_face_yolo.mat");
        matfileGender  = fullfile(DeepNeuralNetworkDetector.modelsFolder,"net_gender.mat");
        matfileAge     = fullfile(DeepNeuralNetworkDetector.modelsFolder,"net_age.mat");
        matfileEmotion = fullfile(DeepNeuralNetworkDetector.modelsFolder,"net_emotion.mat");

        % Resolution for the face detection NN
        faceDetectionYOLOSize = [448,448];
        % Resolution for the gender, age and emotion detection NNs
        genderAgeDetectionSize = [224,224];
        emotionDetectionSize = [64,64];
    end

    methods
        function obj = DeepNeuralNetworkDetector(detectGender,detectAge,detectEmotion,resolution,options)
            if nargin < 5
                options = DeepNeuralNetworkDetectorOptions;
            end
            obj.detectGender = detectGender;
            obj.detectAge = detectAge;
            obj.detectEmotion = detectEmotion;
            obj.origSize = resolution;

            % Setting parameters from DeepNeuralNetworkDetectorOptions object
            obj.backgroundColor = options.backgroundColor;
            obj.textColor = options.textColor;
            obj.fontSize = options.fontSize;
            obj.faceMargin = options.faceMargin;
            obj.bboxLineWidth = options.bboxLineWidth;
            obj.numFacesBatch = options.numFacesBatch;
            obj.faceDetectionFrameRate = options.faceDetectionFrameRate;
            obj.genderMovingAverageWindow = options.genderMovingAverageWindow;
            obj.ageMovingAverageWindow = options.ageMovingAverageWindow;
            obj.emotionMovingAverageWindow = options.emotionMovingAverageWindow;
            obj.debugMode = options.debugMode;
            obj.useYOLO = options.useYOLO;
            obj.useEyes = options.useEyes;
        end

        function [img, bbox] = detect(obj,origImg)
            persistent frameNumber;
            if isempty(frameNumber)
                frameNumber = 0;
            end

            tic; % Count FPS

            origImg = flip(origImg,2); % horizontal flip
            img = origImg;
            imgFaceDetection = imresize(origImg,obj.faceDetectionYOLOSize);
            imgGray = rgb2gray(origImg);

            % Run face detection every faceDetectionFrameRate frames or if no face has been
            % previously detected
            if mod(frameNumber, obj.faceDetectionFrameRate) == 0 || isempty(obj.tracker.Bbox) % Re-detect faces
                if obj.useYOLO % Use YOLO for Face Detection
                    if coder.target('MATLAB')
                        if exist("predictFace_mex","file") == 3
                            bbox = predictFace_mex(imgFaceDetection,obj.matfileFace);
                        else
                            bbox = predictFace(imgFaceDetection,obj.matfileFace);
                        end
                    else % Used for codegen
                        bbox = predictFace(imgFaceDetection,obj.matfileFace);
                    end

                    % Rescaling bounding boxes to original image not to loose resolution for face tracking or age,
                    % gender and emotion detection
                    bbox(:,[1,3]) = floor(bbox(:,[1,3])*size(origImg,2)/obj.faceDetectionYOLOSize(2));
                    bbox(:,[2,4]) = floor(bbox(:,[2,4])*size(origImg,1)/obj.faceDetectionYOLOSize(1));
                end

                % Using Viola-Jones for Face Detection
                resizedImg = imresize(origImg, 0.5);

                % Setting the cascadeClassifier properties

                obj.faceDetector.MaxSize = floor(size(resizedImg(:,:,1))/4);
                obj.faceDetector.MinSize = [30 30];
                obj.faceDetector.ScaleFactor = 1.05;

                bbox2 = 2*obj.faceDetector(resizedImg);

                if obj.useYOLO % Check overlap between YOLO and Viola-Jones
                    ratios = zeros(size(bbox,1),size(bbox2,1));

                    for j = 1:size(ratios,2)
                        for i = 1:size(ratios,1)
                            ratios(i,j) = bboxOverlapRatio(bbox(i,:),bbox2(j,:),"min");
                        end
                    end
                    [~,relevantBbox] = find(ratios > 0.7);
                    % Bounding boxes are chosen from Viola-Jones (apparently more robust detection)
                    bbox = bbox2(relevantBbox,:);
                else
                    bbox = bbox2;
                end

                if obj.useEyes
                    hasEyes = false(size(bbox,1),1);
                    for i = 1:size(bbox)
                        croppedImg = imcrop(origImg,bbox(i,:));
                        eyesBbox = obj.eyesDetector(croppedImg);
                        if ~isempty(eyesBbox)
                            hasEyes(i) = true;
                        end
                    end
                    bbox(~hasEyes,:) = [];
                end

                if ~isempty(bbox) % Add bbox to tracker
                    addDetections(obj.tracker, imgGray, bbox);
                    bbox = floor(obj.tracker.Bbox); % some detections might have been deleted in call to addDetections
                elseif ~isempty(obj.tracker.Bbox) % Use tracker instead
                    try
                        track(obj.tracker,imgGray);
                        bbox = floor(obj.tracker.Bbox);
                    catch me
                        if me.identifier == "vision:points:notEnoughMatchedPts"
                            bbox = resetDueToFailedTrack(obj);
                        else
                            throw(me)
                        end
                    end
                end
            else
                obj.tracker.FailToTrackFace = checkIfEnoughPointsForTracking(obj);
                if ~obj.tracker.FailToTrackFace
                    try
                        track(obj.tracker,imgGray);
                        bbox = floor(obj.tracker.Bbox);
                    catch me
                        if me.identifier == "vision:points:notEnoughMatchedPts"
                            bbox = resetDueToFailedTrack(obj);
                        else
                            throw(me)
                        end
                    end
                else
                    bbox = resetDueToFailedTrack(obj);
                end
            end

            if ~isempty(bbox)
                obj.tracker.FailToTrackFace = false;
                bufx = floor(obj.faceMargin*bbox(:,3));
                bufy = floor(obj.faceMargin*bbox(:,4));
                xs = max(bbox(:,1)-bufx, 1);
                ys = max(bbox(:,2)-bufy, 1);
                xe = min(bbox(:,1)+bbox(:,3)-1+bufx,obj.origSize(1));
                ye = min(bbox(:,2)+bbox(:,4)-1+bufy,obj.origSize(2));
                faces = cell(1,1,1,size(bbox,1),1);
                for k = 1:size(bbox,1)
                    faces{k} = origImg(ys(k):ye(k),xs(k):xe(k),:);
                end

                % Rescale all cropped faces to required size by the network
                if obj.detectAge || obj.detectGender
                    facesForAgeGenderDetection = cellfun(@(face)imresize(face,obj.genderAgeDetectionSize),faces,"UniformOutput",false);
                    facesForAgeGenderDetection = cell2mat(facesForAgeGenderDetection);
                end
                if obj.detectEmotion
                    % Needs additional cropping to match the dataset
                    sizeFaces = cellfun(@size,faces,"UniformOutput",false);
                    facesForEmotionDetection = cell(1,1,1,size(bbox,1),1);
                    for k = 1:size(bbox,1)
                        facesForEmotionDetection{k} = faces{k}(round(obj.faceMargin/2*sizeFaces{k}(1)):sizeFaces{k}(1),round(obj.faceMargin/2*sizeFaces{k}(2)):round(sizeFaces{k}(2)-obj.faceMargin/2*sizeFaces{k}(2)),:);
                    end
                    facesForEmotionDetection = cellfun(@(face)imresize(im2single(rgb2gray(face)),obj.emotionDetectionSize),facesForEmotionDetection,"UniformOutput",false);
                    facesForEmotionDetection = cell2mat(facesForEmotionDetection);
                end

                if length(faces) < obj.numFacesBatch(1) || length(faces) > obj.numFacesBatch(2) || ~coder.target('MATLAB') % Not many faces in the image
                    if obj.detectAge || obj.detectGender
                        % Run gender detection
                        if obj.detectGender
                            pouts_gender = zeros(length(faces),size(obj.genders,2));
                            for k = 1:size(bbox,1)
                                if exist("predictGender_mex","file") == 3 && coder.target('MATLAB')
                                    pouts_gender(k,:) = predictGender_mex(facesForAgeGenderDetection(:,:,:,k),obj.matfileGender);
                                else
                                    pouts_gender(k,:) = predictGender(facesForAgeGenderDetection(:,:,:,k),obj.matfileGender);
                                end
                            end
                        end
                        % Run age detection
                        if obj.detectAge
                            pouts_age = zeros(length(faces),size(obj.ages,2));

                            for k = 1:size(bbox,1)
                                if exist("predictGender_mex","file") == 3 && coder.target('MATLAB')
                                    pouts_age(k,:) = predictAge_mex(facesForAgeGenderDetection(:,:,:,k),obj.matfileAge);
                                else
                                    pouts_age(k,:) = predictAge(facesForAgeGenderDetection(:,:,:,k),obj.matfileAge);
                                end
                            end
                        end
                    end
                    if obj.detectEmotion
                        pouts_emotion = zeros(length(faces),size(obj.emotions,2));

                        for k = 1:size(bbox,1)
                            if exist("predictGender_mex","file") == 3 && coder.target('MATLAB')
                                pouts_emotion(k,:) = predictEmotion_mex(facesForEmotionDetection(:,:,:,k),obj.matfileEmotion);
                            else
                                pouts_emotion(k,:) = predictEmotion(facesForEmotionDetection(:,:,:,k),obj.matfileEmotion);
                            end
                        end
                    end

                else % Place is getting crowded. Run inference in batches
                    if obj.detectAge || obj.detectGender
                        % Run gender detection
                        if obj.detectGender
                            pouts_gender = predictGender(facesForAgeGenderDetection,obj.matfileGender);
                        end

                        % Run age detection
                        if obj.detectAge
                            pouts_age = predictAge(facesForAgeGenderDetection,obj.matfileAge);
                        end
                    end

                    % Run emotion detection
                    if obj.detectEmotion
                        pouts_emotion = predictEmotion(facesForEmotionDetection,obj.matfileEmotion);
                    end
                end

                % Compute gender, age and emotion values based upon buffered data
                for k = 1:size(bbox,1)
                    detectionString = "";

                    if obj.detectAge || obj.detectGender
                        if obj.detectGender
                            % Compute gender considering previous values in buffer
                            gender = genderPredictionBuffer(obj,pouts_gender(k,:),k,obj.genderMovingAverageWindow);
                            detectionString = detectionString + gender;
                        end
                        if obj.detectAge
                            % Compute age considering previous values in buffer
                            p_age = agePredictionBuffer(obj,pouts_age(k,:),k,obj.ageMovingAverageWindow);
                            if detectionString ~= ""
                                detectionString = detectionString + ", "; %#ok<*AGROW>
                            end
                            detectionString = detectionString + sprintf("Age %d",int8(p_age));
                        end
                    end

                    if obj.detectEmotion
                        % Compute emotion considering previous values in buffer
                        emotion = emotionPredictionBuffer(obj,pouts_emotion(k,:),k,obj.emotionMovingAverageWindow);
                        if detectionString ~= ""
                            detectionString = detectionString + ", ";
                        end
                        detectionString = detectionString + emotion;
                    end

                    % Overlay data on the image
                    img = overlayResult(obj,img,bbox(k,:),detectionString);
                end
            end

            elapsedTime = toc;
            obj.fps = 0.9*obj.fps+0.1*(1/elapsedTime);

            % Overlay fps
            if obj.debugMode && ~isempty(bbox)
                img = insertMarker(img,obj.tracker.Points);
                img = insertText(img,bbox(:,1:2)+[zeros(size(bbox,1),1),bbox(:,4)],"Person "+num2str(obj.tracker.BoxIds),"BoxColor",obj.backgroundColor,"TextColor",obj.textColor);
                img = insertText(img,[1,1],sprintf("FPS %2.2f",obj.fps),"FontSize",obj.fontSize,"BoxColor",obj.backgroundColor);
            end

            frameNumber = frameNumber + 1;
        end

        function gender = genderPredictionBuffer(obj,genderProbs,idx,numObs)
            persistent genderProbsBuffer;
            if isempty(genderProbsBuffer) % Initialize memory for buffer
                genderProbsBuffer = containers.Map(0,nan(numObs,size(genderProbs,2)));
            end
            if ~isKey(genderProbsBuffer,obj.tracker.BoxIds(idx)) % Initialize buffer for new detected face
                genderProbsBuffer(obj.tracker.BoxIds(idx)) = genderProbsBuffer(0);
            end
            % Remove any deleted Id from gender buffer
            keys = cell2mat(genderProbsBuffer.keys);
            keysToRemove = setdiff(keys(2:end),obj.tracker.BoxIds);
            if ~isempty(keysToRemove)
                remove(genderProbsBuffer,num2cell(keysToRemove));
            end

            currentFaceProbsBuffer = genderProbsBuffer(obj.tracker.BoxIds(idx));
            currentFaceProbsBuffer = [currentFaceProbsBuffer(2:numObs,:);genderProbs];
            genderProbsBuffer(obj.tracker.BoxIds(idx)) = currentFaceProbsBuffer;

            [genderProb,genderIdx] = max(currentFaceProbsBuffer,[],2);
            gender = obj.genders(mode(genderIdx(~isnan(genderProb))));
        end

        function age = agePredictionBuffer(obj,ageProbs,idx,numObs)
            persistent ageProbsBuffer;
            if isempty(ageProbsBuffer) % Initialize memory for buffer
                ageProbsBuffer = containers.Map(0,nan(numObs,size(ageProbs,2)));
            end
            if ~isKey(ageProbsBuffer,obj.tracker.BoxIds(idx)) % Initialize buffer for new detected face
                ageProbsBuffer(obj.tracker.BoxIds(idx)) = ageProbsBuffer(0);
            end
            % Remove any deleted Id from age buffer
            keys = cell2mat(ageProbsBuffer.keys);
            keysToRemove = setdiff(keys(2:end),obj.tracker.BoxIds);
            if ~isempty(keysToRemove)
                remove(ageProbsBuffer,num2cell(keysToRemove));
            end

            currentFaceProbsBuffer = ageProbsBuffer(obj.tracker.BoxIds(idx));
            currentFaceProbsBuffer = [currentFaceProbsBuffer(2:numObs,:);ageProbs];
            ageProbsBuffer(obj.tracker.BoxIds(idx)) = currentFaceProbsBuffer;

            age = round(median(currentFaceProbsBuffer * (obj.ages + 1)'-1,'omitnan')); % Account for age 0
        end

        function emotion = emotionPredictionBuffer(obj,emotionProbs,idx,numObs)
            persistent emotionProbsBuffer;
            if isempty(emotionProbsBuffer) % Initialize memory for buffer
                emotionProbsBuffer = containers.Map(0,nan(numObs,size(emotionProbs,2)));
            end
            if ~isKey(emotionProbsBuffer,obj.tracker.BoxIds(idx)) % Initialize buffer for new detected face
                emotionProbsBuffer(obj.tracker.BoxIds(idx)) = emotionProbsBuffer(0);
            end
            % Remove any deleted Id from gender buffer
            keys = cell2mat(emotionProbsBuffer.keys);
            keysToRemove = setdiff(keys(2:end),obj.tracker.BoxIds);
            if ~isempty(keysToRemove)
                remove(emotionProbsBuffer,num2cell(keysToRemove));
            end

            currentFaceProbsBuffer = emotionProbsBuffer(obj.tracker.BoxIds(idx));
            currentFaceProbsBuffer = [currentFaceProbsBuffer(2:numObs,:);emotionProbs];
            emotionProbsBuffer(obj.tracker.BoxIds(idx)) = currentFaceProbsBuffer;

            [emotionProb,emotionIdx] = max(currentFaceProbsBuffer,[],2);
            emotion = obj.emotions(mode(emotionIdx(~isnan(emotionProb))));
        end

        function img = overlayResult(obj,img,newpts,detectionString)
            coder.inline('never')
            % Overlay data on the image
            if ~isempty(detectionString)
                img = insertObjectAnnotation(img,"rectangle",newpts,detectionString,"LineWidth",obj.bboxLineWidth,"Color",obj.backgroundColor,"TextColor",obj.textColor,"FontSize",obj.fontSize,"TextBoxOpacity",1);
            else
                img = insertShape(img,"rectangle",newpts,"LineWidth",obj.bboxLineWidth,"Color",obj.backgroundColor);
            end
        end

        function failToTrackFace = checkIfEnoughPointsForTracking(obj)
            failToTrackFace = false;
            numPoints = zeros(size(obj.tracker.BoxIds));
            for i = 1:length(obj.tracker.BoxIds)
                numPoints(i) = sum(obj.tracker.PointIds==obj.tracker.BoxIds(i));
            end
            if any(numPoints < 10)
                failToTrackFace = true;
            end
        end

        function bbox = resetDueToFailedTrack(obj)
            nextId = obj.tracker.NextId;
            reset(obj.tracker);
            obj.tracker.NextId = nextId;
            bbox = [];
        end

        function verifyMATFiles(obj)
            % Ensure models are available
            if ~exist(obj.matfileFace,"file") || (obj.detectGender && ~exist(obj.matfileGender,"file")) || ...
                    (obj.detectAge && ~exist(obj.matfileAge,"file")) || (obj.detectEmotion && ~exist(obj.matfileEmotion,"file"))
                error("Run downloadAndSetupNetworks.m to download the required deep learning models.");
            end
        end

        function verifyMEXFiles(obj)
            % Ensure MEX files are available
            for i = 1:numel(obj.mexFiles)
                if ~exist(obj.mexFiles{i},"file")
                    warning("Run generateCode.m to accelerate your code using GPU Coder");
                end
            end
        end

        function release(obj)
            release(obj.tracker.PointTracker);
            release(obj.faceDetector)
            release(obj.eyesDetector)
        end

    end
end
