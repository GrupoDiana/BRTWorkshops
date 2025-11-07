/**
* \class BRTOSCAudioListener
*
* \brief This class sends the position and orientation of the camera to the BRTLibrary, using OSC commands. In addition, it calculates the accumulated rotation.
* \date	Jule 2022
*
* \authors A. Reyes-Lecuona, D. Gonzalez-Toledo, P. Garcia-Jimenez members of the 3DI-DIANA Research Group (University of Malaga)
* \b Contact: areyes@uma.es 
*
* \b Contributions: (additional authors/contributors can be added here)
*
* \b Project: SAVLab (Spatial Audio Virtual Laboratory) ||
* \b Website: 
*
* \b Copyright: University of Malaga - 2021
*
* \b Licence: GPL v3
*
* \b Acknowledgement: This project has received funding from Spanish Ministerio de Ciencia e Innovación under the SAVLab project (PID2019-107854GB-I00)
*/

using UnityEngine;
using System.Collections;
using System;
using BRTOSC;


namespace BRTOSC { 
    public class BRTAudioSource : MonoBehaviour {
        
        public BRTCommands BRT_Commands;
        public string sourceID = "Source1";
        public string fileName;
        
        private bool sourceLoaded;
        Vector3 previousPosition;
        Quaternion previousRotation;
        private BRTManager brtManager;
        
        readonly float EPSILON_ORIENTATION = 0.0001f;
        readonly float EPSILON_DISTANCE = 0.0001f;


        // Use this for initialization
        void Awake () {
            sourceLoaded = false;            
            previousRotation = transform.rotation;
            previousPosition = transform.position;
            brtManager = FindObjectOfType<BRTManager>();
        }

        private void Start()
        {
            sourceLoaded = false;
            brtManager.OnOSCConnectionReady += OSCConnectionReady;
            brtManager.OnSourceLoaded += OSCSourceLoaded;
            brtManager.OnSourceUnloaded += OSCSourceUnloaded;
        }

        // Update is called once per frame
        void Update () {
      
            if (!sourceLoaded)
            {
                return;
            }

            if (HasChangeRotation()) {
                SendOrientation();                   
                previousRotation = transform.rotation;
            }
            if (HasChangePosition())
            {         
                SendPosition();
                previousPosition = transform.position;
            }
        }

        public void ForceUpdate()
        {
            SendOrientation();
            previousRotation = transform.rotation;
            SendPosition();
            previousPosition = transform.position;
        }

        private void OSCConnectionReady(bool success)
        {
            if (!success)
            {
                Debug.LogError("BRT OSC connection not ready. Cannot load sound source.");
                return;
            }
            if (BRT_Commands != null)
            {
                //Debug.Log("BRT OSC connection ready. Loading the sound source.");
                BRT_Commands.LoadSoundSource(sourceID, fileName, "OmnidirectionalModel");
                //SendPosition();
                //SendOrientation();
            }            
        }
        private void SendPosition()
        {
            if (sourceID !="")            
                BRT_Commands.SetSoundSourceLocation(sourceID, transform.position);
        }

        private void SendOrientation()
        {
            Vector3 ejeY = new Vector3(0, 1, 0);

            Transform rotado = transform;
            //rotado.Rotate(ejeY, 180);

            Vector3 rotacion = ToYawPitchRoll(rotado);
            
            if (sourceID != "")                
                BRT_Commands.SoundSourceOrientation(sourceID, rotacion);
        }
    

        bool HasChangePosition()
        {
            //Debug.Log(Vector3.Distance(transform.position, previousPosition));
            return (Vector3.Distance(transform.position, previousPosition) > EPSILON_DISTANCE);                
        }

        bool HasChangeRotation()
        {
            double previousX = Math.Truncate(previousRotation.x * 100) / 100;
            double currentX = Math.Truncate(transform.rotation.x * 100) / 100;
        
            if (!isApproximate(previousRotation, transform.rotation, 0.04f))
            {
                //Debug.Log("Rotation changes 1");
            }

            if (previousRotation.eulerAngles != transform.localRotation.eulerAngles)
            {
                //Debug.Log("Rotation changes 2");
            }


            Quaternion zero = Quaternion.identity;

            // returns 0.9999996 => precision = 0.0000004
            Quaternion tenthDegree1Axis = Quaternion.Euler(0.1f, 0, 0);
            float veryClose = Quaternion.Dot(zero, tenthDegree1Axis);




            return Math.Truncate(previousRotation.x * 100) / 100 != Math.Truncate(transform.rotation.x * 100) / 100 || Math.Truncate(previousRotation.y * 100) / 100 != Math.Truncate(transform.rotation.y * 100) / 100 || Math.Truncate(previousRotation.z * 100) / 100 != Math.Truncate(transform.rotation.z * 100) / 100 || Math.Truncate(previousRotation.w * 100) / 100 != Math.Truncate(transform.rotation.w * 100) / 100;
        }

        public Vector3 ToYawPitchRoll(Transform rotado)
        {
            Quaternion q = rotado.rotation;
            Vector3 res;
            float x = q.x;

            q.x = q.z;
            q.z = q.y;
            q.y = x;

            // roll (forward-axis rotation)
            double sinr_cosp = +2.0 * (q.w * q.x + q.y * q.z);
            double cosr_cosp = +1.0 - 2.0 * (q.x * q.x + q.y * q.y);
            res.z = (float) Math.Atan2(sinr_cosp, cosr_cosp);

            // pitch (right-axis rotation)
            double sinp = +2.0 * (q.w * q.y - q.z * q.x);
            sinp = sinp > 1.0f ? 1.0f : sinp;
            sinp = sinp < -1.0f ? -1.0f : sinp;
            res.x = (float) Math.Asin(sinp);

            // yaw (up-axis rotation)
            double siny_cosp = +2.0 * (q.w * q.z + q.x * q.y);
            double cosy_cosp = +1.0 - 2.0 * (q.y * q.y + q.z * q.z);
            res.y = (float) Math.Atan2(siny_cosp, cosy_cosp);

            return res;
        }

        private bool isApproximate(Quaternion q1, Quaternion q2, float precision)
        {
            return Mathf.Abs(Quaternion.Dot(q1, q2)) >= 1 - precision;
        }

        private string GetFullPathToResources(string _filePath)
        {
            if (!System.IO.Path.IsPathRooted(_filePath))
            {
                string appPath = Application.dataPath;
                string temp = System.IO.Directory.GetParent(System.IO.Directory.GetParent(appPath).ToString()).ToString();
                return (temp + "/resources/" + _filePath);
            }
            else
            {
                return _filePath;
            }

        }

        private void OSCSourceLoaded(string _sourceID, bool _success)        
        {
            if (_sourceID != sourceID)
                return;

            if (!_success)
            {
                Debug.LogError("Error loadind sound source " + sourceID + "Cannot load file " + fileName);
                return;
            }
            else { 
                Debug.Log("Sound source " + sourceID + " loaded successfully.");
                ForceUpdate();
                sourceLoaded = true;
            }            
        }
        private void OSCSourceUnloaded(string _sourceID, bool _success)
        {
            if (_sourceID != sourceID)
                return;

            if (!_success)
            {
                Debug.LogError("Error loadind sound source " + sourceID + "Cannot load file " + fileName);
                return;
            }
            else
            {
                Debug.Log("Sound source " + sourceID + " loaded successfully.");               
                sourceLoaded = false;
                this.enabled = false;
            }
        }
    }
}
