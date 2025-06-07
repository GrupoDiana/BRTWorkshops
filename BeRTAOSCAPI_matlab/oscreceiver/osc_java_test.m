% https://0110.be/posts/OSC_in_Matlab_on_Windows%2C_Linux_and_Mac_OS_X_using_Java
% https://github.com/hoijui/JavaOSC
cd('G:/Repos/3daudio/of_v0.11.2_vs2017_release/ImageSourceMethodTestApp/ISM_OSC_Tester/MatlabOscTester/')
version -java
javaaddpath('javaosctomatlab.jar');
import com.illposed.osc.*;
import java.lang.String
receiver =  OSCPortIn(12301);
osc_method = String('/ready');
osc_listener = MatlabOSCListener();
receiver.addListener(osc_method,osc_listener);

%osc_method = String('/Dani');
%osc_listener = MatlabOSCListener();
%receiver.addListener(osc_method,osc_listener);

receiver.startListening();
while true    
    %struct = osc_listener.getMessageArgumentsAsDouble();
    struct = osc_listener.getMessageArguments();
     if ~isempty(struct) == 1
         struct
         break;
     end
end

receiver.stopListening();
receiver=0;


