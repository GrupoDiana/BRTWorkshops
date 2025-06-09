using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using static BRTOSC.BRTCommands;

namespace BRTOSC
{    
    public enum TAudioRenderApplication { bita, berta }
             
    public class BRTManager : MonoBehaviour
    {
        private class CResourceData
        {
            public enum TState { loaded, waiting, error };
            
            public string id;
            public TState state;            

            public CResourceData(string _id)
            {
                id = _id;
                state = TState.waiting;
            }
        }

        public event Action<bool> OnOSCConnectionReady;
        public event Action<string, bool> OnHRTFLoaded;
        public event Action<string, bool> OnBRIRLoaded;
        public event Action<string, float, float, DateTime> OnSoundLevelReceived;
        public event Action<float, float, DateTime> OnSoundAlertReceived;

        public static BRTManager Instance { get; private set; }
               
        public TAudioRenderApplication renderApplication = TAudioRenderApplication.berta;

        //private OSC oscLibrary;
        private BRTCommands brtCommands;
        private bool oscConnectionReady;        
        
        //private string listenerID;        
        private bool coroutineSoundLevelAlertRunning;
        private List<CResourceData> hrtfList;
        private List<CResourceData> brirList;

        private void Awake()
        {
            //EditorSceneManager.SceneClosedCallback += SceneClosed;

            if (Instance == null)
            {
                Instance = this;
                DontDestroyOnLoad(gameObject);
            }
            else
            {
                Destroy(this);
            }

            brtCommands = FindObjectOfType<BRTCommands>();

            oscConnectionReady = false;            
            coroutineSoundLevelAlertRunning = false;
            hrtfList = new List<CResourceData>();
            brirList = new List<CResourceData>();
            //listenerID = "DefaultListener";                       
        }

        private void OnDisable()
        {
            SceneClosed();
        }

        private void SceneClosed()
        {
            //throw new NotImplementedException();
            if (!oscConnectionReady) return;
            brtCommands.ResetConnection();
        }
        
        // Start is called before the first frame update
        void Start()
        {
            brtCommands.OnCommandReceived += GetCommandReceived;
            SetRenderApplication(TAudioRenderApplication.berta);
            InitAudioRenderConnection();
        }

        private void BrtCommands_OnCommandReceived(string obj)
        {
            throw new NotImplementedException();
        }

        // Update is called once per frame
        void Update()
        {
            if (!coroutineSoundLevelAlertRunning && oscConnectionReady)
            {
                StartCoroutine(CoroutineSoundLevelAlert_BeRTA());
            }
        }
        
        public void SetRenderApplication(string _app)
        {
            TAudioRenderApplication _renderApp = GetAudioRenderApplicationByName(_app);
            SetRenderApplication(_renderApp);                                         
        }
        
        /// <summary>
        /// Set the render application
        /// </summary>
        /// <param name="renderApplication"></param>
        public void SetRenderApplication(TAudioRenderApplication renderApplication)
        {
            this.renderApplication = renderApplication;
            brtCommands.SetAudioRenderApplication(renderApplication);
        }

        /// <summary>
        /// Get the render application
        /// </summary>
        /// <returns></returns>
        public TAudioRenderApplication GetRenderApplication()
        {
            return renderApplication;
        }

        /// <summary>
        /// Get the render application by name
        /// </summary>
        /// <param name="_applicationName"></param>
        /// <returns></returns>
        private TAudioRenderApplication GetAudioRenderApplicationByName(string _applicationName)
        {
            string temp = _applicationName.ToLower();
            if (temp == "bita") { return TAudioRenderApplication.bita; }
            else if (temp == "berta") { return TAudioRenderApplication.berta; }
            else { return TAudioRenderApplication.bita; }
        }




        /// <summary>
        /// Get any command received from the Audio Render by OSC
        /// </summary>
        /// <param name="_command"></param>
        private void GetCommandReceived(string _command)
        {
            if (_command == "/control/actionResult")
            {
                if (brtCommands.IsReceivedActionResultLoadHRTF())
                {
                    ProcessWaitingHRTFLoad();
                } else if (brtCommands.IsReceivedActionResultLoadBRIR())
                {
                    ProcessWaitingBRIRLoad();
                }
            }
            else if (_command.StartsWith("/control/"))
            {
                Debug.Log("Message received : " + _command);
            }
        }

        ////////////////////////////
        //// CONNECTION INITIALIZATION
        ////////////////////////////

        /// <summary>
        /// Initialize the connection with the Audio Render.
        /// This method only works with the Berta Audio Render.
        /// </summary>
        public void InitAudioRenderConnection()
        {
            if (oscConnectionReady == true) return;
            if (renderApplication == TAudioRenderApplication.berta)
            {
                oscConnectionReady = false;
                StartCoroutine(CoroutineInitAudioRenderConnection());
            }
            else {
                oscConnectionReady = true;
            }                

        }

        /// <summary>
        /// Check if the connection with the Audio Render is established
        /// </summary>
        /// <returns></returns>
        public bool IsConnected()
        {
            return oscConnectionReady;
        }

        private IEnumerator CoroutineInitAudioRenderConnection()
        {
            // Config render
            brtCommands.ControlConnect();        // Connect to render        
            float safetyTimer = 10;
            bool error = false;            
            while (!brtCommands.IsReceivedControlConnect())           {
                yield return new WaitForSeconds(0.1f);
                safetyTimer -= 0.1f;
                if (safetyTimer < 0)
                {                    
                    OnOSCConnectionReady?.Invoke(false);
                    //Debug.LogError(("ERROR trying to connect to Audio Render").Color(Color.red));
                    Debug.LogError(("ERROR trying to connect to Audio Render"));
                    error = true;
                    break;                    
                }
            }
            if (!error)
            {
                Debug.Log(("Connection established"));
                //Debug.Log(("Connection established").Color(Color.magenta));
                OscMessage message = brtCommands.GetReceivedControlConnect();
                oscConnectionReady = true;
                brtCommands.RemoveAllSources();                
                OnOSCConnectionReady?.Invoke(true);
                StartCoroutine(CoroutineSoundLevelAlert_BeRTA());
            }
        }

        ////////////////////////////
        //// HRTF
        ////////////////////////////
        
        /// <summary>
        /// 
        /// </summary>
        /// <param name="_hrtfID"></param>
        /// <param name="_hrtfFileName">Filename full path</param>
        public void LoadHRTF(string _hrtfID, string _hrtfFileName, float spatialResolution)       
        {
            if (renderApplication == TAudioRenderApplication.berta)
            {                              
                if (AddToResourceList(hrtfList,_hrtfID)) {
                    brtCommands.LoadHRTF(_hrtfID, _hrtfFileName, spatialResolution);
                }                
            }
            else
            {
                StartCoroutine(CoroutineLoadHRTF_BiTA(_hrtfID, _hrtfFileName, spatialResolution));
            }
            
        }
               
        private void ProcessWaitingHRTFLoad()
        {
            OscMessage message = brtCommands.GetReceivedCommandLoadHRTF();
            string messageHRFTID = message.values[1].ToString();
            CResourceData _hrtf = hrtfList.Find(x => x.id == messageHRFTID);
            if (_hrtf != null) {                
                if (message.values[2].ToString() == "true")
                {
                    _hrtf.state = CResourceData.TState.loaded;
                    //brtCommands.SetListenerHRTF(listenerID, _hrtf.id);
                    OnHRTFLoaded?.Invoke(messageHRFTID, true);
                }
                else
                {
                   _hrtf.state = CResourceData.TState.error;
                    Debug.LogError("ERROR trying to load the HRTF SOFA file");
                    OnHRTFLoaded?.Invoke(messageHRFTID, false);
                }
            }
            else
            {
                Debug.LogError("ERROR " + messageHRFTID + " BeRTA reports that an unsolicited HRTF SOFA has been uploaded.");
            }
        }       

        private IEnumerator CoroutineLoadHRTF_BiTA(string _hrtfID, string _hrtfFileName, float spatialResolution)
        {
            if (AddToResourceList(hrtfList, _hrtfID))
            {
                brtCommands.LoadHRTF(_hrtfID, _hrtfFileName, spatialResolution);
                //brtCommands.SetListenerHRTF(listenerID, _hrtfID);
                yield return new WaitForSeconds(10);

                CResourceData _hrtf = hrtfList.Find(x => x.id == _hrtfID);
                _hrtf.state = CResourceData.TState.loaded;
                OnHRTFLoaded?.Invoke(_hrtfID, true);
            }
        }
        
       
        ////////////////////////////
        //// BRIR    
        ////////////////////////////

        public void LoadBRIR(string _brirID, string _brirFileName, float spatialResolution)
        {
            if (renderApplication == TAudioRenderApplication.berta)
            {
                //StartCoroutine(CoroutineLoadBRIR_BeRTA(_brirID, _brirFileName, spatialResolution));
                if (AddToResourceList(brirList, _brirID))
                {
                    brtCommands.LoadBRIR(_brirID, _brirFileName, spatialResolution);
                }
            }
            else
            {
                StartCoroutine(CoroutineLoadBRIR_BiTA(_brirID, _brirFileName));
            }
        }

        private void ProcessWaitingBRIRLoad()
        {            
            OscMessage message = brtCommands.GetReceivedCommandLoadBRIR();
            string messageBRIRID = message.values[1].ToString();
            CResourceData _brir = brirList.Find(x => x.id == messageBRIRID);
            if (_brir != null)
            {
                if (message.values[2].ToString() == "true")
                {
                    _brir.state = CResourceData.TState.loaded;
                    //brtCommands.SetListenerBRIR(listenerID, _brir.id);
                    OnBRIRLoaded?.Invoke(_brir.id, true);
                }
                else
                {
                    _brir.state = CResourceData.TState.error;
                    Debug.LogError("ERROR trying to load the BRIR SOFA file");
                    OnBRIRLoaded?.Invoke(_brir.id, false);
                }
            }
            else
            {
                Debug.LogError("ERROR " + messageBRIRID + " BeRTA reports that an unsolicited BRIR SOFA has been uploaded.");
            }
        }
                

        private IEnumerator CoroutineLoadBRIR_BiTA(string _brirID, string _brirFileName)
        {
            if (AddToResourceList(brirList, _brirID))
            {
                brtCommands.LoadBRIR(_brirID, _brirFileName, 10.0f);
                //brtCommands.SetListenerBRIR(_brirID, _brirID);
                yield return new WaitForSeconds(10);

                CResourceData _brir = brirList.Find(x => x.id == _brirID);
                _brir.state = CResourceData.TState.loaded;
                OnBRIRLoaded?.Invoke(_brirID, true);
            }
        }

        ////////////////////////////
        //// Sound Level
        ////////////////////////////      
        public void GetSoundLevel(string _listenerID)
        {
            if (renderApplication == TAudioRenderApplication.berta)
            {
                StartCoroutine(CoroutineGetSoundLevel_BeRTA(_listenerID));
            }            
        }
        private IEnumerator CoroutineGetSoundLevel_BeRTA(string _listenerID)
        {            
            brtCommands.GetSoundLevel(_listenerID);            
            while (!brtCommands.IsReceivedGetSoundLevel(_listenerID))
            {
                yield return new WaitForSeconds(0.05f);
            }            
            //var data2 = brtCommands.GetSoundLevels(_listenerID);
            //Debug.Log(data2.Count);
            SoundLevelData data = brtCommands.GetLastSoundLevel(_listenerID);
            if (data.id != _listenerID) yield break;
            OnSoundLevelReceived?.Invoke(_listenerID, data.leftdBSLP, data.rigthdBSPL, data.time);            
        }

        private IEnumerator CoroutineSoundLevelAlert_BeRTA()
        {
            coroutineSoundLevelAlertRunning = true;            
            while (!brtCommands.IsReceivedSoundLevelAlert())
            {
                yield return new WaitForSeconds(0.25f);
            }
            //var dataList = brtCommands.GetSoundLevels("soundLevelAlert");
            //Debug.Log(dataList.Count);
            SoundLevelData data = brtCommands.GetLastSoundLevel("soundLevelAlert");
            if (data.id != "soundLevelAlert") yield break;
            OnSoundAlertReceived?.Invoke(data.leftdBSLP, data.rigthdBSPL, data.time);            
            coroutineSoundLevelAlertRunning = false;
        }


        ////////////////////////////
        //// OTHERS
        ////////////////////////////

        public void LoadSource(string _sourceID, string _sourceFileName)
        {
            brtCommands.LoadSoundSource(_sourceID, _sourceFileName, "SimpleModel");

        }
        public void LoadSource(string _sourceID, string _sourceFileName, string _modelToConnectTo)
        {
            brtCommands.LoadSoundSource(_sourceID, _sourceFileName, "SimpleModel", _modelToConnectTo);

        }

        public void SetSourceLocation(string _sourceID, Vector3 _position)
        {
            brtCommands.SetSoundSourceLocation(_sourceID, _position);
        }


        ////////////////////////////
        //// RESOURCE MANAGEMENT
        ////////////////////////////
        public bool IsHRTFLoaded(string _hrtfID)
        {
            return IsResourceState(hrtfList, _hrtfID, CResourceData.TState.loaded);
        }

        public bool IsHRTFLoading(string _hrtfID)
        {
            return IsResourceState(hrtfList, _hrtfID, CResourceData.TState.waiting);            
        }

        public bool IsHRTFError(string _hrtfID)
        {
            return IsResourceState(hrtfList, _hrtfID, CResourceData.TState.error);            
        }

        public bool IsBRIRLoaded(string _brirID)
        {
            return IsResourceState(brirList, _brirID, CResourceData.TState.loaded);
        }

        private bool IsResourceState(List<CResourceData> _resourceList, string _ID, CResourceData.TState _stateToCheck)
        {
            return (GetResourceState(_resourceList, _ID) == _stateToCheck);
        }

        /// <summary>
        /// 
        /// </summary>
        /// <param name="_resourceList"></param>
        /// <param name="_ID"></param>
        /// <returns></returns>
        private bool AddToResourceList(List<CResourceData> _resourceList, string _ID)
        {
            if (ExistInResourceList(_resourceList,_ID)) {
                if (IsResourceState(_resourceList,_ID, CResourceData.TState.loaded) 
                    || (IsResourceState(_resourceList,_ID, CResourceData.TState.waiting)))
                {
                    Debug.LogWarning("This Resource " + _ID + " is already loaded or loading");
                    return false;
                }
                if (IsResourceState(_resourceList,_ID, CResourceData.TState.error))
                {
                    RemoveFromResourceList(_resourceList, _ID);
                }
            };

            _resourceList.Add(new CResourceData(_ID));
            return true;
        }

        private bool RemoveFromResourceList(List<CResourceData> _resourceList, string _ID)
        {
            CResourceData _resource = _resourceList.Find(x => x.id == _ID);
            if (_resource != null)
            {
                _resourceList.Remove(_resource);
                return true;
            }
            else return false;
        }
        
        private CResourceData.TState GetResourceState(List<CResourceData> _resourceList, string _ID)
        {
            CResourceData _resource = _resourceList.Find(x => x.id == _ID);
            if (_resource != null) return _resource.state;
            else return CResourceData.TState.error;
        }

        private bool ExistInResourceList(List<CResourceData> _resourceList, string _ID)
        {
            return (_resourceList.Find(x => x.id == _ID) != null);
        }
    }
}