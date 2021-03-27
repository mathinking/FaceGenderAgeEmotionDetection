% Copyright 2019 The MathWorks, Inc.
function install()   
    thisPath = fileparts(mfilename('fullpath'));
    
    % Add folders to search path
    addpath(fullfile(thisPath, 'src'));
    
    requiredAddOns = ["MATLAB Support Package for USB Webcams",...
                      "Deep Learning Toolbox Importer for Caffe Models",...
                      "GPU Coder Support Package for NVIDIA GPUs",...
                      "GPU Coder Interface for Deep Learning Libraries"];
    
	% Checking for missing Add-Ons
    missingAddOns = true(size(requiredAddOns));
	installedAddOns = matlab.addons.installedAddons;
    
    addOnIdx = 1;
    dashRepeats = 52;
    while addOnIdx <= length(requiredAddOns)
        if ~any(installedAddOns.Name ==  requiredAddOns(addOnIdx))
            missingAddOns(addOnIdx) = true;
        else
            missingAddOns(addOnIdx) = false;
        end
        addOnIdx = addOnIdx + 1;
    end

    if all(~missingAddOns)
        fprintf(1,[repmat('-',1,dashRepeats),'\n']);
        fprintf(1,'All the required Add-Ons are successfully installed.\n');
        fprintf(1,[repmat('-',1,dashRepeats),'\n']);
    else
        fprintf(1,[repmat('-',1,dashRepeats),'\n']);
        fprintf(1,'The following support packages are missing.\nPlease, visit the Add-On Explorer from your HOME tab \nand install the following:\n');
        for missingIdx = find(missingAddOns)
            if ~(missingIdx == 3 || missingIdx == 4)
                fprintf(1,'  - %s\n',requiredAddOns(missingIdx))
            else
                fprintf(1,'  - %s (*)\n',requiredAddOns(missingIdx))
            end
        end
        if ismember([3,4],find(missingAddOns))
            fprintf(1,'(*) only if using GPU Coder\n');
        end
        fprintf(1,[repmat('-',1,dashRepeats),'\n']);
    end
   
    fprintf(1,'You may now download and configure the models \n(if you haven''t already).\n') 
    fprintf(1,'To do so, run the script:\n''downloadAndSetupNetworks.m''.\n');
    fprintf(1,[repmat('-',1,dashRepeats),'\n']);
    fprintf(1,'Also, you may speed up detection by running:\n''generateCode.m''.\n(NVIDIA GPU and GPU support packages required).\n');
    fprintf(1,[repmat('-',1,dashRepeats),'\n']);
    
    cd('src')
end