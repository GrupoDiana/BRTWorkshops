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
    %myOSCConnection.sendControlConnect(myIP, listenPort);   
    disp(message);
    if (~success)
        disp('Error starting connection with BeRTA');
        ME = MException('sendControlConnect', 'Error starting connection with BeRTA');
        throw(ME);        
    end  

    %% Load HRTF  
    % myOSCConnection.sendRemoveHRTF("HRTF1");
    % 
    % sofaPaths = "resources\HRTF\";    
    % sofaToBeUsed = "3DTI_HRTF_SADIE_II_D2_256s_48000Hz.sofa";
    % loadSofaSpatialResolution = 15;
    % 
    % [success, message] = myOSCConnection.sendLoadHRTFAndWaitResult("hrtf1", strcat(sofaPaths,sofaToBeUsed), loadSofaSpatialResolution); 
    % disp(message);
    % if (~success)
    %     ME = MException('sendLoadHRTF', 'Error loading the HRTF');
    %     throw(ME);
    % end  
    %% CONFIGURE MODELS 
    [success, message] = myOSCConnection.sendListenerEnableNearFieldEffectAndWaitResult('DefaultListener', true);  
    disp(message);
    if (~success)
        ME = MException('sendListenerEnableNearFieldEffect','Error setting SOS filter into listener');
        throw(ME);
    end
    
    [success, message] = myOSCConnection.sendEnableModelAndWaitResult('FreeField', true);
    disp(message);
    if (~success)
        ME = MException('sendEnableModel','Error when deactivating the model');
        throw(ME);
    end
    
    % [success, message] = myOSCConnection.sendEnableModelAndWaitResult('ReverbPath', true);
    % disp(message);
    % if (~success)
    %     ME = MException('sendEnableModel','Error when deactivating the model');
    %     throw(ME);
    % end
    
    %% Load Sound Source      
    myOSCConnection.sendRemoveAllSources();
    %sourcePath = "resources\";
    %sourceFileToBeUsed = "MusArch_Sample_48kHz_Anechoic_FemaleSpeech.wav";    
    sourcePath = strcat(fileparts(GetMyFolderPath()), '\resources\AudioFiles\');
    sourceFileToBeUsed = "impulse16bits48000hz.wav";

    [success, message] = myOSCConnection.sendLoadSourceAndWaitResult('source1', strcat(sourcePath, sourceFileToBeUsed),'OmnidirectionalModel');
    disp(message);
    if (~success)
        ME = MException('sendLoadSource', 'Error loading sound source');
        throw(ME);
    end  
    
    %% RECORDING ONLINE Loop
    % %recordingdFileName = 'C:\Users\Daniel\Desktop\recordings\movingSource.mat';
    % recordingdFileName = 'movingSource.mat';
    % recordingdFileNameFullPath = strcat(GetMyFolderPath(), '\recordings\', recordingdFileName); 
    % 
    % myOSCConnection.sendPlayAndRecord(recordingdFileNameFullPath, 'mat', -1);
    % 
    % azimuthList = linspace(90, -90, 100);    
    % for sourceIndex = 1:length(azimuthList)        
    %     currentAzimuth      = azimuthList(sourceIndex);
    %     currentElevation    = 0;
    %     currentDistance     = 2;
    %     [x,y,z] = sph2cart(deg2rad(currentAzimuth), deg2rad(currentElevation), currentDistance);
    %     myOSCConnection.sendSourceLocation('source1', x, y, z);
    %     pause(0.1);
    % end
    % myOSCConnection.sendStop();
    % [success, message] = myOSCConnection.waitAndCheckControlActionResult('/playAndRecord');
    % disp(message);
   
    %% RECORDING OFFLINE LOOP    
    filePath = strcat(GetMyFolderPath(), '\recordings\'); 

    azimuthList = linspace(90, -90, 180);    
    for sourceIndex = 1:length(azimuthList)        
        currentAzimuth      = azimuthList(sourceIndex);
        currentElevation    = 0;
        currentDistance     = 2;
        [x,y,z] = sph2cart(deg2rad(currentAzimuth), deg2rad(currentElevation), currentDistance);
        myOSCConnection.sendSourceLocation('source1', x, y, z);

        fileName = strcat(filePath, 'fixedSource_azimuth_', num2str(currentAzimuth),'.mat');
        [success, message] = myOSCConnection.sendRecordAndWaitResult(fileName, 'mat', 1);
        disp(message);
        if (~success)
            ME = MException('sendRecordAndWaitResult', 'Error recording');
            throw(ME);
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


%% Get MyFolfer
function [onlyPath] = GetMyFolderPath()
    fullPath = mfilename('fullpath');
    [onlyPath, ~, ~] = fileparts(fullPath);
    % [onlyPath, ~, ~] = fileparts(which(mfilename)); 
end