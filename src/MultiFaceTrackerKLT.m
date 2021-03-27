% MultiFaceTrackerKLT implements tracking multiple faces using the
% Kanade-Lucas-Tomasi (KLT) algorithm.

% Copyright 2019-2020 The MathWorks, Inc.

classdef MultiFaceTrackerKLT < handle
    properties
        PointTracker; 
        
        Bbox = []; % M-by-4 matrix of [x y w h] face bounding boxes
        
        BboxPolygon = []; % M-by-8 matrix of [x1 y1 x2 y2 x3 y3 x4 y4] face polygon
        
        BoxIds = zeros(0,1); % M-by-1. Ids associated with each bounding box
        
        BoxScores = zeros(0,1); % M-by-1 array. Low box score means that the face was probably lost

        Points = []; % M-by-2 matrix containing tracked points from all faces

        PointIds = zeros(0,1); % M-by-1 array containing face id associated with each point
        
        NextId = 1; % The next new object will have this id
        
        FailToTrackFace = true; % If few points are being tracked
    end
    
    methods
        function obj = MultiFaceTrackerKLT()
            obj.PointTracker = vision.PointTracker('MaxBidirectionalError',2);
        end
        
        function addDetections(obj,I,bbox)
        % Determines whether a detection belongs to an existing face, or 
        % whether it is a brand new face.
            release(obj.PointTracker);
            for i = 1:size(bbox,1)
                % Determine if the detection belongs to an existing face
                boxIdx = findMatchingFace(obj,bbox(i,:));
                
                if isempty(boxIdx) % This is a brand new face.
                    obj.Bbox = [obj.Bbox;bbox(i,:)];
                    points = detectMinEigenFeatures(I,'ROI',bbox(i,:));
                    points = points.Location;
                    obj.BboxPolygon(end+1,:) = reshape(bbox2points(bbox(i,:))',1,[]); % [x1 y1 x2 y2 x3 y3 x4 y4] 
                    obj.BoxIds(end+1,1) = obj.NextId;
                    idx = ones(size(points,1),1)*obj.NextId;
                    obj.PointIds = [obj.PointIds;idx];
                    obj.NextId = obj.NextId+1;
                    obj.Points = [obj.Points;points];
                    obj.BoxScores(end+1,1) = 1;
                    
                else % The face already exists.
                    currentBoxScore = deleteBox(obj,boxIdx); % Delete the matched box
                    obj.Bbox = [obj.Bbox;bbox(i,:)]; % Replace with new box
                    % Re-detect the points. This is how we replace the
                    % points, which invariably get lost as we track.
                    points = detectMinEigenFeatures(I,'ROI',bbox(i,:));
                    points = points.Location;
                    obj.BboxPolygon(end+1,:) = reshape(bbox2points(bbox(i,:))',1,[]); % [x1 y1 x2 y2 x3 y3 x4 y4]                     
                    obj.BoxIds(end+1,1) = boxIdx;
                    idx = ones(size(points,1),1)*boxIdx;
                    obj.PointIds = [obj.PointIds;idx];
                    obj.Points = [obj.Points;points];                    
                    obj.BoxScores(end+1,1) = currentBoxScore+1;
                end
            end
            
            % Determine which faces are no longer tracked.
            minBoxScore = -2;
            obj.BoxScores(obj.BoxScores<3) = obj.BoxScores(obj.BoxScores<3)-0.5;
            boxesToRemoveIds = obj.BoxIds(obj.BoxScores<minBoxScore);
            while ~isempty(boxesToRemoveIds)
                deleteBox(obj,boxesToRemoveIds(1));
                boxesToRemoveIds = obj.BoxIds(obj.BoxScores<minBoxScore);
            end
            
            % Update the point tracker.
            if isLocked(obj.PointTracker)
                setPoints(obj.PointTracker,obj.Points);
            else
                initialize(obj.PointTracker,obj.Points,I);
            end
        end
                
        function track(obj,I)
            oldPoints = obj.Points;
            [newPoints,isFound] = obj.PointTracker(I);
            visiblePoints = newPoints(isFound,:);
            oldInliers = oldPoints(isFound,:);
            [xform,~,visiblePoints] = estimateGeometricTransform(...
                oldInliers, visiblePoints, 'similarity', 'MaxDistance', 4);
            bBoxPoints = permute(reshape(obj.BboxPolygon',2,4,[]),[2,1,3]);
            pointIds = [];
            points = [];
            for i = 1:size(bBoxPoints,3)
                bBoxPoints(:,:,i) = transformPointsForward(xform,bBoxPoints(:,:,i));
                x1 = min(bBoxPoints(:,1,i));
                y1 = min(bBoxPoints(:,2,i));
                x2 = max(bBoxPoints(:,1,i));
                y2 = max(bBoxPoints(:,2,i));
                obj.Bbox(obj.BoxIds == obj.BoxIds(i),:) = [x1,y1,x2-x1,y2-y1];
                obj.BboxPolygon(obj.BoxIds == obj.BoxIds(i),:) = reshape(bBoxPoints(:,:,i)',1,[]);
                isContainedInBbox = visiblePoints(:,1)>x1 & visiblePoints(:,2)>y1 & visiblePoints(:,1)<x2 & visiblePoints(:,2)<y2;
                pointIds = [pointIds;ones(nnz(isContainedInBbox),1)*obj.BoxIds(i)]; %#ok<AGROW>
                points = [points;visiblePoints(isContainedInBbox,:)]; %#ok<AGROW>
            end
            
            obj.Points = points;
            obj.PointIds = pointIds;
            if ~isempty(obj.Points)
                setPoints(obj.PointTracker,obj.Points);
            end
        end
        
        function reset(obj)
            release(obj.PointTracker)
            reset(obj.PointTracker)
            obj.Bbox = []; 
            obj.BboxPolygon = [];
            obj.BoxIds = zeros(0,1);
            obj.BoxScores = zeros(0,1);
            obj.Points = [];
            obj.PointIds = zeros(0,1);
            obj.NextId = 1;
            obj.FailToTrackFace = true;
        end
    end
    
    methods(Access = private)        
        function boxIdx = findMatchingFace(obj, bbox)
        % Determine if the new detection belongs to any of the tracked faces
            boxIdx = [];
            for i = 1:size(obj.Bbox,1)
                if bboxOverlapRatio(bbox,obj.Bbox(i,:),"Min") > 0.6 
                    boxIdx = obj.BoxIds(i);
                    return;
                end
            end           
        end
        
        function currentScore = deleteBox(obj, boxIdx)
            obj.Bbox(obj.BoxIds == boxIdx,:) = [];
            obj.BboxPolygon(obj.BoxIds == boxIdx,:) = [];
            obj.Points(obj.PointIds == boxIdx,:) = [];
            obj.PointIds(obj.PointIds == boxIdx,:) = [];
            currentScore = obj.BoxScores(obj.BoxIds == boxIdx);
            obj.BoxScores(obj.BoxIds == boxIdx,:) = [];
            obj.BoxIds(obj.BoxIds == boxIdx,:) = []; 
        end
        
        function generateNewBoxes(obj)  
        % Get bounding boxes for each object from tracked points.
            oldBoxIds = obj.BoxIds;
            oldScores = obj.BoxScores;
            obj.BoxIds = unique(obj.PointIds);
            numBoxes = numel(obj.BoxIds);
            obj.Bbox = zeros(numBoxes,4);
            obj.BoxScores = zeros(numBoxes,1);
            for i = 1:numBoxes
                newBox = getBoundingBox(obj,i);
                obj.Bbox(i,:) = newBox;
                obj.BoxScores(i) = oldScores(oldBoxIds == obj.BoxIds(i));
            end
        end
               
        function bbox = getBoundingBox(obj,idx)
            points = obj.Points(obj.PointIds == obj.BoxIds(idx),:);
            x1 = min(points(:,1));
            y1 = min(points(:,2));
            x2 = max(points(:,1));
            y2 = max(points(:,2));
            bbox = [x1,y1,x2-x1,y2-y1];
        end        
    end    
end