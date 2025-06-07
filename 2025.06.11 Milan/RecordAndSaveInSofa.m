function [success, returnFileName] = RecordAndSaveInSofa(myOSCConnection, fileOutName, fileOutPath,  sourcelocations, fs, recordDurationLength, irLength, recordingMode) 
    try                                                        
        % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Start SOFA Struct
        % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %Init SOFA DATA
        Obj = InitSofaObject();
        Obj = SizingSofaDataStructure(Obj, length(sourcelocations), irLength);       
        
    
        % Recorres la matriz de localizaciones de la fuente
        irNumber =1;    
        for sourceIndex = 1:length(sourcelocations)        
            currentAzimuth      = sourcelocations(sourceIndex, 1, 1);
            currentElevation    = sourcelocations(sourceIndex, 2, 1);
            currentDistance     = sourcelocations(sourceIndex, 3, 1);
    
            % Place the source     
            [x,y,z] = sph2cart(deg2rad(currentAzimuth), deg2rad(currentElevation), currentDistance);
            myOSCConnection.sendSourceLocation('source1', x, y, z);
    
            % Start Play and Record
            tempMatPath = strcat(GetThisFilePath(), '\temp.mat');
            DeleteFile(tempMatPath);            
            if (strcmp(recordingMode,"online"))
                [success, message] = myOSCConnection.sendPlayAndRecordAndWaitResult(tempMatPath, 'mat', recordDurationLength);            
            else 
                [success, message] = myOSCConnection.sendRecordAndWaitResult(tempMatPath, 'mat', recordDurationLength);                        
            end
            %disp(message);
            myOSCConnection.sendStop();
            if (~success)
                ME = MException('send Record', 'Error recording');
                throw(ME);
            end             
            recordFilepath = extractFilePath(message);
            if (success)
                disp(strcat("Recording ", num2str(irNumber), " of ", num2str(length(sourcelocations)), " done => Azimuth ", num2str(currentAzimuth), ", elevation ", num2str(currentElevation), ", distance ", num2str(currentDistance)));                
            else
                disp("Error trying to record azimuth ", num2str(currentAzimuth), ", elevation ", num2str(currentElevation));                               
                return;
            end
            %pause(0.1);    
            
            % Open record results file. It is a .mat file 
            recordData=load(recordFilepath);        
         
            % Copy data to SOFA Struct    
            Obj.Data.IR(irNumber, 1,:) = recordData.Data.Receiver(1,(1:irLength));
            Obj.Data.IR(irNumber, 2,:) = recordData.Data.Receiver(2,(1:irLength));                        
            [recordAzimuth, recordElevation, recordDistante] = cart2sph(recordData.EmitterPosition(1,1,1), recordData.EmitterPosition(1,2,1), recordData.EmitterPosition(1,3,1));                        
            Obj.SourcePosition(irNumber,:) = [CalculateAzimuthIn0_360Range(rad2deg(recordAzimuth)), rad2deg(recordElevation), recordDistante];
           
            clear recordData;
            DeleteFile(recordFilepath);
            irNumber = irNumber+1;           
        end
    
        % Save data into the SOFA file
        Obj = CompleteSofaObject(Obj, "Virtual Listener", fs, "virtually using BeRTA"); 
        
        %[filepath,fileName, ext] = fileparts(fileOutName);
        finalSofaFileName = sprintf(strcat(fileOutName, '_%s.sofa'), datestr(now,'dd-mm-yyyy HH-MM'));
        returnFileName = SaveSofaFile(Obj, fileOutPath, finalSofaFileName);                        
        success = true;

    catch ME          
        success = false;
    end

end

%%
function azimuth = CalculateAzimuthIn0_360Range(azimuth) 
    if (azimuth < 0) 
		azimuth = mod(azimuth, 360);			
    elseif (azimuth >= 360) 
		azimuth = mod(azimuth, 360);		
	else 
		%DO nothing			
    end
end
			

%% Initialize a Sofa Object
function Obj = InitSofaObject()
    addpath('..\API_MO\SOFAtoolbox\');       
    SOFAstart;
    Obj = SOFAgetConventions('SimpleFreeFieldHRIR');
end

%% Sizing the SOFA DATA structure
function Obj = SizingSofaDataStructure(Obj, matrixSize, irLength)
    if (Obj.Data.IR == [0 0])
        M=matrixSize;%azimuthLength*elevationLength;
        N=irLength;
        Obj.Data.IR = NaN(M,2,N); % data.IR must be [M R N]
    end
end

%% Complete SOFA data                
function Obj = CompleteSofaObject(Obj, subjectID, fs, place)
    Obj.Data.SamplingRate = str2num(fs);    
    
    Obj.ListenerPosition = [0 0 0];
    Obj.ListenerView = [1 0 0];
    Obj.ListenerUp = [0 0 1];
    % Update dimensions
    Obj=SOFAupdateDimensions(Obj);
    % Fill with attributes
    Obj.GLOBAL_ListenerShortName = convertStringsToChars(subjectID);
    %Obj.GLOBAL_History = 'recorded in DIANA Research group treated room';
    Obj.GLOBAL_History = convertStringsToChars(strcat("recorded in ", place));    
    Obj.GLOBAL_DatabaseName = 'none';
    Obj.GLOBAL_ApplicationName = 'BeRTA_Virtual_Measurement';
    Obj.GLOBAL_ApplicationVersion = SOFAgetVersion('API');
    Obj.GLOBAL_Organization = 'DIANA Research Group. University of Malaga';
    Obj.GLOBAL_AuthorContact = 'areyes@uma.es';
    Obj.GLOBAL_Comment = 'Contains IR responses recorder using BRT application';       
end

%% Save SOFA file 
function SOFAfn = SaveSofaFile(Obj, pathToSaveFiles, fileName)
    % save the SOFA file    
    compression=1; % results in a nice compression within a reasonable processing time        
    pathToSaveFilesS = convertStringsToChars(pathToSaveFiles);
    fileNameS = convertStringsToChars(fileName);
    SOFAfn=fullfile(pathToSaveFilesS,fileNameS);
    disp(['Saving:  ' SOFAfn]);
    Obj=SOFAsave(SOFAfn, Obj, compression);    
end

%% Get file Path
function workingPath = GetThisFilePath()
    % Get the full call stack.
    stk = dbstack('-completenames');
    
    % stk(1) refers to the current function.
    % .file contains the complete absolute path of the function's file.
    filepath = stk(1).file;
    
    % Use fileparts to separate the directory path, filename, and extension.
    % We are only interested in the directory path.
    [pathstr, ~, ~] = fileparts(filepath);
    
    % Assign the directory path to the output variable.
    workingPath = pathstr;
end


%% Get FS from BeRTA
function fs = GetFSFromBeRTA(sender, oscServer, oscListener)
    disp("Sending ControlSampleRate...");    
    BeRTAOSCAPI.SendControlSampleRate(sender);    
    [address, parameters] = BeRTAOSCAPI.WaitMessage(oscServer, oscListener);       
    if (address == "/control/sampleRate")
        fs = parameters(1);
    else 
        fs = 0;
    end
end

%% Delete file
function DeleteFile(fullFilePath)
    % Check if the file exists.
    if exist(fullFilePath, 'file') == 2 % 'file' and 2 confirm it's a file, not a folder or variable.
        % If it exists, delete the file.
        delete(fullFilePath);
    end
end

%% extractFilePath
function filePath = extractFilePath(textString)
    % Extracts the file path and name from a given text string.
    %
    % Input:
    %   textString - A string containing the message, e.g.,
    %                "Recording completed. File saved : D:\Repos\3daudio\bilateralambisonicsevaluation\temp.mat"
    %
    % Output:
    %   filePath - The extracted full file path, e.g.,
    %              "D:\Repos\3daudio\bilateralambisonicsevaluation\temp.mat"

    % Define the pattern to search for. We expect the path to follow "File saved : "
    % and to end with a file extension (e.g., .mat, .txt, etc.).
    % We use a regular expression to capture everything after "File saved : "
    % and before the end of the string.
    
    % The regex pattern explained:
    % (?:File saved : ) - Non-capturing group for the literal string "File saved : "
    % (.*)              - Capturing group for any characters (the file path itself)
    %                      until the end of the string.
    pattern = '(?:File saved : )(.*)'; 
    
    % Use regexp to find the pattern and extract the captured group.
    tokens = regexp(textString, pattern, 'tokens', 'once');
    
    % Check if a match was found.
    if ~isempty(tokens)
        % The extracted file path is the first token.
        filePath = tokens{1};
    else
        % If no match is found, return an empty string or handle the error as appropriate.
        warning('No file path found in the input string.');
        filePath = ''; 
    end
end