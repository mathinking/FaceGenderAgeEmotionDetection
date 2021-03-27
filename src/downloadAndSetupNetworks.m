% Copyright 2018-2020 The MathWorks, Inc.

% References to pretrained models:
% [1] Abars, Face Search VGG16, (2018). GitHub repository, 
%     https://github.com/abars/FaceSearchVGG16
% [2] Rasmus Rothe, Radu Timofte and Luc Van Gool, (2016). Deep expectation
%     of real and apparent age from a single image without facial 
%     landmarks. International Journal of Computer Vision (IJCV)
% [3] Jia, Yangqing, et al., (2014). "Caffe: Convolutional architecture for 
%     fast feature embedding." Proceedings of the 22nd ACM international 
%     conference on Multimedia. ACM.

% Run function to download and prepare the networks
function downloadAndSetupNetworks(downloadGender)

    if nargin < 1
        downloadGender = false;
    end

    modelFolder = 'models';
    mkdir(modelFolder)
    modelFaceYolo = 'net_face_yolo';
    modelAge = 'net_age';
    modelGender = 'net_gender';
    ageGenderMeanImage = 'age_gender_mean';
    insertIntoProtoFile = @(modelFolder,filename,DataType) cat(2, ...
        'layer {', newline,'  top: "data"', newline, '  top: "label"', newline, ...
        '  name: "data"', newline, '  type: ', DataType, newline, ... 
        '  transform_param {', newline, '    crop_size: 224', newline, ...
        '    mirror: false', newline, ...
        '    mean_file: "', modelFolder, '/', filename, '.binaryproto"', newline, ...
        '  }', newline, '  include: { ', newline, '    phase: TEST', newline, ...
        '    stage: "test-on-test"', newline, ' }', newline, '}', newline);
    options = weboptions('ContentType','text');

    if downloadGender
        downloadSize = '1.16GB';
    else
        downloadSize = '684MB';
    end
    cont = input(sprintf('You will be downloading ~%s of pretrained networks. Continue? [Y/N]: ',downloadSize),'s');
        
    if lower(cont) ~= 'y'
        return;
    end

    % Download Caffe model and protofile for face detection.
    % Source: https://github.com/abars/FaceSearchVGG16
    if ~isfile(fullfile(modelFolder,[modelFaceYolo,'.mat']))
        fprintf(1,'Downloading Caffe model for face detection...');
        netFaceYoloModelFilename = websave(fullfile(modelFolder,[modelFaceYolo,'.caffemodel']), ...
            'http://www.abars.biz/keras/face.caffemodel');
        netFaceYoloProtoFilename = websave(fullfile(modelFolder,[modelFaceYolo,'_deploy.prototxt']), ...
            'http://www.abars.biz/keras/face.prototxt');
    
        fprintf(1,'[DONE]\n')
    end

    % Download Mean Image for age and gender classification.
    % Source: https://github.com/BVLC/caffe
    if ~isfile(fullfile(modelFolder,[ageGenderMeanImage,'.binaryproto']))
        fprintf(1,'Downloading mean image for age (and gender) classification...')
    
        % Download binaryproto
        ageGenderAuxiliaryFiles = websave(fullfile(modelFolder,'caffe_ilsvrc12.tar.gz'), ...
            'http://dl.caffe.berkeleyvision.org/caffe_ilsvrc12.tar.gz');
        untar(ageGenderAuxiliaryFiles,fullfile(modelFolder,'auxiliaryFiles'))
        copyfile(fullfile(modelFolder,'auxiliaryFiles','imagenet_mean.binaryproto'),...
            fullfile(modelFolder,[ageGenderMeanImage,'.binaryproto']))
        rmdir(fullfile(modelFolder,'auxiliaryFiles'),'s')
        delete(ageGenderAuxiliaryFiles)
    
        fprintf(1,'[DONE]\n')
    end

    % Download Caffe model and protofile for gender classification.
    % Source: https://data.vision.ee.ethz.ch/cvl/rrothe/imdb-wiki/
    if downloadGender
        if ~isfile(fullfile(modelFolder,[modelGender,'.mat']))
            fprintf(1,'Downloading Caffe model for gender classification...');
            netGenderModelFilename = websave(fullfile(modelFolder,[modelGender,'.caffemodel']), ...
                'https://data.vision.ee.ethz.ch/cvl/rrothe/imdb-wiki/static/gender.caffemodel');

            % Download and modify gender protofile to include mean image
            netGenderProtoFile = webread('https://data.vision.ee.ethz.ch/cvl/rrothe/imdb-wiki/static/gender.prototxt',options);   
            netGenderProtoFile = [netGenderProtoFile(1:29),insertIntoProtoFile(modelFolder,ageGenderMeanImage,'"ImageData"'),netGenderProtoFile(100:end)];
            netGenderProtoFilename = fullfile(modelFolder,[modelGender,'_deploy.prototxt']);
            fid = fopen(netGenderProtoFilename,'wt');    
            fprintf(fid,'%s',netGenderProtoFile);
            fid = fclose(fid); %#ok<NASGU>

            fprintf(1,'[DONE]\n')
        end
    end

    % Download Caffe model and protofile for age classification.
    % Source: https://data.vision.ee.ethz.ch/cvl/rrothe/imdb-wiki/
    if ~isfile(fullfile(modelFolder,[modelAge,'.mat']))
        fprintf(1,'Downloading Caffe model for age classification...');
        netAgeModelFilename = websave(fullfile(modelFolder,[modelAge,'.caffemodel']), ...
            'https://data.vision.ee.ethz.ch/cvl/rrothe/imdb-wiki/static/dex_chalearn_iccv2015.caffemodel');
    
        % Download and modify age protofile to include mean image
        netAgeProtoFile = webread('https://data.vision.ee.ethz.ch/cvl/rrothe/imdb-wiki/static/age.prototxt',options);   
        netAgeProtoFile = [netAgeProtoFile(1:29),insertIntoProtoFile(modelFolder,ageGenderMeanImage,'"ImageData"'), netAgeProtoFile(100:end)];
        netAgeProtoFilename = fullfile(modelFolder,[modelAge,'_deploy.prototxt']);
        fid = fopen(netAgeProtoFilename,'wt');    
        fprintf(fid,'%s',netAgeProtoFile);
        fid = fclose(fid); %#ok<NASGU>
    
        fprintf(1,'[DONE]\n')
    end

    % Prepare face detection network in MATLAB format
    if ~isfile(fullfile(modelFolder,[modelFaceYolo,'.mat']))
        fprintf(1,'Converting face detection network to MATLAB format...');
        faceYoloNet = importCaffeNetwork(netFaceYoloProtoFilename,netFaceYoloModelFilename,'OutputLayerType','regression');    
        save(fullfile(modelFolder,modelFaceYolo),'faceYoloNet');
        fprintf(1,'[DONE]\n')
    end

    % Average image will be resized. Disabling warning to avoid confusing the
    % user. Numerical differences due to resizing are minimal.
    warnStruct = warning('query','nnet_cnn:caffe_importer:AverageImageResized');
    if warnStruct.state == "on"
        warning('off','nnet_cnn:caffe_importer:AverageImageResized');
    end

    % Prepare gender classification network in MATLAB format
    if downloadGender
        if ~isfile(fullfile(modelFolder,[modelGender,'.mat']))
            fprintf(1,'Converting gender classification network to MATLAB format...');
            classes = ["female","male"];
            genderNet = importCaffeNetwork(netGenderProtoFilename,netGenderModelFilename,'Classes',classes,'InputSize',[224,224,3]); % Average image to be taken from protofile
            save(fullfile(modelFolder,modelGender),'genderNet');
            fprintf(1,'[DONE]\n')
        end
    end

    % Prepare age classification network in MATLAB format
    if ~isfile(fullfile(modelFolder,[modelAge,'.mat']))
        fprintf(1,'Converting age classification network to MATLAB format...');
        classes = string(0:100);
        ageNet = importCaffeNetwork(netAgeProtoFilename,netAgeModelFilename,'Classes',classes,'InputSize',[224,224,3]);  % Average image to be taken from protofile
        save(fullfile(modelFolder,modelAge),'ageNet');
        fprintf(1,'[DONE]\n')
    end

    % Reset warning to previous state if originally active
    if warnStruct.state == "on"
        warning('on','nnet_cnn:caffe_importer:AverageImageResized');
    end
end