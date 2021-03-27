% Copyright 2018-2019 The MathWorks, Inc.
function out = predictGender(img, matfile) 
%#codegen

% A persistent object mynet is used to load the series network object.
% At the first call to this function, the persistent object is constructed and
% setup. When the function is called subsequent times, the same object is reused 
% to call predict on inputs, thus avoiding reconstructing and reloading the
% network object.

persistent genderNet;

if isempty(genderNet)
    genderNet = coder.loadDeepLearningNetwork(matfile);
end

% Pass in input image
out = predict(genderNet,img);