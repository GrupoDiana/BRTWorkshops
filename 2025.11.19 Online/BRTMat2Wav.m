function [success] = BRTMat2Wav(matFilePath, wavFileName, wavFilePath, fs) 
%BRTMat2Wav This script provides a way to generate a wav file from a .MAT recording made using BeRTA Renderer.
    %   Authors: Daniel González Toledo
    %   Contact: areyesa@uma.es
    %   3DDIANA research group. University of Malaga
    %   Project: SONICOM
    %   Copyright (C) 2025 Universidad de Málaga
    %
    try                                                                 
       % Open record results file. It is a .mat file 
        recordData=load(matFilePath);        
        fs = recordData.Data.SamplingRate;
        % Copy data to SOFA Struct                                   
        %wavFileName = sprintf(strcat(wavFileName,'__%s.wav'), datestr(now,'dd-mm-yyyy HH-MM'));                        
        wavFullFileName = fullfile(wavFilePath,wavFileName);

        [success, wavFileFullName] = recordStereoWAV(wavFullFileName,recordData.Data.Receiver(1,:), recordData.Data.Receiver(2,:),fs, 16);
        if (~success)                
            return;
        end
        clear recordData;                      
        success = true;
    catch ME          
        success = false;
    end
end

    
    %% Save wav file
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
        %sound(audioData, 48000);
        audiowrite(fullFilePath, audioData, sampleRate, 'BitsPerSample', bitDepth);
        fprintf('WAV file "%s" created successfully with %d bits and %d Hz.\n', fullFilePath, bitDepth, sampleRate);
        success = true;
        fileOutName = fullFilePath;
    catch ME
        fprintf('Error attempting to record WAV file: %s\n', ME.message);
        rethrow(ME); % Rethrow the exception so the calling code can handle it
    end
end