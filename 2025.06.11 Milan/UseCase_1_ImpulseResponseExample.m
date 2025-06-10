try 
    clear all;
    clc;    
    addpath("..\BeRTAOSCAPI_matlab\");    
    
    %% Connect to BeRTA        
    % 1. Create an instance of the class (call constructor)    
    myIP ='127.0.0.1';
    listenPort = 12301;
    senderIP ='127.0.0.1';  % BeRTA IP
    senderPort = 10017;     % BeRTA port    
    
    myOSCConnection = BeRTAOSCAPI(myIP, listenPort, senderIP, senderPort);
    
    % Open connection to send messages to BeRTA                     
    [success, message] = myOSCConnection.sendControlConnectAndWaitResponse(myIP, listenPort);            
    disp(message);
    if (~success)
        disp('Error starting connection with BeRTA');
        ME = MException('sendControlConnect', 'Error starting connection with BeRTA');
        throw(ME);        
    end  
          
    %% Load HRTF  
    % myOSCConnection.sendRemoveHRTF("HRTF1");
    % 
     sofaPaths = "resources\HRTF\";    
     sofaToBeUsed = "3DTI_HRTF_SADIE_II_D2_256s_48000Hz.sofa";
     loadSofaSpatialResolution = 15;
    % 
    % [success, message] = myOSCConnection.sendLoadHRTFAndWaitResult("hrtf1", strcat(sofaPaths,sofaToBeUsed), loadSofaSpatialResolution); 
    % disp(message);
    % if (~success)
    %     ME = MException('sendLoadHRTF', 'Error loading the HRTF');
    %     throw(ME);
    % end  

    %% Load NearField Effect filter
    % sosFilterPath = "resources\SOSFilters\";    
    % sosFilterToBeUsed = "NearFieldCompensation_ILD_1.2m_48Khz.sofa";
    % [success, message] = myOSCConnection.sendLoadSOSFiltersAndWaitResult("NFFilters", strcat(sosFilterPath, sosFilterToBeUsed));
    % disp(message);
    % if (~success)
    %     ME = MException('sendLoadSOSFilters','Error loading SOS filter');
    %     throw(ME);
    % end
    
    %% CONFIGURE MODELS 
    [success, message] = myOSCConnection.sendListenerEnableNearFieldEffectAndWaitResult('DefaultListener', true);  
    disp(message);
    if (~success)
        ME = MException('sendListenerEnableNearFieldEffect','Error setting SOS filter into listener');
        throw(ME);
    end
    
    [success, message] = myOSCConnection.sendEnableModelAndWaitResult('FreeField', false);
    disp(message);
    if (~success)
        ME = MException('sendEnableModel','Error when deactivating the model');
        throw(ME);
    end
    
    [success, message] = myOSCConnection.sendEnableModelAndWaitResult('ReverbPath', false);
    disp(message);
    if (~success)
        ME = MException('sendEnableModel','EError when deactivating the model');
        throw(ME);
    end

    %% Load Sound Source (Impulse response) 
    myOSCConnection.sendRemoveAllSources();

    sourcePath = "C:\Repos\3DAudio\BRTWorkshops\resources\AudioFiles\";
    sourceFileToBeUsed = "impulse16bits48000hz.wav";
    [success, message] = myOSCConnection.sendLoadSourceAndWaitResult('source1', strcat(sourcePath, sourceFileToBeUsed),'SimpleModel');
    disp(message);
    if (~success)
        ME = MException('sendLoadSource', 'Error loading sound source');
        throw(ME);
    end  
          
    %% RECORD LOOP    
    fileOutPath = "C:\Users\Daniel\Desktop\recordings\";
    
    listODistanceToSimulate = [0.2, 0.5];    
    recordDurationLength = 0.1;  % seconds
    irLength = 256;
    spatialResolution = 20;
    recordingMode = "offline"; %online or offline    
    fs = "48000";

    for i = 1:length(listODistanceToSimulate)
        distanceToSimulate = listODistanceToSimulate(i);
        sourcelocations = GetSphereSourceLocations(distanceToSimulate, spatialResolution);
        
        [sofaToBeUsedPath,sofaToBeUsedName, sofaToBeUsedExt] = fileparts(sofaToBeUsed);
        fileOutName = strcat(sofaToBeUsedName, "_Sim_",num2str(distanceToSimulate),"m_with_NearField");

        [success, fileOut] = RecordAndSaveInSofa(myOSCConnection, fileOutName, fileOutPath, sourcelocations, fs, recordDurationLength, irLength , recordingMode);     
        if (~success)
            ME = MException('RecordAndSaveInSofa', 'Error recording and save the SOFA file');
            throw(ME);
        else                
            disp(strcat("File with recordings in : ", fileOut));
        end       
    end

    % Disconnect and close osc sever
    myOSCConnection.sendControlDisconnect();        
    myOSCConnection.closeOscServer();
    clear myOSCConnection;

catch ME    
    if (exist('myOSCConnection', 'var'))
        myOSCConnection.sendControlDisconnect();        
        myOSCConnection.closeOscServer();
    end
    rethrow(ME)
end

%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% EXTRA FUNCTIONS
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% Create source locations vector
function sourceLocations = GetSphereSourceLocations(distanceToSimulate, spatialResolution)
    % Generates source locations on a sphere in spherical coordinates using vectorized operations.
    %
    % Inputs:
    %   distanceToSimulate - The radial distance from the origin (radius of the sphere).
    %   spatialResolution  - The angular step size (in degrees) for azimuth and elevation.
    %
    % Output:
    %   sourceLocations    - An N-by-3 matrix where each row is [azimuth, elevation, radius].

    % Create 1D arrays for azimuth and elevation values
    azimuth_vals = (0:spatialResolution:359)'; % Column vector
    elevation_vals = (-90:spatialResolution:90)'; % Column vector

    % Use ndgrid to create 2D grids of all combinations of azimuth and elevation
    % The output `az` and `el` will be matrices where each element is a combination.
    [az_grid, el_grid] = ndgrid(azimuth_vals, elevation_vals);

    % Reshape the grids into column vectors
    az_col = az_grid(:);
    el_col = el_grid(:);

    % Create a column vector for the distance (it's constant for all points)
    dist_col = repmat(distanceToSimulate, size(az_col));

    % Combine the column vectors into the final sourceLocations matrix
    sourceLocations = [az_col, el_col, dist_col];
end