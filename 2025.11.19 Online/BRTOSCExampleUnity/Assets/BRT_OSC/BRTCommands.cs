using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;


namespace BRTOSC
{
    public class BRTCommands : MonoBehaviour
    {
        public struct SoundLevelData
        {
            public string id;
            public float leftdBSLP;
            public float rigthdBSPL;
            public DateTime time;
            
            public SoundLevelData(float _leftdBSLP, float _rigthdBSPL, DateTime _time)
            {
                leftdBSLP = _leftdBSLP;
                rigthdBSPL = _rigthdBSPL;
                time = _time;
                id = "";
            }

            public bool IsNull()
            {
                return id == "";
            }
        }

        public event Action<string> OnCommandReceived;

        private Dictionary<string, Queue<SoundLevelData>> soundLevelQueues;
        private Dictionary<string, List<OscMessage>> receivedCommands;
        private Dictionary<string, List<OscMessage>> actionResultCommands;


        private OSC oscLibrary;
        //private OscMessage lastMessageReceived;
        
        OSCMessageGenerator applicationMessageGenerator;
        private string myIP;

        private bool initialized = false;

        private void Awake()
        {            
            receivedCommands = new Dictionary<string, List<OscMessage>>();
            soundLevelQueues = new Dictionary<string, Queue<SoundLevelData>>();
            actionResultCommands = new Dictionary<string, List<OscMessage>>();
            Initialize();
        }

        void OnApplicationQuit()
        {
            ResetConnection();
        }
        
        public void ResetConnection()
        {
            if (oscLibrary != null)
            {
                GeneralStop();
                RemoveAllSources();
                ControlDisconnect();
                oscLibrary.Close();
                oscLibrary = null;
            }
        }

        private void Initialize()
        {
            if (initialized) { return; }
            initialized = true;
            oscLibrary = this.GetComponent<OSC>();
            SetAudioRenderApplication(TAudioRenderApplication.berta);
            //lastMessageReceived = new OscMessage();
            myIP = GetLocalIPAddress();
        }

        public void SetAudioRenderApplication(TAudioRenderApplication _renderApp)
        {
            Initialize();
            if (_renderApp == TAudioRenderApplication.bita)
            {
                applicationMessageGenerator = new OSCMessageGeneratorBiTA();                
            }
            else if (_renderApp == TAudioRenderApplication.berta)
            {
                applicationMessageGenerator = new OSCMessageGeneratorBeRTA();                
            }

            oscLibrary.SetAllMessageHandler(OnReceive);
        }
        

        // RECEIVER

        void OnReceive(OscMessage message)
        {            
            if (message.address == "/control/getSoundLevel")
            {
                OnReceiveSoundLevel(message);
            } else if (message.address == "/control/soundLevelAlert")
            {
                OnReceiveSoundLevelAlert(message);
            }
            else if (message.address == "/control/actionResult")
            {
                OnReceiveActionResult(message);
            }
            else {
                //lastMessageReceived = message;
                OnReceiveCommand(message);
            }

            OnCommandReceived?.Invoke(message.address);
            //string _log = "OSC message received: " + message.address;
            //if (message.values.Count > 0)
            //{
            //    _log = _log + "-" + message.values[0];
            //}            
            //Debug.Log(_log);
        }


        //RECEIVERS--------------------------------------------------------------------------------------------
        private void OnReceiveCommand(OscMessage message)
        {
            string command = message.address;

            if (!receivedCommands.ContainsKey(command))
            {
                receivedCommands[command] = new List<OscMessage>();
            }
            receivedCommands[command].Add(message);
        }

        private void OnReceiveActionResult(OscMessage message)
        {
            //string command = message.address;
            string action = message.values[0].ToString();

            if (!actionResultCommands.ContainsKey(action))
            {
                actionResultCommands[action] = new List<OscMessage>();
            }
            actionResultCommands[action].Add(message);
        }

        private void OnReceiveSoundLevel(OscMessage message)
        {
            string command = message.address;
            string id = message.values[0].ToString();            

            if (!soundLevelQueues.ContainsKey(id))
            {
                soundLevelQueues[id] = new Queue<SoundLevelData>();
            }
            float param1 = float.Parse(message.values[1].ToString());
            float param2 = float.Parse(message.values[2].ToString());

            soundLevelQueues[id].Enqueue(new SoundLevelData(param1, param2, DateTime.UtcNow));                 
            //Debug.Log("Sound Level received: " + param1 + " - " + param2);            
        }

        private void OnReceiveSoundLevelAlert(OscMessage message)
        {
            string command = message.address;
            string id = "soundLevelAlert";

            if (!soundLevelQueues.ContainsKey(id))
            {
                soundLevelQueues[id] = new Queue<SoundLevelData>();
            }
            float param1 = float.Parse(message.values[0].ToString());
            float param2 = float.Parse(message.values[1].ToString());

            soundLevelQueues[id].Enqueue(new SoundLevelData(param1, param2, DateTime.UtcNow));
            //Debug.Log("Sound Level Alert received: " + param1 + " - " + param2);
        }



        // SOUND LEVEL GETTERS --
        public bool IsReceivedMessageSoundLevels(string id)
        {
            return soundLevelQueues.ContainsKey(id) && soundLevelQueues[id].Count > 0;
        }
        public bool IsReceivedGetSoundLevel(string listenerID)
        {
            return IsReceivedMessageSoundLevels(listenerID);
        }
        public bool IsReceivedSoundLevelAlert()
        {
            return IsReceivedMessageSoundLevels("soundLevelAlert");
        }
        public SoundLevelData GetLastSoundLevel(string id)
        {
            if (soundLevelQueues.ContainsKey(id) && soundLevelQueues[id].Count > 0)
            {
                SoundLevelData lastElement = soundLevelQueues[id].Dequeue();
                soundLevelQueues[id].Clear();
                lastElement.id = id;
                return lastElement;
            }
            return new SoundLevelData(); 
        }

        public Queue<SoundLevelData>? GetSoundLevels(string id)
        {
            if (soundLevelQueues.ContainsKey(id))
            {
                return new Queue<SoundLevelData>(soundLevelQueues[id]);
            }
            return null; 
        }

        ////////////////////////////
        /// Commands ACTION RESULT
        ////////////////////////////
        public bool IsReceivedActionResult(string _action)
        {
            if (actionResultCommands.ContainsKey(_action))
            {
                return actionResultCommands[_action].Count > 0;
            }
            return false;
        }

        public OscMessage GetReceivedActionResult(string _action)
        {
            if (IsReceivedActionResult(_action))
            {
                OscMessage message = actionResultCommands[_action].Find(x => x.values[0].ToString() == _action);
                if (message != null)
                {
                    actionResultCommands[_action].Remove(message);
                    return message;
                }
            }
            return new OscMessage();
        }
                       
        /// Commands GETTERS
        public bool IsReceivedCommand(string command)
        {
            if (receivedCommands.ContainsKey(command))
            {
                return receivedCommands[command].Count > 0;
            }
            return false;           
        }

        private OscMessage GetReceivedCommand(string command)
        {
            if (IsReceivedCommand(command))
            {
                OscMessage message = receivedCommands[command][0];
                receivedCommands[command].Clear();
                return message;
            }
            return new OscMessage();
        }
               
       
        public bool IsReceivedControlConnect()
        {
            return IsReceivedCommand("/control/connect");
        }
        public OscMessage GetReceivedControlConnect()
        {
            return GetReceivedCommand("/control/connect");
        }

        public bool IsReceivedActionResultLoadHRTF()
        {
            return IsReceivedActionResult("/resources/loadHRTF");                        
        }       

        public OscMessage GetReceivedCommandLoadHRTF()
        {
            return GetReceivedActionResult("/resources/loadHRTF");
        }

        public bool IsReceivedActionResultLoadBRIR()
        {
            return IsReceivedActionResult("/resources/loadBRIR");
        }
        public OscMessage GetReceivedCommandLoadBRIR()
        {
            return GetReceivedActionResult("/resources/loadBRIR");
        }

        public bool IsReceivedActionResultLoadSource()
        {
            return IsReceivedActionResult("/source/loadSource");
        }
        public OscMessage GetReceivedCommandLoadSource()
        {
            return GetReceivedActionResult("/source/loadSource");
        }

        public bool IsReceivedActionResultRemoveSource()
        {
            return IsReceivedActionResult("/source/removeSource");
        }
        public OscMessage GetReceivedCommandRemoveSource()
        {
            return GetReceivedActionResult("/source/removeSource");
        }

        //SENDERS--------------------------------------------------------------------------------------------

        //Control
        public void ControlConnect()
        {
            int inPort = oscLibrary.inPort;
            myIP = "127.0.0.1";
            oscLibrary.Send(applicationMessageGenerator.GetControlConnect(myIP, inPort));

        }
        public void ControlDisconnect()
        {
            oscLibrary.Send(applicationMessageGenerator.GetControlDisconnect());
        }
        public void ControlPing()
        {
            oscLibrary.Send(applicationMessageGenerator.GetControlPing());
        }
        public void ControlVersion()
        {
            oscLibrary.Send(applicationMessageGenerator.GetControlVersion());
        }
        public void ControlSampleRate()
        {
            oscLibrary.Send(applicationMessageGenerator.GetControlSampleRate());
        }
        public void ControlFrameSize()
        {
            oscLibrary.Send(applicationMessageGenerator.GetControlFrameSize());
        }

        ///// PlayBack Control

        public void GeneralStart()
        {
            oscLibrary.Send(applicationMessageGenerator.GetGeneralStartMessage());
        }
        public void GeneralPause()
        {
            oscLibrary.Send(applicationMessageGenerator.GetGeneralPauseMessage());
        }
        public void GeneralStop()
        {
            oscLibrary.Send(applicationMessageGenerator.GetGeneralStopMessage());
        }
        public void RemoveAllSources()
        {
            oscLibrary.Send(applicationMessageGenerator.GetRemoveAllSourcesMessage());
        }

        //Source
        public void LoadSoundSource(int soundSourceID, string wavfile)
        {
            oscLibrary.Send(applicationMessageGenerator.GetLoadSoundSourceMessage(soundSourceID, wavfile));
        }

        public void LoadSoundSource(string soundSourceID, string wavfile, string model)
        {
            oscLibrary.Send(applicationMessageGenerator.GetLoadSoundSourceMessage(soundSourceID, wavfile, model));
        }

        public void LoadSoundSource(string soundSourceID, string wavfile, string model, string _modelToConnectTo)
        {
            oscLibrary.Send(applicationMessageGenerator.GetLoadSoundSourceMessage(soundSourceID, wavfile, model, _modelToConnectTo));
        }

        public void PlaySoundSource(int soundSourceID)
        {
            oscLibrary.Send(applicationMessageGenerator.GetPlaySoundSourceMessage(soundSourceID));
        }
        public void PlaySoundSource(string soundSourceID)
        {
            oscLibrary.Send(applicationMessageGenerator.GetPlaySoundSourceMessage(soundSourceID));
        }

        public void PlayAndRecordSoundSource(int soundSourceID, string filename)
        {
            Debug.Log(filename);
            oscLibrary.Send(applicationMessageGenerator.GetPlayAndRecordSoundSourceMessage(soundSourceID, filename));
        }
        public void StopSoundSource(int soundSourceID)
        {
            oscLibrary.Send(applicationMessageGenerator.GetStopSoundSourceMessage(soundSourceID));
        }
        public void StopSoundSource(string soundSourceID)
        {
            oscLibrary.Send(applicationMessageGenerator.GetStopSoundSourceMessage(soundSourceID));
        }
        public void RemoveSoundSource(string soundSourceID)
        {
            oscLibrary.Send(applicationMessageGenerator.GetRemoveSoundSource(soundSourceID));
        }
        public void LoopSoundSource(int soundSourceID, bool _enable)
        {
            oscLibrary.Send(applicationMessageGenerator.GetLoopSoundSourceMessage(soundSourceID, _enable));
        }
        public void LoopSoundSource(string soundSourceID, bool _enable)
        {
            oscLibrary.Send(applicationMessageGenerator.GetLoopSoundSourceMessage(soundSourceID, _enable));
        }

        public void MuteSoundSource(string soundSourceID)
        {
            oscLibrary.Send(applicationMessageGenerator.GetMuteSoundSource(soundSourceID));
        }
        public void UnmuteSoundSource(string soundSourceID)
        {
            oscLibrary.Send(applicationMessageGenerator.GetUnmuteSoundSource(soundSourceID));
        }
        public void SetSoundSourceReverbType(int soundSourceID, string _reverbType)
        {
            oscLibrary.Send(applicationMessageGenerator.GetSetSoundSourceReverbTypeMessage(soundSourceID, _reverbType));
        }
        public void SetSoundSourceLocation(int soundSourceID, Vector3 _location)
        {
            oscLibrary.Send(applicationMessageGenerator.GetSetSoundSourceLocationMessage(soundSourceID, _location));
        }
        public void SetSoundSourceLocation(string soundSourceID, Vector3 _location)
        {
            oscLibrary.Send(applicationMessageGenerator.GetSetSoundSourceLocationMessage(soundSourceID, _location));
        }

        public void SoundSourceOrientation(string soundSourceID, Vector3 _orientation)
        {
            oscLibrary.Send(applicationMessageGenerator.GetSoundSourceOrientation(soundSourceID, _orientation));
        }
        public void SetSoundSourceGain(int soundSourceID, float _gain)
        {
            oscLibrary.Send(applicationMessageGenerator.GetSetSoundSourceGainMessage(soundSourceID, _gain));
        }
        public void SetSoundSourceGain(string soundSourceID, float _gain)
        {
            oscLibrary.Send(applicationMessageGenerator.GetSetSoundSourceGainMessage(soundSourceID, _gain));
        }

        public void SetActivateSoundSourceAnechoicDistanceSimulation(int soundSourceID, bool _enabled)
        {
            oscLibrary.Send(applicationMessageGenerator.GetSetActivateSoundSourceAnechoicDistanceSimulationMessage(soundSourceID, _enabled));
        }

        public void SetActivateSoundSourceEnvironmentDistanceSimulation(int soundSourceID, bool _enabled)
        {
            oscLibrary.Send(applicationMessageGenerator.GetSetActivateSoundSourceEnvironmentDistanceSimulationMessage(soundSourceID, _enabled));
        }

        //Resources
        public void LoadHRTF(string _hrtfID, string _hrtfFilePath, float _samplingStep)
        {
            oscLibrary.Send(applicationMessageGenerator.GetLoadHRTFMessage(_hrtfID, _hrtfFilePath, _samplingStep));
        }
        public void LoadBRIR(string _brirID, string _brirFilePath, float spatialResolution)
        {
            oscLibrary.Send(applicationMessageGenerator.GetLoadBRIRMessage(_brirID, _brirFilePath));
        }
        public void LoadDirectivityTF(string _ID, string _filePath, float _samplingStep)
        {
            oscLibrary.Send(applicationMessageGenerator.GetLoadDirectivity(_ID, _filePath, _samplingStep));
        }

        public void LoadSOSFilters(string _ID, string _filePath)
        {
            oscLibrary.Send(applicationMessageGenerator.GetLoadSOSFilters(_ID, _filePath));
        }



        ////LISTENER
        public void SetListenerHRTF(string _listenerID, string _hrtfID)
        {
            oscLibrary.Send(applicationMessageGenerator.GetListenerSetHRTFMessage(_listenerID, _hrtfID));
        }
        public void SetListenerBRIR(string _listenerID, string _brirID)
        {
            oscLibrary.Send(applicationMessageGenerator.GetListenerSetBRIRMessage(_listenerID, _brirID));
        }

        public void SendListenerOrientation(string _listenerID, Vector3 _rotation)
        {
            oscLibrary.Send(applicationMessageGenerator.GetSendListenerOrientationMessage(_listenerID, _rotation));
        }

        public void SendListenerPosition(string _listenerID, Vector3 _location)
        {
            oscLibrary.Send(applicationMessageGenerator.GetSendListenerPositionMessage(_listenerID, _location));
        }
        public void SendListenerEnableSpatialization(string _listenerID, bool _enabled)
        {
            oscLibrary.Send(applicationMessageGenerator.GetListenerEnableSpatialization(_listenerID, _enabled));

        }
        public void SendListenerEnableInterpolation(string _listenerID, bool _enabled)
        {
            oscLibrary.Send(applicationMessageGenerator.GetListenerSetEnableInterpolation(_listenerID, _enabled));
        }
        public void SetListenerSOSFilters(string _listenerID, string _NFCFilterID)
        {
            oscLibrary.Send(applicationMessageGenerator.GetListenerSetSOSFilterMessage(_listenerID, _NFCFilterID));
        }

        public void SendListenerEnableNearFieldEffect(string _listenerID, bool _enabled)
        {
            oscLibrary.Send(applicationMessageGenerator.GetListenerSetEnableNearFieldEffect(_listenerID, _enabled));
        }
        public void SendListenerEnableBilateralAmbisonics(string _listenerID, bool _enabled)
        {
            oscLibrary.Send(applicationMessageGenerator.GetListenerEnableBilateralAmbisonics(_listenerID, _enabled));
        }

        public void SendListenerAmbisonicOrder(string _listenerID, int _order)
        {
            oscLibrary.Send(applicationMessageGenerator.GetListenerSetAmbisonicOrder(_listenerID, _order));
        }

        public void SendListenerAmbisonicNormalization(string _listenerID, string _normalization)
        {
            oscLibrary.Send(applicationMessageGenerator.GetListenerSetAmbisonicNormalization(_listenerID, _normalization));
        }

        //// ENVIRONMENT
        public void SetEnvironmentReverbOrder(string _reverbOrder)
        {
            oscLibrary.Send(applicationMessageGenerator.GetSetEnvironmentReverbOrderMessage(_reverbOrder));
        }

        public void SetEnvironmentReverbOverallGain(float _gain)
        {
            oscLibrary.Send(applicationMessageGenerator.GetEnvironmentReverbOverallGainMessage(_gain));
        }

        // Binaural Filters
        public void SetBinauralFilterEnableModel(string modelID, bool _enabled)
        {
            oscLibrary.Send(applicationMessageGenerator.GetSetBinauralFilterEnableModel(modelID, _enabled));
        }

        public void SetBinauralFilterSOSFilters(string _listenerID, string _NFCFilterID)
        {
            oscLibrary.Send(applicationMessageGenerator.GetBinauralFilterSetSOSFilterMessage(_listenerID, _NFCFilterID));
        }

        // Calibration

        public void PlayCalibration(float _dBFS)
        {
            oscLibrary.Send(applicationMessageGenerator.GetPlayCalibrationMessage(_dBFS));
        }

        public void SetCalibration(float _dBFS, float _dBSPL)
        {
            oscLibrary.Send(applicationMessageGenerator.GetSetCalibrationMessage(_dBFS, _dBSPL));
        }
        public void PlayCalibrationTest(float _dBSPL)
        {
            oscLibrary.Send(applicationMessageGenerator.GetPlayCalibrationTestMessage(_dBSPL));
        }
        public void StopCalibrationTest()
        {
            oscLibrary.Send(applicationMessageGenerator.GetStopCalibrationTestMessage());
        }

        // Safety limiter
        
        public void SetSoundLevelLimit(float _limitdBSPL)
        {
            oscLibrary.Send(applicationMessageGenerator.GetSetSoundLevelLimitMessage(_limitdBSPL));
        }
        public void GetSoundLevel(string _listenerID)
        {
            oscLibrary.Send(applicationMessageGenerator.GetGetSoundLevelMessage(_listenerID));
        }

        // Auxiliar Methods

        public string GetLocalIPAddress()
        {
            var host = System.Net.Dns.GetHostEntry(System.Net.Dns.GetHostName());
            foreach (var ip in host.AddressList)
            {
                if (ip.AddressFamily == System.Net.Sockets.AddressFamily.InterNetwork)
                {
                    //hintText.text = ip.ToString();
                    return ip.ToString();
                }
            }
            throw new System.Exception("No network adapters with an IPv4 address in the system!");
        }
    }

    public interface OSCMessageGenerator
    {
        // Control
        public OscMessage GetControlConnect(string _ip, int _port);
        public OscMessage GetControlDisconnect();
        public OscMessage GetControlPing();
        public OscMessage GetControlVersion();
        public OscMessage GetControlSampleRate();
        public OscMessage GetControlFrameSize();

        // General Playback
        public OscMessage GetGeneralStartMessage();
        public OscMessage GetGeneralStopMessage();
        public OscMessage GetGeneralPauseMessage();
        public OscMessage GetRemoveAllSourcesMessage();

        //Sources Control
        public OscMessage GetLoadSoundSourceMessage(int soundSourceID, string wavfile);
        public OscMessage GetLoadSoundSourceMessage(string soundSourceID, string wavfile, string model);        
        public OscMessage GetLoadSoundSourceMessage(string soundSourceID, string wavfile, string model, string _modelToConnectTo);
        public OscMessage GetPlaySoundSourceMessage(int soundSourceID);
        public OscMessage GetPlaySoundSourceMessage(string soundSourceID);
        public OscMessage GetPlayAndRecordSoundSourceMessage(int soundSourceID, string filename);
        public OscMessage GetStopSoundSourceMessage(int soundSourceID);
        public OscMessage GetStopSoundSourceMessage(string soundSourceID);
        public OscMessage GetPauseSoundSource(string soundSourceID);
        public OscMessage GetRemoveSoundSource(string soundSourceID);
        public OscMessage GetLoopSoundSourceMessage(int soundSourceID, bool _enable);        
        public OscMessage GetLoopSoundSourceMessage(string soundSourceID, bool _enable);
        public OscMessage GetMuteSoundSource(string soundSourceID);
        public OscMessage GetUnmuteSoundSource(string soundSourceID);
        public OscMessage GetSetSoundSourceReverbTypeMessage(int soundSourceID, string _reverbType);
        public OscMessage GetSetSoundSourceLocationMessage(int soundSourceID, Vector3 _location);        
        public OscMessage GetSetSoundSourceLocationMessage(string soundSourceID, Vector3 _location);
        public OscMessage GetSoundSourceOrientation(string soundSourceID, Vector3 _orientation);
        public OscMessage GetSetSoundSourceGainMessage(int soundSourceID, float _gain);        
        public OscMessage GetSetSoundSourceGainMessage(string soundSourceID, float _gain);
        public OscMessage GetSetActivateSoundSourceAnechoicDistanceSimulationMessage(int soundSourceID, bool _enabled);
        public OscMessage GetSetActivateSoundSourceEnvironmentDistanceSimulationMessage(int soundSourceID, bool _enabled);

        //Resources
        public OscMessage GetLoadHRTFMessage(string _hrtfID, string _hrtfFilePath, float _samplingStep);
        public OscMessage GetLoadDirectivity(string _ID, string _filePath, float _samplingStep);
        public OscMessage GetLoadSOSFilters(string _ID, string _filePath);
        public OscMessage GetLoadBRIRMessage(string _brirID, string _brirFilePath);
        public OscMessage GetLoadBRIRMessage(string _brirID, string _brirFilePath, float spatialResolution);

        //Listener
        public OscMessage GetListenerSetHRTFMessage(string _listenerID, string _hrtfID);
        public OscMessage GetListenerSetBRIRMessage(string _listenerID, string _brirID);
        public OscMessage GetSendListenerPositionMessage(string _listenerID, Vector3 _location);
        public OscMessage GetSendListenerOrientationMessage(string _listenerID, Vector3 _rotation);
        public OscMessage GetListenerEnableSpatialization(string _listenerID, bool _enabled);
        public OscMessage GetListenerSetEnableInterpolation(string _listenerID, bool _enabled);
        public OscMessage GetListenerSetSOSFilterMessage(string _listenerID, string _NFCFilterfID);
        public OscMessage GetListenerSetEnableNearFieldEffect(string _listenerID, bool _enabled);
        public OscMessage GetListenerEnableBilateralAmbisonics(string _listenerID, bool _enabled);
        public OscMessage GetListenerSetAmbisonicOrder(string _listenerID, int _order);
        public OscMessage GetListenerSetAmbisonicNormalization(string _listenerID, string _normalization);


        //Environment
        public OscMessage GetSetEnvironmentReverbOrderMessage(string _reverbOrder);
        public OscMessage GetEnvironmentReverbOverallGainMessage(float _gain);

        // Binaural Filter
        public OscMessage GetSetBinauralFilterEnableModel(string modelID, bool _enabled);
        public OscMessage GetBinauralFilterSetSOSFilterMessage(string _listenerID, string _NFCFilterID);

        // Calibration
        public OscMessage GetPlayCalibrationMessage(float _dBFS);
        public OscMessage GetSetCalibrationMessage(float _dBFS, float _dBSPL);
        public OscMessage GetPlayCalibrationTestMessage(float _dBSPL);
        public OscMessage GetStopCalibrationTestMessage();
        // Safety limiter
        public OscMessage GetSetSoundLevelLimitMessage(float _limitdBSPL);
        public OscMessage GetGetSoundLevelMessage(string _listenerID);
    }

    public class OSCMessageGeneratorBiTA : OSCMessageGenerator
    {
        //CONTROL
        public OscMessage GetControlConnect(string _ip, int _port)
        {
            OscMessage message = new OscMessage();
            message.address = "/notImplemented";
            return message;
        }
        public OscMessage GetControlDisconnect()
        {
            OscMessage message = new OscMessage();
            message.address = "/notImplemented";
            return message;
        }
        public OscMessage GetControlPing()
        {
            OscMessage message = new OscMessage();
            message.address = "/notImplemented";
            return message;
        }
        public OscMessage GetControlVersion()
        {
            OscMessage message = new OscMessage();
            message.address = "/notImplemented";
            return message;
        }
        public OscMessage GetControlSampleRate()
        {
            OscMessage message = new OscMessage();
            message.address = "/notImplemented";
            return message;
        }
        public OscMessage GetControlFrameSize()
        {
            OscMessage message = new OscMessage();
            message.address = "/notImplemented";
            return message;
        }

        //GENERAL PLAYBACK
        public OscMessage GetGeneralStartMessage()
        {
            OscMessage message = new OscMessage();
            message.address = "/notImplemented";
            return message;
        }
        public OscMessage GetGeneralStopMessage()
        {
            OscMessage message = new OscMessage();
            message.address = "/3DTI-OSC/v2/stop";
            return message;

        }
        public OscMessage GetGeneralPauseMessage()
        {
            OscMessage message = new OscMessage();
            message.address = "/notImplemented";
            return message;
        }

        public OscMessage GetRemoveAllSourcesMessage()
        {
            OscMessage message = new OscMessage();
            message.address = "/notImplemented";
            return message;
        }

        //SOURCES CONTROL
        public OscMessage GetLoadSoundSourceMessage(int soundSourceID, string wavfile)
        {
            OscMessage message = new OscMessage();
            message.address = "/3DTI-OSC/v2/loadSource";
            //string fullPath = "G:/Repos/3daudio/dynamic-localisation/resources/" + wavfile;
            message.values.Add(wavfile);
            message.values.Add(soundSourceID);
            return message;
        }
        public OscMessage GetLoadSoundSourceMessage(string soundSourceID, string wavfile, string model)
        {
            OscMessage message = new OscMessage();
            message.address = "/notImplemented";
            return message;
        }

        public OscMessage GetLoadSoundSourceMessage(string soundSourceID, string wavfile, string model, string _modelToConnectTo)
        {
            OscMessage message = new OscMessage();
            message.address = "/notImplemented";
            return message;
        }

        public OscMessage GetPlaySoundSourceMessage(int soundSourceID)
        {
            OscMessage message = new OscMessage();
            message.address = "/3DTI-OSC/v2/source" + soundSourceID.ToString() + "/play";
            return message;
        }

        public OscMessage GetPlaySoundSourceMessage(string soundSourceID)
        {
            OscMessage message = new OscMessage();
            message.address = "/notImplemented";
            return message;
        }

        public OscMessage GetPlayAndRecordSoundSourceMessage(int soundSourceID, string filename)
        {
            return GetPlaySoundSourceMessage(soundSourceID);
        }

        public OscMessage GetPauseSoundSource(string soundSourceID)
        {
            OscMessage message = new OscMessage();
            message.address = "/notImplemented";
            return message;
        }
        public OscMessage GetStopSoundSourceMessage(int soundSourceID)
        {
            OscMessage message = new OscMessage();
            message.address = "/3DTI-OSC/v2/source" + soundSourceID.ToString() + "/stop";
            return message;
        }
        public OscMessage GetStopSoundSourceMessage(string soundSourceID)
        {
            OscMessage message = new OscMessage();
            message.address = "/notImplemented";
            return message;
        }

        public OscMessage GetRemoveSoundSource(string soundSourceID)
        {
            OscMessage message = new OscMessage();
            message.address = "/notImplemented";
            message.values.Add(soundSourceID);
            return message;
        }

        public OscMessage GetLoopSoundSourceMessage(int soundSourceID, bool _enable)
        {
            OscMessage message = new OscMessage();
            message.address = "/3DTI-OSC/v2/source" + soundSourceID.ToString() + "/loop";
            if (!_enable) { message.values.Add(0); }
            else { message.values.Add(1); }
            return message;
        }

        public OscMessage GetLoopSoundSourceMessage(string soundSourceID, bool _enable)
        {
            OscMessage message = new OscMessage();
            message.address = "/notImplemented";           
            return message;
        }

        public OscMessage GetMuteSoundSource(string soundSourceID)
        {
            OscMessage message = new OscMessage();
            message.address = "/notImplemented";
            message.values.Add(soundSourceID);
            return message;
        }
        public OscMessage GetUnmuteSoundSource(string soundSourceID)
        {
            OscMessage message = new OscMessage();
            message.address = "/notImplemented";
            message.values.Add(soundSourceID);
            return message;
        }

        public OscMessage GetSetSoundSourceReverbTypeMessage(int soundSourceID, string _reverbType)
        {
            OscMessage message = new OscMessage();
            message.address = "/3DTI-OSC/v2/source" + soundSourceID.ToString() + "/environment/type";
            message.values.Add(_reverbType);
            return message;
        }


        public OscMessage GetSetSoundSourceLocationMessage(int soundSourceID, Vector3 _location)
        {
            Vector3 _newLocation = CalculateLocationToBitaConvention(_location);
            OscMessage message = new OscMessage();

            message.address = "/3DTI-OSC/v2/source" + soundSourceID.ToString() + "/location";
            message.values.Add(_newLocation.x);
            message.values.Add(_newLocation.y);
            message.values.Add(_newLocation.z);
            return message;
        }

        public OscMessage GetSetSoundSourceLocationMessage(string soundSourceID, Vector3 _location)
        {
            OscMessage message = new OscMessage();
            message.address = "/notImplemented";
            return message;
        }

        public OscMessage GetSoundSourceOrientation(string soundSourceID, Vector3 _orientation)
        {
            OscMessage message = new OscMessage();
            message.address = "/notImplemented";
            return message;
        }

        public OscMessage GetSetSoundSourceGainMessage(int soundSourceID, float _gain)
        {
            OscMessage message = new OscMessage();
            message.address = "/3DTI-OSC/v2/source" + soundSourceID.ToString() + "/gain";
            message.values.Add(_gain);
            return message;
        }
        public OscMessage GetSetSoundSourceGainMessage(string soundSourceID, float _gain)
        {
            OscMessage message = new OscMessage();
            message.address = "/notImplemented";
            return message;
        }

        public OscMessage GetSetActivateSoundSourceAnechoicDistanceSimulationMessage(int soundSourceID, bool _enabled)
        {
            OscMessage message = new OscMessage();
            message.address = "/3DTI-OSC/v2/source" + soundSourceID.ToString() + "/anechoic/distance";
            if (_enabled) { message.values.Add(1); }
            else { message.values.Add(0); }
            return message;
        }

        public OscMessage GetSetActivateSoundSourceEnvironmentDistanceSimulationMessage(int soundSourceID, bool _enabled)
        {
            OscMessage message = new OscMessage();
            message.address = "/3DTI-OSC/v2/source" + soundSourceID.ToString() + "/environment/distance";
            if (_enabled) { message.values.Add(1); }
            else { message.values.Add(0); }
            return message;
        }

        //RESOURCES

        public OscMessage GetLoadHRTFMessage(string _hrtfID, string _hrtfFilePath, float _samplingStep)
        {
            OscMessage message = new OscMessage();
            message.address = "/3DTI-OSC/v2/listener/loadHRTF";
            message.values.Add(_hrtfFilePath);
            return message;
        }

        public OscMessage GetLoadDirectivity(string _ID, string _filePath, float _samplingStep)
        {
            OscMessage message = new OscMessage();
            message.address = "/notImplemented";
            message.values.Add(_ID);
            message.values.Add(_filePath);
            message.values.Add(_samplingStep);
            return message;
        }
        public OscMessage GetLoadSOSFilters(string _ID, string _filePath)
        {
            OscMessage message = new OscMessage();
            message.address = "/notImplemented";
            message.values.Add(_ID);
            message.values.Add(_filePath);
            return message;
        }

        public OscMessage GetLoadBRIRMessage(string _brirID, string _brirFilePath)
        {
            OscMessage message = new OscMessage();
            message.address = "/3DTI-OSC/v2/environment/convolution/loadBRIR";
            message.values.Add(_brirFilePath);
            return message;
        }

        public OscMessage GetLoadBRIRMessage(string _brirID, string _brirFilePath, float spatialResolution)
        {
            OscMessage message = new OscMessage();
            message.address = "/3DTI-OSC/v2/environment/convolution/loadBRIR";
            message.values.Add(_brirFilePath);
            return message;
        }

        ////LISTENER

        public OscMessage GetListenerSetHRTFMessage(string _listenerID, string _hrtfID)
        {
            OscMessage message = new OscMessage();
            message.address = "/notImplemented";
            return message;
        }

        public OscMessage GetListenerSetBRIRMessage(string _listenerID, string _brirID)
        {
            OscMessage message = new OscMessage();
            message.address = "/notImplemented";
            return message;
        }
        public OscMessage GetSendListenerOrientationMessage(string _listenerID, Vector3 _rotation)
        {
            OscMessage message = new OscMessage();
            message.address = "/3DTI-OSC/receiver/pry";
            message.values.Add(-_rotation.x);         //pitch         
            message.values.Add(_rotation.z);         //rolll         
            message.values.Add(_rotation.y);         //yaw
            return message;
        }

        public OscMessage GetSendListenerPositionMessage(string _listenerID, Vector3 _location)
        {
            Vector3 _bitaLocation = CalculateLocationToBitaConvention(_location);

            OscMessage message;

            message = new OscMessage();
            message.address = "/3DTI-OSC/receiver/pos";
            message.values.Add(_bitaLocation.x);
            message.values.Add(_bitaLocation.y);
            message.values.Add(_bitaLocation.z);

            return message;
        }

        public OscMessage GetListenerEnableSpatialization(string _listenerID, bool _enabled)
        {
            OscMessage message = new OscMessage();
            message.address = "/listener/notImplemented";
            message.values.Add(_listenerID);
            if (_enabled) { message.values.Add(1); }
            else { message.values.Add(0); }
            return message;
        }

        public OscMessage GetListenerSetEnableInterpolation(string _listenerID, bool _enabled)
        {
            OscMessage message = new OscMessage();
            message.address = "/listener/notImplemented";
            message.values.Add(_listenerID);
            if (_enabled) { message.values.Add(1); }
            else { message.values.Add(0); }
            return message;
        }
        public OscMessage GetListenerSetSOSFilterMessage(string _listenerID, string _NFCFilterfID)
        {
            OscMessage message = new OscMessage();
            message.address = "/listener/notImplemented";
            message.values.Add(_listenerID);
            message.values.Add(_NFCFilterfID);
            return message;
        }
        public OscMessage GetListenerSetEnableNearFieldEffect(string _listenerID, bool _enabled)
        {
            OscMessage message = new OscMessage();
            message.address = "/listener/notImplemented";
            message.values.Add(_listenerID);
            if (_enabled) { message.values.Add(1); }
            else { message.values.Add(0); }
            return message;
        }

        public OscMessage GetListenerEnableBilateralAmbisonics(string _listenerID, bool _enabled)
        {
            OscMessage message = new OscMessage();
            message.address = "/listener/notImplemented";
            message.values.Add(_listenerID);
            if (_enabled) { message.values.Add(1); }
            else { message.values.Add(0); }
            return message;
        }
        public OscMessage GetListenerSetAmbisonicOrder(string _listenerID, int _order)
        {
            OscMessage message = new OscMessage();
            message.address = "/listener/notImplemented";
            message.values.Add(_listenerID);
            message.values.Add(_order);
            return message;
        }

        public OscMessage GetListenerSetAmbisonicNormalization(string _listenerID, string _normalization)
        {
            OscMessage message = new OscMessage();
            message.address = "/listener/notImplemented";
            message.values.Add(_normalization);
            return message;
        }



        //// ENVIRONMENT

        public OscMessage GetSetEnvironmentReverbOrderMessage(string _reverbOrder)
        {
            OscMessage message = new OscMessage();
            message.address = "/3DTI-OSC/v2/environment/convolution/order";
            message.values.Add(_reverbOrder);
            return message;
        }

        public OscMessage GetEnvironmentReverbOverallGainMessage(float _gain)
        {
            OscMessage message = new OscMessage();
            message.address = "/3DTI-OSC/v2/environment/convolution/gain";
            message.values.Add(_gain);
            return message;
        }

        public OscMessage GetSetBinauralFilterEnableModel(string modelID, bool _enabled)
        {
            OscMessage message = new OscMessage();
            message.address = "/listener/notImplemented";
            message.values.Add(modelID);
            return message;
        }

        public OscMessage GetBinauralFilterSetSOSFilterMessage(string _listenerID, string _NFCFilterfID)
        {
            OscMessage message = new OscMessage();
            message.address = "/listener/notImplemented";
            message.values.Add(_listenerID);
            message.values.Add(_NFCFilterfID);
            return message;
        }

        public OscMessage GetPlayCalibrationMessage(float _dBFS)
        {
            OscMessage message = new OscMessage();
            message.address = "/notImplemented";
            return message;
        }

        public OscMessage GetSetCalibrationMessage(float _dBFS, float _dBSPL)
        {
            OscMessage message = new OscMessage();
            message.address = "/notImplemented";
            return message;
        }

        public OscMessage GetPlayCalibrationTestMessage(float _dBSPL)
        {
            OscMessage message = new OscMessage();
            message.address = "/notImplemented";
            return message;
        }

        public OscMessage GetStopCalibrationTestMessage()
        {
            OscMessage message = new OscMessage();
            message.address = "/notImplemented";
            return message;
        }

        public OscMessage GetSetSoundLevelLimitMessage(float _limitdBSPL)
        {
            OscMessage message = new OscMessage();
            message.address = "/notImplemented";
            return message;
        }

        public OscMessage GetGetSoundLevelMessage(string _listenerID)
        {
            OscMessage message = new OscMessage();
            message.address = "/notImplemented";
            return message;
        }
        //OTHERS
        private Vector3 CalculateLocationToBitaConvention(Vector3 _location)
        {
            Vector3 _bitaLocation;
            _bitaLocation.x = _location.z;
            _bitaLocation.y = -_location.x;
            _bitaLocation.z = _location.y;

            return _bitaLocation;
        }
    }


    public class OSCMessageGeneratorBeRTA : OSCMessageGenerator
    {

        // Control
        public OscMessage GetControlConnect(string _ip, int _port)
        {
            OscMessage message = new OscMessage();
            message.address = "/control/connect";
            message.values.Add(_ip);
            message.values.Add(_port);
            return message;
        }
        public OscMessage GetControlDisconnect()
        {
            OscMessage message = new OscMessage();
            message.address = "/control/disconnect";
            return message;
        }
        public OscMessage GetControlPing()
        {
            OscMessage message = new OscMessage();
            message.address = "/control/ping";
            return message;
        }
        public OscMessage GetControlVersion()
        {
            OscMessage message = new OscMessage();
            message.address = "/control/version";
            return message;
        }
        public OscMessage GetControlSampleRate()
        {
            OscMessage message = new OscMessage();
            message.address = "/control/sampleRate";
            return message;
        }
        public OscMessage GetControlFrameSize()
        {
            OscMessage message = new OscMessage();
            message.address = "/control/frameSize";
            return message;
        }

        //GENERAL PLAYBACK

        public OscMessage GetGeneralStartMessage()
        {
            OscMessage message = new OscMessage();
            message.address = "/start";
            return message;
        }
        public OscMessage GetGeneralStopMessage()
        {
            OscMessage message = new OscMessage();
            message.address = "/stop";
            return message;
        }
        public OscMessage GetGeneralPauseMessage()
        {
            OscMessage message = new OscMessage();
            message.address = "/pause";
            return message;
        }

        public OscMessage GetRemoveAllSourcesMessage()
        {
            OscMessage message = new OscMessage();
            message.address = "/removeAllSources";
            return message;
        }


        // SOURCES CONTROL
        public OscMessage GetLoadSoundSourceMessage(int soundSourceID, string wavfile)
        {
            OscMessage message = new OscMessage();
            message.address = "/source/loadSource";
            message.values.Add(soundSourceID);
            message.values.Add(wavfile);
            return message;
        }

        public OscMessage GetLoadSoundSourceMessage(string soundSourceID, string wavfile, string model)
        {
            OscMessage message = new OscMessage();
            message.address = "/source/loadSource";
            message.values.Add(soundSourceID);
            message.values.Add(wavfile);
            message.values.Add(model);
            return message;
        }

        public OscMessage GetLoadSoundSourceMessage(string soundSourceID, string wavfile, string model, string _modelToConnectTo)
        {
            OscMessage message = new OscMessage();
            message.address = "/source/loadSource";
            message.values.Add(soundSourceID);
            message.values.Add(wavfile);
            message.values.Add(model);
            message.values.Add(_modelToConnectTo);
            return message;
        }

        public OscMessage GetPlaySoundSourceMessage(int soundSourceID)
        {
            OscMessage message = new OscMessage();
            message.address = "/source/play";
            message.values.Add(soundSourceID);
            return message;
        }
        public OscMessage GetPlaySoundSourceMessage(string soundSourceID)
        {
            OscMessage message = new OscMessage();
            message.address = "/source/play";
            message.values.Add(soundSourceID);
            return message;
        }
        public OscMessage GetPlayAndRecordSoundSourceMessage(int soundSourceID, string filename)
        {
            OscMessage message = new OscMessage();
            message.address = "/source/playAndRecord";
            message.values.Add(soundSourceID);
            message.values.Add(filename);
            message.values.Add("mat");
            message.values.Add(-1);
            return message;
        }
        public OscMessage GetPauseSoundSource(string soundSourceID)
        {
            OscMessage message = new OscMessage();
            message.address = "/source/pause";
            message.values.Add(soundSourceID);
            return message;
        }
        public OscMessage GetStopSoundSourceMessage(int soundSourceID)
        {
            OscMessage message = new OscMessage();
            message.address = "/source/stop";
            message.values.Add(soundSourceID);
            return message;
        }
        public OscMessage GetStopSoundSourceMessage(string soundSourceID)
        {
            OscMessage message = new OscMessage();
            message.address = "/source/stop";
            message.values.Add(soundSourceID);
            return message;
        }
        public OscMessage GetRemoveSoundSource(string soundSourceID)
        {
            OscMessage message = new OscMessage();
            message.address = "/source/removeSource";
            message.values.Add(soundSourceID);
            return message;
        }
        public OscMessage GetLoopSoundSourceMessage(int soundSourceID, bool _enable)
        {
            OscMessage message = new OscMessage();
            message.address = "/source/loop";
            message.values.Add(soundSourceID);
            if (!_enable) { message.values.Add(0); }
            else { message.values.Add(1); }
            return message;
        }

        public OscMessage GetLoopSoundSourceMessage(string soundSourceID, bool _enable)
        {
            OscMessage message = new OscMessage();
            message.address = "/source/loop";
            message.values.Add(soundSourceID);
            if (!_enable) { message.values.Add(0); }
            else { message.values.Add(1); }
            return message;
        }
        public OscMessage GetMuteSoundSource(string soundSourceID)
        {
            OscMessage message = new OscMessage();
            message.address = "/source/mute";
            message.values.Add(soundSourceID);
            return message;
        }
        public OscMessage GetUnmuteSoundSource(string soundSourceID)
        {
            OscMessage message = new OscMessage();
            message.address = "/source/unmute";
            message.values.Add(soundSourceID);
            return message;
        }


        public OscMessage GetSetSoundSourceReverbTypeMessage(int soundSourceID, string _reverbType)
        {
            OscMessage message = new OscMessage();
            message.address = "/source/notImplemented";
            message.values.Add(soundSourceID);
            message.values.Add(_reverbType);
            return message;
        }


        public OscMessage GetSetSoundSourceLocationMessage(int soundSourceID, Vector3 _location)
        {
            Vector3 _newLocation = CalculateLocationToBeRTAConvention(_location);
            OscMessage message = new OscMessage();

            message.address = "/source/location";
            message.values.Add(soundSourceID);
            message.values.Add(_newLocation.x);
            message.values.Add(_newLocation.y);
            message.values.Add(_newLocation.z);
            return message;
        }

        public OscMessage GetSetSoundSourceLocationMessage(string soundSourceID, Vector3 _location)
        {
            Vector3 _newLocation = CalculateLocationToBeRTAConvention(_location);
            OscMessage message = new OscMessage();

            message.address = "/source/location";
            message.values.Add(soundSourceID);
            message.values.Add(_newLocation.x);
            message.values.Add(_newLocation.y);
            message.values.Add(_newLocation.z);
            return message;
        }

        public OscMessage GetSoundSourceOrientation(string soundSourceID, Vector3 _orientation)
        {
            Vector3 _newLocation = CalculateLocationToBeRTAConvention(_orientation);
            OscMessage message = new OscMessage();

            message.address = "/source/orientation";
            message.values.Add(soundSourceID);
            message.values.Add(_newLocation.x);
            message.values.Add(_newLocation.y);
            message.values.Add(_newLocation.z);
            return message;
        }

        public OscMessage GetSetSoundSourceGainMessage(int soundSourceID, float _gain)
        {
            OscMessage message = new OscMessage();
            message.address = "/source/gain";
            message.values.Add(soundSourceID);
            message.values.Add(_gain);
            return message;
        }

        public OscMessage GetSetSoundSourceGainMessage(string soundSourceID, float _gain)
        {
            OscMessage message = new OscMessage();
            message.address = "/source/gain";
            message.values.Add(soundSourceID);
            message.values.Add(_gain);
            return message;
        }

        public OscMessage GetSetActivateSoundSourceAnechoicDistanceSimulationMessage(int soundSourceID, bool _enabled)
        {
            OscMessage message = new OscMessage();
            message.address = "/source/notImplemented";
            message.values.Add(soundSourceID);
            if (_enabled) { message.values.Add(1); }
            else { message.values.Add(0); }
            return message;
        }

        public OscMessage GetSetActivateSoundSourceEnvironmentDistanceSimulationMessage(int soundSourceID, bool _enabled)
        {
            OscMessage message = new OscMessage();
            message.address = "/source/notImplemented";
            message.values.Add(soundSourceID);
            if (_enabled) { message.values.Add(1); }
            else { message.values.Add(0); }
            return message;
        }

        // RESOURCES

        public OscMessage GetLoadHRTFMessage(string _hrtfID, string _hrtfFilePath, float _samplingStep)
        {
            OscMessage message = new OscMessage();
            message.address = "/resources/loadHRTF";
            message.values.Add(_hrtfID);
            message.values.Add(_hrtfFilePath);
            message.values.Add(_samplingStep);
            return message;
        }

        public OscMessage GetLoadDirectivity(string _ID, string _filePath, float _samplingStep)
        {
            OscMessage message = new OscMessage();
            message.address = "/resources/loadDirectivityTF";
            message.values.Add(_ID);
            message.values.Add(_filePath);
            message.values.Add(_samplingStep);
            return message;
        }
        public OscMessage GetLoadSOSFilters(string _ID, string _filePath)
        {
            OscMessage message = new OscMessage();
            message.address = "/resources/loadSOSFilters";
            message.values.Add(_ID);
            message.values.Add(_filePath);
            return message;
        }
        public OscMessage GetLoadBRIRMessage(string _brirID, string _brirFilePath)
        {
            return GetLoadBRIRMessage(_brirID, _brirFilePath, 10.0f);            
        }

        public OscMessage GetLoadBRIRMessage(string _brirID, string _brirFilePath, float spatialResolution)
        {
            OscMessage message = new OscMessage();
            message.address = "/resources/loadBRIR";
            message.values.Add(_brirID);
            message.values.Add(_brirFilePath);
            message.values.Add(spatialResolution);
            return message;
        }
        ////LISTENER


        public OscMessage GetListenerSetHRTFMessage(string _listenerID, string _hrtfID)
        {
            OscMessage message = new OscMessage();
            message.address = "/listener/setHRTF";
            message.values.Add(_listenerID);
            message.values.Add(_hrtfID);
            return message;
        }
        public OscMessage GetListenerSetBRIRMessage(string _listenerID, string _brirID)
        {
            OscMessage message = new OscMessage();
            message.address = "/listener/setBRIR";
            message.values.Add(_listenerID);
            message.values.Add(_brirID);
            return message;
        }

        public OscMessage GetSendListenerOrientationMessage(string _listenerID, Vector3 _rotation)
        {
            OscMessage message = new OscMessage();
            message.address = "/listener/orientation";
            message.values.Add(_listenerID);
            message.values.Add(_rotation.y);    //yaw
            message.values.Add(-_rotation.x);   //pitch         
            message.values.Add(-_rotation.z);    //rolll                 
            return message;
        }

        public OscMessage GetSendListenerPositionMessage(string _listenerID, Vector3 _location)
        {
            Vector3 _newLocation = CalculateLocationToBeRTAConvention(_location);
            OscMessage message;
            message = new OscMessage();
            message.address = "/listener/location";
            message.values.Add(_listenerID);
            message.values.Add(_newLocation.x);
            message.values.Add(_newLocation.y);
            message.values.Add(_newLocation.z);
            return message;
        }
        public OscMessage GetListenerEnableSpatialization(string _listenerID, bool _enabled)
        {
            OscMessage message = new OscMessage();
            message.address = "/listener/enableSpatialization";
            message.values.Add(_listenerID);
            if (_enabled) { message.values.Add(1); }
            else { message.values.Add(0); }
            return message;
        }

        public OscMessage GetListenerSetEnableInterpolation(string _listenerID, bool _enabled)
        {
            OscMessage message = new OscMessage();
            message.address = "/listener/enableInterpolation";
            message.values.Add(_listenerID);
            if (_enabled) { message.values.Add(1); }
            else { message.values.Add(0); }
            return message;
        }
        public OscMessage GetListenerSetSOSFilterMessage(string _listenerID, string _NFCFilterfID)
        {
            OscMessage message = new OscMessage();
            message.address = "/listener/setSOSFilters";
            message.values.Add(_listenerID);
            message.values.Add(_NFCFilterfID);
            return message;
        }
        public OscMessage GetListenerSetEnableNearFieldEffect(string _listenerID, bool _enabled)
        {
            OscMessage message = new OscMessage();
            message.address = "/listener/enableNearFieldEffect";
            message.values.Add(_listenerID);
            if (_enabled) { message.values.Add(1); }
            else { message.values.Add(0); }
            return message;
        }

        public OscMessage GetListenerEnableBilateralAmbisonics(string _listenerID, bool _enabled)
        {
            OscMessage message = new OscMessage();
            message.address = "/listener/enableBilateralAmbisonics";
            message.values.Add(_listenerID);
            if (_enabled) { message.values.Add(1); }
            else { message.values.Add(0); }
            return message;
        }
        public OscMessage GetListenerSetAmbisonicOrder(string _listenerID, int _order)
        {
            OscMessage message = new OscMessage();
            message.address = "/listener/setAmbisonicsOrder";
            message.values.Add(_listenerID);
            message.values.Add(_order);
            return message;
        }

        public OscMessage GetListenerSetAmbisonicNormalization(string _listenerID, string _normalization)
        {
            OscMessage message = new OscMessage();
            message.address = "/listener/setAmbisonicsOrder";
            message.values.Add(_listenerID);
            message.values.Add(_normalization);
            return message;
        }


        //// ENVIRONMENT

        public OscMessage GetSetEnvironmentReverbOrderMessage(string _reverbOrder)
        {
            OscMessage message = new OscMessage();
            message.address = "/notImplemented";
            message.values.Add(_reverbOrder);
            return message;
        }

        public OscMessage GetEnvironmentReverbOverallGainMessage(float _gain)
        {
            OscMessage message = new OscMessage();
            message.address = "/notImplemented";
            message.values.Add(_gain);
            return message;
        }
        
        // Binaural Filter
        public OscMessage GetSetBinauralFilterEnableModel(string modelID, bool _enabled)
        {       
            OscMessage message = new OscMessage();
            message.address = "/binauralFilter/enableModel";
            message.values.Add(modelID);
            if (_enabled) { message.values.Add(1); }
            else { message.values.Add(0); }
            return message;
        }

        public OscMessage GetBinauralFilterSetSOSFilterMessage(string _listenerID, string _NFCFilterfID)
        {
            OscMessage message = new OscMessage();
            message.address = "/binauralFilter/setSOSFilter";
            message.values.Add(_listenerID);
            message.values.Add(_NFCFilterfID);
            return message;
        }

        public OscMessage GetPlayCalibrationMessage(float _dBFS)
        {
            OscMessage message = new OscMessage();
            message.address = "/control/playCalibration";
            message.values.Add(_dBFS);
            return message;
        }

        public OscMessage GetSetCalibrationMessage(float _dBFS, float _dBSPL)
        {
            OscMessage message = new OscMessage();
            message.address = "/control/setCalibration";
            message.values.Add(_dBFS);
            message.values.Add(_dBSPL);
            return message;
        }

        public OscMessage GetPlayCalibrationTestMessage(float _dBSPL)
        {
            OscMessage message = new OscMessage();
            message.address = "/control/playCalibrationTest";
            message.values.Add(_dBSPL);
            return message;
        }

        public OscMessage GetStopCalibrationTestMessage()
        {
            OscMessage message = new OscMessage();
            message.address = "/control/stopCalibrationTest";
            return message;
        }

        public OscMessage GetSetSoundLevelLimitMessage(float _limitdBSPL)
        {
            OscMessage message = new OscMessage();
            message.address = "/control/setSoundLevelLimit";
            message.values.Add(_limitdBSPL);
            return message;
        }

        public OscMessage GetGetSoundLevelMessage(string _listenerID)
        {
            OscMessage message = new OscMessage();
            message.address = "/control/getSoundLevel";
            message.values.Add(_listenerID);
            return message;
        }

        //OTHERS
        private Vector3 CalculateLocationToBeRTAConvention(Vector3 _locationUnity)
        {
            Vector3 locationBRT;
            locationBRT.x = _locationUnity.z;
            locationBRT.y = -_locationUnity.x;
            locationBRT.z = _locationUnity.y;

            return locationBRT;
        }


    }
}