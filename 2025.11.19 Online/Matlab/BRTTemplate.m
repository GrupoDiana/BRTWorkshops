try 
    clear all;
    clc;    
    addpath("..\..\BeRTAOSCAPI_matlab\");    
    
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

    

catch ME    
    if (exist('myOSCConnection', 'var'))
        myOSCConnection.sendControlDisconnect();        
        myOSCConnection.closeOscServer();
    end
    rethrow(ME)
end


