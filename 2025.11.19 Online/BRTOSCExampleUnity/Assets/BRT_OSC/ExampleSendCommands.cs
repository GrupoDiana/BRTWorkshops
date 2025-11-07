using BRTOSC;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Networking.Types;

public class ExampleSendCommands : MonoBehaviour
{
    public BRTCommands BRT_Commands;
    private BRTManager brtManager;

    bool OSCConnectionIsReady;
    bool nearfieldEnabled = false;
    
    private void Awake()
    {
        OSCConnectionIsReady = false;
        brtManager = BRTManager.Instance;
    }

    // Start is called before the first frame update
    void Start()
    {
        OSCConnectionIsReady = false;
        brtManager.OnOSCConnectionReady += OSCConnectionReady;
    }

    // Update is called once per frame
    void Update()
    {        
        if (Input.GetKeyDown(KeyCode.Space))
        {
            if (!OSCConnectionIsReady) return;
            nearfieldEnabled = !nearfieldEnabled;
            BRT_Commands.SendListenerEnableNearFieldEffect("DefaultListener", nearfieldEnabled);            
        }
    }

    private void OSCConnectionReady(bool success)
    {
        if (!success)
        {            
            return;
        }
        if (BRT_Commands != null)
        {
            OSCConnectionIsReady = true;
        }
    }
}
