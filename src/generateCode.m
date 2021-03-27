% Copyright 2018-2020 The MathWorks, Inc.
currDir = pwd;
cd(fileparts(which(mfilename)))

codegen -args {ones(448,448,3,'uint8'), coder.Constant("models\net_face_yolo.mat")} -config coder.gpuConfig('mex') predictFace   
codegen -args {ones(224,224,3,'uint8'), coder.Constant("models\net_gender.mat")}    -config coder.gpuConfig('mex') predictGender
codegen -args {ones(224,224,3,'uint8'), coder.Constant("models\net_age.mat")}       -config coder.gpuConfig('mex') predictAge
codegen -args {ones(64,64,1,'single'), coder.Constant("models\net_emotion.mat")}   -config coder.gpuConfig('mex') predictEmotion

cd(currDir)