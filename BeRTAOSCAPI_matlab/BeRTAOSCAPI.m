classdef BeRTAOSCAPI
    %BERTAOSCAPI This class provides an API for sending and receiving OSC commands
    %   for the hybrid method, encapsulating OSC server and listener logic.
    %   Authors: Daniel González Toledo, María Cuevas Rodriguez
    %   Contact: areyesa@uma.es
    %   3DDIANA research group. University of Malaga
    %   Project: SONICOM
    %   Copyright (C) 2023 Universidad de Málaga

    properties (Access = private)
        % Private properties to hold the OSC server and listener objects
        oscServer % OSCPortIn object for receiving messages
        oscListener % MatlabOSCListener object to handle incoming messages
        sender % UDP object for sending messages
    end
   
    methods
        %% Constructor
        function obj = BeRTAOSCAPI(listenIP, listenPort, senderIP, senderPort)
            %BERTAOSCAPI Constructor for the BeRTAOSCAPI class.
            %   obj = BeRTAOSCAPI(listenPort) initializes the OSC listening server
            %   and sets up the default addresses to listen to.
            %
            % Input:
            %   listenPort - The UDP port number to listen for incoming OSC messages.

            % Add Java OSC library to the MATLAB path
            % This part assumes javaosctomatlab.jar is in the same directory as this .m file.
            stk = dbstack('-completenames');
            filepath = stk(1).file;
            [workingpath, ~, ~] = fileparts(filepath); % Get directory path
            javaLibpath = fullfile(workingpath, "javaosctomatlab.jar");

            % Check if the path is already added to avoid warnings
            currentJavaPath = javaclasspath('-all');
            if ~ismember(javaLibpath, currentJavaPath)
                javaaddpath(javaLibpath);
                %disp(['Added Java library: ', javaLibpath]); % For debugging
            else
                %disp(['Java library already in path: ', javaLibpath]); % For debugging
            end

            import com.illposed.osc.*;
            import java.lang.String; % Import String class for convenience

            % Initialize oscServer property
            obj.oscServer = OSCPortIn(listenPort);

            % Initialize oscListener property and set up default addresses
            obj.oscListener = MatlabOSCListener();

            % Set the list of OSC addresses to listen to
            % Using AddMultipleListenerAddress internally to add all required addresses
            obj = obj.setListOfAddressToListenTo(); % Call the internal method
            
            % Open a UDP connection with a OSC server to send data
            
            obj.sender = udp(senderIP, senderPort);
            fopen(obj.sender);            

        end
        
        %% Destructor
        function delete(obj)
            %DELETE Destructor for the BeRTAOSCAPI class.
            %   This method is automatically called when the object is destroyed.
            %   It closes OSC connections and releases resources.

            % Close the OSC receiver server
            %if ~isempty(obj.oscServer) && isvalid(obj.oscServer)
                fprintf('Closing OSC receiver server...\n');
                obj.oscServer.stopListening();
                obj.oscServer.close();
                obj.oscServer = []; % Clear the property
            %end

            % Close the UDP connection (sender)
            % Check if the sender object exists, is valid, and its status is 'open'.
            %if ~isempty(obj.sender) && isvalid(obj.sender) && strcmp(obj.sender.Status, 'open')
                fprintf('Closing OSC sender connection...\n');
                fclose(obj.sender);
                delete(obj.sender); % Delete the UDP object from memory
                obj.sender = []; % Clear the property
            %end

            %javarmpath('javaosctomatlab.jar');
            %clear java;
        end

        %% Close Osc Server
        function obj = closeOscServer(obj)
            %CLOSEOSCSERVER Stops listening and closes the OSC server connection.
            %   obj = obj.closeOscServer()
            %
            % Output:
            %   obj - The updated BeRTAOSCAPI object (oscServer and oscListener properties will be cleared).
            import com.illposed.osc.*; % Ensure this is imported for clean up

            %if ~isempty(obj.oscServer) && isvalid(obj.oscServer)
                obj.oscServer.stopListening();
                obj.oscServer.close();
                % You might want to clear the properties explicitly or just let them be
                % when the object is cleared from workspace.
                obj.oscServer = [];
                obj.oscListener = [];
            %end

            % This part tries to remove the jar from classpath. Be careful as
            % javarmpath only works if no classes from the jar are loaded.
            % If you have multiple instances, this might fail or cause issues.
            % It's often better to just add the path once at startup and let it be.
            % javarmpath('javaosctomatlab.jar');
            % clear java; % This clears all Java objects, which might be too broad.
            % If you just want to clear the specific jar, ensure no classes from it are loaded.
        end
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%% TO RECEIVE DATA
        %%%%%%%%%%%%%%%%%%%%%%%%%%%

        %% AddListenerAddress
        function obj = addListenerAddress(obj, address)
            %ADDLISTENERADDRESS Adds a single OSC address to the listener.
            %   obj = obj.addListenerAddress(address)
            %
            % Input:
            %   address - The OSC address string to listen for (e.g., '/my/data').
            %
            % Output:
            %   obj     - The updated BeRTAOSCAPI object.
            import com.illposed.osc.*;
            import java.lang.String
            osc_method = String(address);
            obj.oscServer.addListener(osc_method, obj.oscListener);
        end

        %% AddMultipleListenerAddress (Internal Helper Method)
        % Made private as it's an internal helper for setting up initial listeners.
        % If you need to add more addresses dynamically later, you'd call addListenerAddress.
        function obj = setListOfAddressToListenTo(obj)
            %SETLISTOFADDRESSTOLISTENTO Sets a predefined list of OSC addresses to listen to.
            %   This is typically called by the constructor to initialize common listeners.
            %
            % Output:
            %   obj - The updated BeRTAOSCAPI object.

            % Note: Using obj.addListenerAddress to add each address
            obj = obj.addListenerAddress('/control/actionResult');
            obj = obj.addListenerAddress('/control/connect');
            obj = obj.addListenerAddress('/control/disconnect');
            obj = obj.addListenerAddress('/control/ping');
            obj = obj.addListenerAddress('/control/version');
            obj = obj.addListenerAddress('/control/sampleRate');
            obj = obj.addListenerAddress('/resources/loadHRTF');            
            % Add other addresses as needed
        end

        

        %% Waiting One Osc Message Without Parameters
        function waitingOneOscMessageNoParameters(obj)
            %WAITINGONEOSCMESSAGENOPARAMETERS Waits for a single OSC message without parameters.
            %   obj.waitingOneOscMessageNoParameters()
            obj.oscServer.startListening();
            while true
                % No specific check for arguments here, just keeps listening
                % Consider adding a timeout or a specific message check.
                arguments = obj.oscListener.getMessageArguments(); %#ok<NASGU>
                % The original code had commented out lines to stop listening if arguments
                % were found, which seems more sensible. I've re-added a basic check.
                if ~isempty(arguments)
                     obj.oscServer.stopListening();
                     break;
                end
                pause(0.01); % Small pause to prevent busy-waiting
            end
        end

        %% Waiting One Osc Message with DoubleVector as parameter
        function message = waitingOneOscMessageDoubleVector(obj)
            %WAITINGONEOSCMESSAGEDOUBLEVECTOR Waits for an OSC message with a double vector.
            %   message = obj.waitingOneOscMessageDoubleVector()
            %
            % Output:
            %   message - A double vector containing the message arguments.
            obj.oscServer.startListening();
            while true
                arguments = obj.oscListener.getMessageArgumentsAsDouble();
                if ~isempty(arguments)
                    message = double(arguments);
                    obj.oscServer.stopListening();
                    break;
                end
                pause(0.01); % Small pause to prevent busy-waiting
            end
        end

        %% WaitingOneOscMessageStringVector
        function message = waitingOneOscMessageStringVector(obj)
            %WAITINGONEOSCMESSAGESTRINGVECTOR Waits for an OSC message with a string vector.
            %   message = obj.waitingOneOscMessageStringVector()
            %
            % Output:
            %   message - A string array containing the message arguments.
            obj.oscServer.startListening();
            while true
                arguments = obj.oscListener.getMessageArgumentsAsString();
                if ~isempty(arguments)
                    message = string(arguments);
                    obj.oscServer.stopListening();
                    break;
                end
                pause(0.01); % Small pause to prevent busy-waiting
            end
        end

        %% WaitingOneOscMessageStructVector
        function message = waitingOneOscMessageStructVector(obj)
            %WAITINGONEOSCMESSAGESTRUCTVECTOR Waits for an OSC message with a struct vector.
            %   message = obj.waitingOneOscMessageStructVector()
            %
            % Output:
            %   message - A struct array containing the message arguments.
            obj.oscServer.startListening();
            while true
                arguments = obj.oscListener.getMessageArguments(); % This typically returns a Java array
                if ~isempty(arguments)
                    message = struct(arguments);
                    obj.oscServer.stopListening();
                    break;
                end
                pause(0.01); % Small pause to prevent busy-waiting
            end
        end

        %% Wait for any of the messages configured in oscListener.
        function [address, parameters] = waitMessage(obj)
            %WAITMESSAGE Waits for any OSC message configured in the listener.
            %   [address, parameters] = obj.waitMessage()
            %
            % Outputs:
            %   address    - The OSC address of the received message (string).
            %   parameters - The arguments of the received message (string array).
            import com.illposed.osc.*;
            import java.lang.String;
            obj.oscServer.startListening();
            waiting = true;
            counter = 0;
            address = ""; % Initialize to avoid error if no message received
            parameters = ""; % Initialize to avoid error if no message received
            while waiting
                message = obj.oscListener.getMessage();
                if ~isempty(message)
                    addressJava = message.getAddress();
                    address = string(addressJava);
                    arguments = obj.oscListener.getMessageArgumentsAsString();
                    parameters = string(arguments);
                    obj.oscServer.stopListening();
                    waiting = false;
                end
                pause(0.05); % Reduce pause for faster response, still allowing CPU rest
                counter = counter + 1;
                if (counter == 1200) % 1200 * 0.05s = 60s (1 minute timeout)
                    warning('BeRTAOSCAPI:WaitMessageTimeout', 'No message received within timeout period (1 minute).');
                    break;
                end
            end
        end

        %% WaitControlActionResult
        function [address, parameters] = waitControlActionResult(obj)
            %WAITCONTROLACTIONRESULT Waits for a '/control/actionResult' message.
            %   [address, parameters] = obj.waitControlActionResult()
            %
            % Outputs:
            %   address    - The extracted action address (string).
            %   parameters - The parameters of the action result (string array, excluding the action address).
            %
            % Throws:
            %   'MyComponent:WaitControlActionResult' if no action result is received.
            [address, parameters] = obj.waitMessage();
            if (address == "/control/actionResult")
                if length(parameters) >= 1
                    address = parameters(1); % The actual action address is the first parameter
                    parameters = parameters(2:end); % Remaining parameters are the result of the action
                else
                    ME = MException('BeRTAOSCAPI:WaitControlActionResult', 'Error: /control/actionResult received but no parameters found.');
                    throw(ME);
                end
            else
                ME = MException('BeRTAOSCAPI:WaitControlActionResult', 'Error: Expected /control/actionResult but received %s', address);
                throw(ME);
            end
        end

        %% CheckActionResultBackMessage
        % function [success, message] = waitAndCheckControlActionResult(obj, command, toCheck)
        %     %CHECKACTIONRESULTBACKMESSAGE Checks the return message of an action result generically.
        %     %   [success, message] = obj.checkActionResultBackMessage(command, toCheck)
        %     %
        %     % Inputs:
        %     %   command - The expected command address (e.g., "/playAndRecord").
        %     %   toCheck - The expected first parameter after the command (e.g., filename or ID).
        %     %
        %     % Outputs:
        %     %   success - True if the action was successful, false otherwise.
        %     %   message - The response message from the action.
        % 
        %     [address, parameters] = obj.waitControlActionResult();
        % 
        %     success = false; % Default to false
        %     message = ""; % Default to empty string
        % 
        %     if length(parameters) ~= 3
        %         success = false;
        %         message = "Unexpected action result parameters for command " + command + ". Received: " + strjoin(parameters, ', ');
        %         return;
        %     end
        % 
        %     if address == command               
        %         if parameters(1) == toCheck && parameters(2) == "true"
        %             success = true;
        %             message = parameters(3);                    
        %         else
        %             success = false;                    
        %             message = parameters(3);                                     
        %         end
        %     else
        %         message = "Expected command " + command + " but received " + address + ".";
        %     end
        % end

        function [success, message] = waitAndCheckControlActionResult(obj, command, varargin)
            %WAITANDCHECKCONTROLACTIONRESULT Checks the return message of an action result.
            %   [success, message] = obj.waitAndCheckControlActionResult(command)
            %     Waits for an action result and returns its success status and message.
            %     No 'toCheck' parameter is provided, so the first parameter of the
            %     action result is NOT checked against an expected value.
            %
            %   [success, message] = obj.waitAndCheckControlActionResult(command, toCheck)
            %     Waits for an action result and returns its success status and message.
            %     The 'toCheck' parameter is provided, so the first parameter of the
            %     action result is checked against this expected value.
            %
            % Inputs:
            %   obj     - The class instance.
            %   command - The expected command address (e.g., "/playAndRecord").
            %   varargin:
            %     toCheck - (Optional) The expected first parameter after the command
            %               (e.g., filename or ID). Only used if provided.
            %
            % Outputs:
            %   success - True if the action was successful and (optionally) the 'toCheck'
            %             parameter matched, false otherwise.
            %   message - The response message from the action.
        
            % Get the number of additional arguments passed (excluding obj and command)
            numOptionalArgs = length(varargin);
        
            % Determine if 'toCheck' was provided
            checkToCheckParameter = (numOptionalArgs >= 1);
            if checkToCheckParameter
                toCheck = varargin{1};
            end
        
            % Wait for the action result message
            [address, parameters] = obj.waitControlActionResult();
        
            success = false; % Default to false
            message = "";    % Default to empty string
        
            % Basic validation: Ensure 'parameters' has at least 3 elements             
            if length(parameters) ~= 3 
                success = false;
                message = "Action result has too few parameters. Expected at least 2, got " + length(parameters) + ".";
                return;
            end
        
            % First, check if the received address matches the expected command
            if address ~= command
                message = "Expected command '" + command + "' but received '" + address + "'.";
                success = false; % Explicitly set to false
                return; % Exit early if the command doesn't match
            end
        
            % Now, process based on whether 'toCheck' was provided
            if checkToCheckParameter
                % Case 1: 'toCheck' was provided (2 arguments: command, toCheck)
                % Ensure parameters has at least 2 for the 'toCheck' and the status.                        
                if parameters(2) == "true" && parameters(1) == toCheck                    
                    success = true;                        
                    message = parameters(3);
                        
                elseif parameters(2) == "true" && parameters(1) ~= toCheck 
                     success = false;
                     message = "Action result for command '" + command + "' received parameter '" + parameters(1) + "' but expected '" + toCheck + "'.";
                     message = strcat(message, " - ", parameters(3));
                else 
                    success = false; 
                    message = parameters(3); % Error message from the action result                                                       
                end
            else
                % Case 2: 'toCheck' was NOT provided (1 argument: command)
                % Just check the overall success/failure based on parameters(2)
                % assuming parameters(1) is the main result identifier.
                if parameters(2) == "true"
                    success = true;                           
                else 
                    success = false;
                end
                    message = parameters(3);                                    
            end
        end

        %%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%% TO SEND DATA
        %%%%%%%%%%%%%%%%%%%%%%%%%%%       
        %% Send control/connect command
        function sendControlConnect(obj, ip, port)
            %SENDCONTROLCONNECT Sends a '/control/connect' OSC command.
            %   obj.sendControlConnect(ip, port)
            %
            % Inputs:
            %   ip   - IP address (string).
            %   port - Port number (integer).
            oscsend(obj.sender, '/control/connect', 'si', ip, port);
        end
        
        function [success, message] = sendControlConnectAndWaitResponse(obj, ip, port)
            %SENDCONTROLCONNECTANDWAITRESPONSE Sends '/control/connect' and waits for a response.
            %   [success, message] = obj.sendControlConnectAndWaitResponse(ip, port)
            %
            % Inputs:
            %   ip   - IP address (string).
            %   port - Port number (integer).
            %
            % Outputs:
            %   success - True if connection successful, false otherwise.
            %   message - Connection status message.
            obj.sendControlConnect(ip, port);
            [address, parameters] = obj.waitMessage();
            if (address == "/control/connect")
                success = true;
                if length(parameters) >= 2
                    message = strcat("Connection established with ", parameters(1), ":", parameters(2));
                else
                    message = "Connection established (no detailed parameters received).";
                end
            else
                success = false;
                message = parameters; % Return whatever parameters were received on failure
            end
        end

        %% Send control/disconnect command
        function sendControlDisconnect(obj)
            %SENDCONTROLDISCONNECT Sends a '/control/disconnect' OSC command.
            %   obj.sendControlDisconnect()
            disp("Sending /control/disconnect...");
            oscsend(obj.sender, '/control/disconnect', 'N', "");
        end

        %% Send control/disconnect command and wait message back
        function [success, message] = sendControlDisconnectAndWaitResponse(obj)
            %SENDCONTROLDISCONNECTANDWAITRESPONSE Sends '/control/disconnect' and waits for a response.
            %   [success, message] = obj.sendControlDisconnectAndWaitResponse()
            %
            % Outputs:
            %   success - True if disconnection successful, false otherwise.
            %   message - Disconnection status message.
            obj.sendControlDisconnect();
            [address, parameters] = obj.waitMessage();
            if (address == "/control/disconnect")
                success = true;
                message = "Disconnected...";
            else
                success = false;
                message = parameters;
            end
        end

        %% Send control/ping command
        function sendControlPing(obj)
            %SENDCONTROLIPING Sends a '/control/ping' OSC command.
            %   obj.sendControlPing()
            oscsend(obj.sender, '/control/ping', 'N', "");
        end

        %% Send control/version command
        function sendControlVersion(obj)
            %SENDCONTROLVERSION Sends a '/control/version' OSC command.
            %   obj.sendControlVersion()
            oscsend(obj.sender, '/control/version', 'N', "");
        end

        %% Send control/sampleRate command
        function sendControlSampleRate(obj)
            %SENDCONTROLSAMPLERATE Sends a '/control/sampleRate' OSC command.
            %   obj.sendControlSampleRate()
            oscsend(obj.sender, '/control/sampleRate', 'N', "");
        end

        %% Send control/sampleRate command and wait message back
        function [success, fs] = sendControlSampleRateAndWaitResponse(obj)
            %SENDCONTROLSAMPLERATEANDWAITRESPONSE Sends '/control/sampleRate' and waits for a response.
            %   [success, fs] = obj.sendControlSampleRateAndWaitResponse()
            %
            % Outputs:
            %   success - True if sample rate received, false otherwise.
            %   fs      - The sample rate (string) or 0 on failure.
            obj.sendControlSampleRate();
            [address, parameters] = obj.waitMessage();
            if (address == "/control/sampleRate")
                success = true;
                if ~isempty(parameters)
                    fs = parameters(1);
                else
                    fs = "0"; % Or NaN, depending on expected type
                    warning('BeRTAOSCAPI:NoSampleRateReceived', 'Sample rate command successful but no parameter returned.');
                end
            else
                success = false;
                fs = "0";
            end
        end

        %% Send a Play command
        function sendPlay(obj)
            %SENDPLAY Sends a '/play' OSC command.
            %   obj.sendPlay()
            oscsend(obj.sender, '/play', 'N', "");
        end

        %% Send a Pause command
        function sendPause(obj)
            %SENDPAUSE Sends a '/pause' OSC command.
            %   obj.sendPause()
            oscsend(obj.sender, '/pause', 'N', "");
        end

        %% Send a Stop command
        function sendStop(obj)
            %SENDSTOP Sends a '/stop' OSC command.
            %   obj.sendStop()
            oscsend(obj.sender, '/stop', 'N', "");
        end

        %% Send a RemoveAllSource command
        function sendRemoveAllSources(obj)
            %SENDREMOVEALLSOURCES Sends a '/removeAllSources' OSC command.
            %   obj.sendRemoveAllSources()
            disp("Sending /removeAllSources...");
            oscsend(obj.sender, '/removeAllSources', 'N', "");
        end

        %% Send a PlayAndRecord command
        function sendPlayAndRecord(obj, filename, type, seconds)
            %SENDPLAYANDRECORD Sends a '/playAndRecord' OSC command.
            %   obj.sendPlayAndRecord(filename, type, seconds)
            %
            % Inputs:
            %   filename - The file path to save the recording.
            %   type     - The file type (e.g., 'wav').
            %   seconds  - Duration of recording in seconds.
            disp("Sending /playAndRecord...");
            oscsend(obj.sender, '/playAndRecord', 'ssf', filename, type, seconds);
        end

        function [success, message] = sendPlayAndRecordAndWaitResult(obj, filename, type, seconds)
            %SENDPLAYANDRECORDANDWAITRESULT Sends '/playAndRecord' and waits for action result.
            %   [success, message] = obj.sendPlayAndRecordAndWaitResult(filename, type, seconds)
            %
            % Inputs:
            %   filename - The file path to save the recording.
            %   type     - The file type (e.g., 'wav').
            %   seconds  - Duration of recording in seconds.
            %
            % Outputs:
            %   success - True if action was successful, false otherwise.
            %   message - Response message from the action.
            obj.sendPlayAndRecord(filename, type, seconds);
            [success, message] = obj.waitAndCheckControlActionResult("/playAndRecord", filename);
        end

        %% Send a Record command
        function sendRecord(obj, filename, type, seconds)
            %SENDRECORD Sends a '/record' OSC command.
            %   obj.sendRecord(filename, type, seconds)
            %
            % Inputs:
            %   filename - The file path to save the recording.
            %   type     - The file type (e.g., 'wav').
            %   seconds  - Duration of recording in seconds.
            disp("Sending /record...");
            oscsend(obj.sender, '/record', 'ssf', filename, type, seconds);
        end

        function [success, message] = sendRecordAndWaitResult(obj, filename, type, seconds)
            %SENDRECORDANDWAITRESULT Sends '/record' and waits for action result.
            %   [success, message] = obj.sendRecordAndWaitResult(filename, type, seconds)
            %
            % Inputs:
            %   filename - The file path to save the recording.
            %   type     - The file type (e.g., 'wav').
            %   seconds  - Duration of recording in seconds.
            %
            % Outputs:
            %   success - True if action was successful, false otherwise.
            %   message - Response message from the action.
            obj.sendRecord(filename, type, seconds);
            [success, message] = obj.waitAndCheckControlActionResult("/record");
        end


        %% Send a Enable Model command
        function sendEnableModel(obj, modelID, enable)
             disp("Sending /listener/enableModel...");
            oscsend(obj.sender, '/enableModel', 'sB', convertStringsToChars(modelID), enable);
        end
        
        function [success, message] = sendEnableModelAndWaitResult(obj, modelID, enable)            
            obj.sendEnableModel(modelID, enable);
            [success, message] = obj.waitAndCheckControlActionResult("/enableModel", modelID);
        end

        %% Send a LoadHRTF command
        function sendLoadHRTF(obj, HRTFID, filename, samplingStep)
            %SENDLOADHRTF Sends a '/resources/loadHRTF' OSC command.
            %   obj.sendLoadHRTF(HRTFID, filename, samplingStep)
            %
            % Inputs:
            %   HRTFID       - Unique ID for the HRTF.
            %   filename     - Path to the HRTF file.
            %   samplingStep - Sampling step for the HRTF.
            disp("Sending /resources/loadHRTF...");
            oscsend(obj.sender, '/resources/loadHRTF', 'ssf', convertStringsToChars(HRTFID), convertStringsToChars(filename), samplingStep);
        end

        function [success, message] = sendLoadHRTFAndWaitResult(obj, HRTFID, filename, samplingStep)
            %SENDLOADHRTFANDWAITRESULT Sends '/resources/loadHRTF' and waits for action result.
            %   [success, message] = obj.sendLoadHRTFAndWaitResult(HRTFID, filename, samplingStep)
            %
            % Inputs:
            %   HRTFID       - Unique ID for the HRTF.
            %   filename     - Path to the HRTF file.
            %   samplingStep - Sampling step for the HRTF.
            %
            % Outputs:
            %   success - True if action was successful, false otherwise.
            %   message - Response message from the action.
            obj.sendLoadHRTF(HRTFID, filename, samplingStep);
            [success, message] = obj.waitAndCheckControlActionResult("/resources/loadHRTF", HRTFID);
        end
        %% Send Remove HRTF
        function sendRemoveHRTF(obj, HRTFID)           
            disp("Sending /resources/removeHRTF ...");
            oscsend(obj.sender, '/resources/removeHRTF ', 's', convertStringsToChars(HRTFID));
        end

        %% Send a LoadDirectivityTF (Note: Original method name 'LoadHRTF' might be a typo for 'LoadDirectivityTF')
        function sendLoadDirectivityTF(obj, directivityID, filename, samplingStep)
            %SENDLOADDIRECTIVITYTF Sends a '/loadHRTF' OSC command (might be a typo for '/loadDirectivityTF').
            %   obj.sendLoadDirectivityTF(directivityID, filename, samplingStep)
            %
            % Inputs:
            %   directivityID - Unique ID for the directivity.
            %   filename      - Path to the directivity file.
            %   samplingStep  - Sampling step for the directivity.
            oscsend(obj.sender, '/loadHRTF', 'ssf', directivityID, filename, samplingStep);
        end

        %% Send a LoadSource command
        function sendLoadSource(obj, sourceID, filename, sourceModel)
            %SENDLOADSOURCE Sends a '/source/loadSource' OSC command.
            %   obj.sendLoadSource(sourceID, filename, sourceModel)
            %
            % Inputs:
            %   sourceID    - Unique ID for the source.
            %   filename    - Path to the source audio file.
            %   sourceModel - Model for the source (e.g., 'point').
            disp("Sending /source/loadSource...");
            oscsend(obj.sender, '/source/loadSource', 'sss', convertStringsToChars(sourceID), convertStringsToChars(filename), convertStringsToChars(sourceModel));
        end

        function [success, message] = sendLoadSourceAndWaitResult(obj, sourceID, filename, sourceModel)
            %SENDLOADSOURCEANDWAITRESULT Sends '/source/loadSource' and waits for action result.
            %   [success, message] = obj.sendLoadSourceAndWaitResult(sourceID, filename, sourceModel)
            %
            % Inputs:
            %   sourceID    - Unique ID for the source.
            %   filename    - Path to the source audio file.
            %   sourceModel - Model for the source (e.g., 'point').
            %
            % Outputs:
            %   success - True if action was successful, false otherwise.
            %   message - Response message from the action.
            obj.sendLoadSource(sourceID, filename, sourceModel);
            [success, message] = obj.waitAndCheckControlActionResult("/source/loadSource", sourceID);
        end

        %% Send a LoadSOSFilter command
        function sendLoadSOSFilters(obj, SOSFilters_id, filename)
            %SENDLOADSOSFILTERS Sends a '/resources/loadHRTF' OSC command.
            %   obj.sendLoadSOSFilters(HRTFID, filename, samplingStep)
            %
            % Inputs:
            %   SOSFilters_id       - Unique ID for the SOSFilter.
            %   filename     - Path to the SOSFilter file.            
            disp("Sending /resources/loadSOSFilters...");
            oscsend(obj.sender, '/resources/loadSOSFilters', 'ss', convertStringsToChars(SOSFilters_id), convertStringsToChars(filename));
        end

        function [success, message] = sendLoadSOSFiltersAndWaitResult(obj, SOSFilters_id, filename)
            %SENDLOADSOSFILTERSANDWAITRESULT Sends '/resources/loadSOSFilters' and waits for action result.
            %   [success, message] = obj.sendLoadSOSFiltersAndWaitResult(HRTFID, filename, samplingStep)
            %
            % Inputs:
            %   SOSFilters_id       - Unique ID for the SOSFilter.
            %   filename     - Path to the SOSFilter file.                
            %
            % Outputs:
            %   success - True if action was successful, false otherwise.
            %   message - Response message from the action.
            obj.sendLoadSOSFilters(SOSFilters_id, filename);
            [success, message] = obj.waitAndCheckControlActionResult("/resources/loadSOSFilters", SOSFilters_id);
        end
     

        %% Send a RemoveSource command
        function sendRemoveSource(obj, sourceID)
            %SENDREMOVESOURCE Sends a '/source/removeSource' OSC command.
            %   obj.sendRemoveSource(sourceID)
            %
            % Input:
            %   sourceID - Unique ID of the source to remove.
            oscsend(obj.sender, '/source/removeSource', 's', sourceID);
        end

        %% Send a Source Play command
        function sendSourcePlay(obj, sourceID)
            %SENDSOURCEPLAY Sends a '/source/play' OSC command.
            %   obj.sendSourcePlay(sourceID)
            %
            % Input:
            %   sourceID - Unique ID of the source to play.
            oscsend(obj.sender, '/source/play', 's', sourceID);
        end

        %% Send a Source Pause command
        function sendSourcePause(obj, sourceID)
            %SENDSOURCEPAUSE Sends a '/source/pause' OSC command.
            %   obj.sendSourcePause(sourceID)
            %
            % Input:
            %   sourceID - Unique ID of the source to pause.
            oscsend(obj.sender, '/source/pause', 's', sourceID);
        end

        %% Send a Source Stop command
        function sendSourceStop(obj, sourceID)
            %SENDSOURCESTOP Sends a '/source/stop' OSC command.
            %   obj.sendSourceStop(sourceID)
            %
            % Input:
            %   sourceID - Unique ID of the source to stop.
            oscsend(obj.sender, '/source/stop', 's', sourceID);
        end

        %% Send a Source Mute command
        function sendSourceMute(obj, sourceID)
            %SENDSOURCEMUTE Sends a '/source/mute' OSC command.
            %   obj.sendSourceMute(sourceID)
            %
            % Input:
            %   sourceID - Unique ID of the source to mute.
            oscsend(obj.sender, '/source/mute', 's', sourceID);
        end

        %% Send a Source Unmute command
        function sendSourceUnmute(obj, sourceID)
            %SENDSOURCEUNMUTE Sends a '/source/unmute' OSC command.
            %   obj.sendSourceUnmute(sourceID)
            %
            % Input:
            %   sourceID - Unique ID of the source to unmute.
            oscsend(obj.sender, '/source/unmute', 's', sourceID);
        end

        %% Send a Source Solo command
        function sendSourceSolo(obj, sourceID)
            %SENDSOURCESOLO Sends a '/source/solo' OSC command.
            %   obj.sendSourceSolo(sourceID)
            %
            % Input:
            %   sourceID - Unique ID of the source to solo.
            oscsend(obj.sender, '/source/solo', 's', sourceID);
        end

        %% Send a Source Unsolo command
        function sendSourceUnsolo(obj, sourceID)
            %SENDSOURCEUNSOLO Sends a '/source/unsolo' OSC command.
            %   obj.sendSourceUnsolo(sourceID)
            %
            % Input:
            %   sourceID - Unique ID of the source to unsolo.
            oscsend(obj.sender, '/source/unsolo', 's', sourceID);
        end

        %% Send a Source loop command
        function sendSourceLoop(obj, sourceID, enable)
            %SENDSOURCELOOP Sends a '/source/loop' OSC command.
            %   obj.sendSourceLoop(sourceID, enable)
            %
            % Inputs:
            %   sourceID - Unique ID of the source.
            %   enable   - Boolean (true/false) to enable/disable looping.
            disp("Sending /source/loop...");
            oscsend(obj.sender, '/source/loop', 'sB', sourceID, enable);
        end

        function [success, message] = sendSourceLoopAndWaitResult(obj, sourceID, enable)
            %SENDSOURCELOOPANDWAITRESULT Sends '/source/loop' and waits for action result.
            %   [success, message] = obj.sendSourceLoopAndWaitResult(sourceID, enable)
            %
            % Inputs:
            %   sourceID - Unique ID of the source.
            %   enable   - Boolean (true/false) to enable/disable looping.
            %
            % Outputs:
            %   success - True if action was successful, false otherwise.
            %   message - Response message from the action.
            obj.sendSourceLoop(sourceID, enable);
            [success, message] = obj.waitAndCheckControlActionResult("/source/loop", sourceID);
        end

        %% Send a Source Location command
        function sendSourceLocation(obj, sourceID, x, y, z)
            %SENDSOURCELOCATION Sends a '/source/location' OSC command.
            %   obj.sendSourceLocation(sourceID, x, y, z)
            %
            % Inputs:
            %   sourceID - Unique ID of the source.
            %   x, y, z  - Cartesian coordinates of the source.
            oscsend(obj.sender, '/source/location', 'sfff', sourceID, x, y, z);
        end

        %% Send a Source Orientation command
        function sendSourceOrientation(obj, sourceID, yaw, pitch, roll)
            %SENDSOURCEORIENTATION Sends a '/source/orientation' OSC command.
            %   obj.sendSourceOrientation(sourceID, yaw, pitch, roll)
            %
            % Inputs:
            %   sourceID - Unique ID of the source.
            %   yaw      - Yaw angle (rotation around Y-axis).
            %   pitch    - Pitch angle (rotation around X-axis).
            %   roll     - Roll angle (rotation around Z-axis).
            oscsend(obj.sender, '/source/orientation', 'sfff', sourceID, yaw, pitch, roll);
        end

        %% Send a Source Gain command
        function sendSourceGain(obj, sourceID, gain)
            %SENDSOURCEGAIN Sends a '/source/gain' OSC command.
            %   obj.sendSourceGain(sourceID, gain)
            %
            % Inputs:
            %   sourceID - Unique ID of the source.
            %   gain     - Gain value.
            oscsend(obj.sender, '/source/gain', 'sf', sourceID, gain);
        end

        %% Send a Source Enable Directivity command
        function sendSourceEnableDirectivity(obj, sourceID, enable)
            %SENDSOURCEENABLEDIRECTIVITY Sends a '/source/enableDirectivity' OSC command.
            %   obj.sendSourceEnableDirectivity(sourceID, enable)
            %
            % Inputs:
            %   sourceID - Unique ID of the source.
            %   enable   - Boolean (true/false) to enable/disable directivity.
            oscsend(obj.sender, '/source/enableDirectivity', 'sB', sourceID, enable);
        end

        %% Send a Source Set DirectivityTF
        function sendSourceSetDirectivityTF(obj, sourceID, directivityTFID)
            %SENDSOURCESETDIRECTIVITYTF Sends a '/source/setDirectivityTF' OSC command.
            %   obj.sendSourceSetDirectivityTF(sourceID, directivityTFID)
            %
            % Inputs:
            %   sourceID      - Unique ID of the source.
            %   directivityTFID - ID of the directivity transfer function.
            oscsend(obj.sender, '/source/setDirectivityTF', 'ss', sourceID, directivityTFID);
        end

        %% Send a Source Play and Record
        function sendSourcePlayAndRecord(obj, sourceID, filename, type, seconds)
            %SENDSOURCEPLAYANDRECORD Sends a '/source/playAndRecord' OSC command.
            %   obj.sendSourcePlayAndRecord(sourceID, filename, type, seconds)
            %
            % Inputs:
            %   sourceID - Unique ID of the source.
            %   filename - The file path to save the recording.
            %   type     - The file type (e.g., 'wav').
            %   seconds  - Duration of recording in seconds.
            oscsend(obj.sender, '/source/playAndRecord', 'sssf', sourceID, filename, type, seconds);
        end

        %% LISTENER

        %% Send a Listener Location command
        function sendListenerLocation(obj, listenerID, x, y, z)
            %SENDLISTENERLOCATION Sends a '/listener/location' OSC command.
            %   obj.sendListenerLocation(listenerID, x, y, z)
            %
            % Inputs:
            %   listenerID - Unique ID of the listener.
            %   x, y, z    - Cartesian coordinates of the listener.
            oscsend(obj.sender, '/listener/location', 'sfff', listenerID, x, y, z);
        end

        %% Send a Listener Orientation command
        function sendListenerOrientation(obj, listenerID, yaw, pitch, roll)
            %SENDLISTENERORIENTATION Sends a '/listener/orientation' OSC command.
            %   obj.sendListenerOrientation(listenerID, yaw, pitch, roll)
            %
            % Inputs:
            %   listenerID - Unique ID of the listener.
            %   yaw        - Yaw angle (rotation around Y-axis).
            %   pitch      - Pitch angle (rotation around X-axis).
            %   roll       - Roll angle (rotation around Z-axis).
            oscsend(obj.sender, '/listener/orientation', 'sfff', listenerID, yaw, pitch, roll);
        end

        %% Send a Listener Set HRTF command
        function sendListenerSetHRTF(obj, listenerID, HRTFID)
            %SENDLISTENERSETHRTF Sends a '/listener/setHRTF' OSC command.
            %   obj.sendListenerSetHRTF(listenerID, HRTFID)
            %
            % Inputs:
            %   listenerID - Unique ID of the listener.
            %   HRTFID     - ID of the HRTF to set.
            disp("Sending /listener/setHRTF...");
            oscsend(obj.sender, '/listener/setHRTF', 'ss', convertStringsToChars(listenerID), convertStringsToChars(HRTFID));
        end

        function [success, message] = sendListenerSetHRTFAndWaitResult(obj, listenerID, HRTFID)
            %SENDLISTENERSETHRTFANDWAITRESULT Sends '/listener/setHRTF' and waits for action result.
            %   [success, message] = obj.sendListenerSetHRTFAndWaitResult(listenerID, HRTFID)
            %
            % Inputs:
            %   listenerID - Unique ID of the listener.
            %   HRTFID     - ID of the HRTF to set.
            %
            % Outputs:
            %   success - True if action was successful, false otherwise.
            %   message - Response message from the action.
            obj.sendListenerSetHRTF(listenerID, HRTFID);
            [success, message] = obj.waitAndCheckControlActionResult("/listener/setHRTF", HRTFID);
        end

        %% Send a Listener Enable Spatialization command
        function sendListenerEnableSpatialization(obj, listenerID, enable)
            %SENDLISTENERENABLESPATIALIZATION Sends a '/listener/enableSpatialization' OSC command.
            %   obj.sendListenerEnableSpatialization(listenerID, enable)
            %
            % Inputs:
            %   listenerID - Unique ID of the listener.
            %   enable     - Boolean (true/false) to enable/disable spatialization.
            oscsend(obj.sender, '/listener/enableSpatialization', 'sB', convertStringsToChars(listenerID), enable);
        end

        %% Send a Listener Enable Interpolation command
        function sendListenerEnableInterpolation(obj, listenerID, enable)
            %SENDLISTENERENABLEINTERPOLATION Sends a '/listener/enableInterpolation' OSC command.
            %   obj.sendListenerEnableInterpolation(listenerID, enable)
            %
            % Inputs:
            %   listenerID - Unique ID of the listener.
            %   enable     - Boolean (true/false) to enable/disable interpolation.
            oscsend(obj.sender, '/listener/enableInterpolation', 'sB', convertStringsToChars(listenerID), enable);
        end

        %% Send a Listener Enable NearFieldEffect command
        function sendListenerEnableNearFieldEffect(obj, listenerID, enable)
            %SENDLISTENERENABLENEARFIELDEFFECT Sends a '/listener/enableNearFieldEffect' OSC command.
            %   obj.sendListenerEnableNearFieldEffect(listenerID, enable)
            %
            % Inputs:
            %   listenerID - Unique ID of the listener.
            %   enable     - Boolean (true/false) to enable/disable near field effect.
            disp("Sending /listener/enableNearFieldEffect...");
            oscsend(obj.sender, '/listener/enableNearFieldEffect', 'sB', convertStringsToChars(listenerID), enable);
        end

        function [success, message] = sendListenerEnableNearFieldEffectAndWaitResult(obj, listenerID, enable)
            %SENDLISTENERENABLENEARFIELDEFFECTANDWAITRESULT Sends '/listener/enableNearFieldEffect' and waits for action result.
            %   [success, message] = obj.sendListenerEnableNearFieldEffectAndWaitResult(listenerID, enable)
            %
            % Inputs:
            %   listenerID - Unique ID of the listener.
            %   enable     - Boolean (true/false) to enable/disable near field effect.
            %
            % Outputs:
            %   success - True if action was successful, false otherwise.
            %   message - Response message from the action.
            obj.sendListenerEnableNearFieldEffect(listenerID, enable);
            [success, message] = obj.waitAndCheckControlActionResult("/listener/enableNearFieldEffect", listenerID);
        end

        %% Send a Listener Enable BilateralAmbisonics command
        function sendListenerEnableBilateralAmbisonics(obj, listenerID, enable)
            %SENDLISTENERENABLEBILATERALAMBISONICS Sends a '/listener/enableBilateralAmbisonics' OSC command.
            %   obj.sendListenerEnableBilateralAmbisonics(listenerID, enable)
            %
            % Inputs:
            %   listenerID - Unique ID of the listener.
            %   enable     - Boolean (true/false) to enable/disable bilateral ambisonics.
            oscsend(obj.sender, '/listener/enableBilateralAmbisonics', 'sB', convertStringsToChars(listenerID), enable);
        end

        %% Send a Listener Set Ambisonics Order command
        function sendListenerSetAmbisonicsOrder(obj, listenerID, order)
            %SENDLISTENERSETAMBISONICSORDER Sends a '/listener/setAmbisonicsOrder' OSC command.
            %   obj.sendListenerSetAmbisonicsOrder(listenerID, order)
            %
            % Inputs:
            %   listenerID - Unique ID of the listener.
            %   order      - Ambisonics order (integer).
            disp("Sending /listener/setAmbisonicsOrder...");
            oscsend(obj.sender, '/listener/setAmbisonicsOrder', 'si', convertStringsToChars(listenerID), order);
        end

        function [success, message] = sendListenerSetAmbisonicsOrderAndWaitResult(obj, listenerID, order)
            %SENDLISTENERSETAMBISONICSORDERANDWAITRESULT Sends '/listener/setAmbisonicsOrder' and waits for action result.
            %   [success, message] = obj.sendListenerSetAmbisonicsOrderAndWaitResult(listenerID, order)
            %
            % Inputs:
            %   listenerID - Unique ID of the listener.
            %   order      - Ambisonics order (integer).
            %
            % Outputs:
            %   success - True if action was successful, false otherwise.
            %   message - Response message from the action.
            obj.sendListenerSetAmbisonicsOrder(listenerID, order);
            [success, message] = obj.waitAndCheckControlActionResult("/listener/setAmbisonicsOrder", listenerID);
        end

        %% Send a Listener Set Ambisonics Normalization command
        function sendListenerSetAmbisonicsNormalization(obj, listenerID, normalization)
            %SENDLISTENERSETAMBISONICSNORMALIZATION Sends a '/listener/setAmbisonicsNormalization' OSC command.
            %   obj.sendListenerSetAmbisonicsNormalization(listenerID, normalization)
            %
            % Inputs:
            %   listenerID    - Unique ID of the listener.
            %   normalization - Normalization type (string, e.g., 'SN3D', 'N3D').
            oscsend(obj.sender, '/listener/setAmbisonicsNormalization', 'ss', convertStringsToChars(listenerID), normalization);
        end


        %% Send a Listener Enable NearFieldEffect command
        function sendEnvironmentEnablePropagationDelay(obj, environmentModelID, enable)           
            disp("Sending /environment/enablePropagationDelay ...");
            oscsend(obj.sender, '/environment/enablePropagationDelay', 'sB', convertStringsToChars(environmentModelID), enable);
        end

        function [success, message] = sendEnvironmentEnablePropagationDelayAndWaitResult(obj, environmentModelID, enable)           
            obj.sendEnvironmentEnablePropagationDelay(environmentModelID, enable);
            [success, message] = obj.waitAndCheckControlActionResult("/environment/enablePropagationDelay ", listenerID);
        end
    end
end