function [success] = RecordAndSaveInWav(myOSCConnection, fileOutName, fileOutPath,  sourcelocations, fs, recordDurationLength, irLength, recordingMode) 
    try                                                                 
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
            wavFileName = strcat(fileOutName,'_azimuth_',num2str(currentAzimuth),'_elevation_',num2str(currentElevation));
            wavFileName = sprintf(strcat(wavFileName,'__%s.wav'), datestr(now,'dd-mm-yyyy HH-MM'));                        
            wavFullFileName = fullfile(fileOutPath,wavFileName);

            [success, wavFileName] = recordStereoWAV(wavFullFileName,recordData.Data.Receiver(1,(1:irLength)), recordData.Data.Receiver(2,(1:irLength)),str2double(fs), 24);
            if (~success)                
                return;
            end
            clear recordData;
            DeleteFile(recordFilepath);
            irNumber = irNumber+1;           
        end                 
        success = true;

    catch ME          
        success = false;
    end

end

%%
function [success, fileOutName] = recordStereoWAV(fullFilePath, leftChannelSamples, rightChannelSamples, sampleRate, bitDepth)
    %RECORDSTEREOWAV Records a stereo WAV audio file.
    %
    %   recordStereoWAV(fullFilePath, leftChannelSamples, rightChannelSamples, sampleRate, bitDepth)
    %
    %   Input Parameters:
    %     fullFilePath      - Character string specifying the full path and
    %                         name of the WAV file to create (e.g., 'C:\audio\my_audio.wav').
    %     leftChannelSamples - Numeric vector containing the samples for the left channel.
    %     rightChannelSamples- Numeric vector containing the samples for the right channel.
    %     sampleRate        - Sample rate in Hz (e.g., 44100, 48000).
    %     bitDepth          - Bit depth for the WAV file (e.g., 16, 24, 32).
    %                         Common options are:
    %                         - 8 (uint8)
    %                         - 16 (int16)
    %                         - 24 (int16 for export in Matlab, but the file can be true 24-bit)
    %                         - 32 (single or float)
    %
    %   Example Usage:
    %     fs = 44100; % Sample rate
    %     dur = 5;    % Duration in seconds
    %     t = 0:1/fs:dur-1/fs;
    %     left_audio = 0.8 * sin(2*pi*440*t);  % 440 Hz tone
    %     right_audio = 0.8 * sin(2*pi*880*t); % 880 Hz tone
    %
    %     % Record as 16-bit WAV
    %     recordStereoWAV('my_audio_16bit.wav', left_audio, right_audio, fs, 16);
    %     disp('File "my_audio_16bit.wav" created.');
    %
    %     % Record as 32-bit (floating point) WAV
    %     recordStereoWAV('my_audio_32bit.wav', left_audio, right_audio, fs, 32);
    %     disp('File "my_audio_32bit.wav" created.');
    success = false;
    fileOutName ="";
    % Validate inputs
    if ~ischar(fullFilePath) && ~isstring(fullFilePath)
        error('recordStereoWAV:InvalidFilePath', 'The fullFilePath parameter must be a character string.');
    end
    if ~isnumeric(leftChannelSamples) || ~isvector(leftChannelSamples)
        error('recordStereoWAV:InvalidLeftChannel', 'leftChannelSamples must be a numeric vector.');
    end
    if ~isnumeric(rightChannelSamples) || ~isvector(rightChannelSamples)
        error('recordStereoWAV:InvalidRightChannel', 'rightChannelSamples must be a numeric vector.');
    end
    if length(leftChannelSamples) ~= length(rightChannelSamples)
        error('recordStereoWAV:ChannelLengthMismatch', 'Left and right channel vectors must have the same length.');
    end
    if ~isscalar(sampleRate) || ~isnumeric(sampleRate) || sampleRate <= 0
        error('recordStereoWAV:InvalidSampleRate', 'sampleRate must be a positive numeric scalar.');
    end
    if ~ismember(bitDepth, [8, 16, 24, 32])
        error('recordStereoWAV:InvalidBitDepth', 'bitDepth must be 8, 16, 24, or 32.');
    end

    % Ensure vectors are column vectors for the audiowrite function
    leftChannelSamples = leftChannelSamples(:);
    rightChannelSamples = rightChannelSamples(:);

    % Interleave channels to form a stereo matrix (columns: [L, R])
    audioData = [leftChannelSamples, rightChannelSamples];

    % Convert samples to the appropriate range for bit depth.
    % audiowrite handles this automatically if the data type is correct,
    % but it's good practice to ensure floating-point data is within [-1, 1].
    if ~isfloat(audioData)
        % If data is not floating-point (e.g., int16 from a read operation), convert it.
        % However, if it comes from generation like sin(2*pi*f*t), it will already be floating-point.
        % Ensure floating-point data is in the range [-1, 1].
        % Normalization is crucial before writing if the original range is unknown.
        % Here, we assume the data is already scaled to its appropriate range
        % or that audiowrite will normalize it if it's floating-point.
        % For 16, 24, 32 bits, audiowrite prefers float in [-1, 1]
        % and maps it automatically. For 8-bit, it prefers uint8 in [0, 255].
        %
        % For audiowrite, if data is 'double' or 'single', values
        % must be in the range [-1, 1]. If they exceed this range, they will be clipped.
        % If data is integer, it will be mapped to the bit depth values.
        % It's best to work with floats in [-1, 1] and let audiowrite handle the mapping.
        % If your input data is already in [-1, 1] (as in the example), no normalization is needed.
        % If your data comes from a source that doesn't scale it to [-1,1], you should normalize it:
        % audioData = audioData / max(abs(audioData(:))); % This is a common normalization.
        return;
    end

    try
        % Write the WAV file
        audiowrite(fullFilePath, audioData, sampleRate, 'BitsPerSample', bitDepth);
        fprintf('WAV file "%s" created successfully with %d bits and %d Hz.\n', fullFilePath, bitDepth, sampleRate);
        success = true;
        fileOutName = fullFilePath;
    catch ME
        fprintf('Error attempting to record WAV file: %s\n', ME.message);
        rethrow(ME); % Rethrow the exception so the calling code can handle it
    end
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