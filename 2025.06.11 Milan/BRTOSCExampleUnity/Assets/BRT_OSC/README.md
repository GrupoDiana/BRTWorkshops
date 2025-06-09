# Unity-BRT Integration Package

This package enables the integration of a Unity scene with applications from the BRT library using OSC commands.

## Package Contents

### `BRTManager.cs`
A dual-purpose class designed to:
1. Serve as an example of how to use the package.
2. It can be used and extended by anyone, as it implements some important OSC commands.  

### `BRTCommands.cs`
This class handles the implementation, sending, and receiving of OSC commands.

**Note:** This class is still under development. Bugs may be present, and not all commands from the BRT interface are currently implemented. For more details about the available OSC commands, refer to the [BRT OSC Documentation](https://grupodiana.github.io/BRT-Documentation/osc/).

### `BRTAudioListener.cs`
This script sends the listener's position and orientation to the BRT renderer via OSC commands.

To use this:
- Attach the script to your scene's camera object, or
- Instantiate the `CenterEarAnchor.prefab`.

### `CenterEarAnchor.prefab`
A prefab designed to be placed under the "center eye" object in a virtual reality scene. Its purpose is to apply an offset, positioning it virtually at the center of the listener's head. This prefab also includes the `BRTAudioListener.cs` script.

### `OSC.cs`
A third-party library that implements the OSC protocol. Configure the IP and port for the remote application and the listening port for the Unity app in this script.

## License

Except for the OSC.cs class which has not been developed by us, the rest of the scripts in this package are distributed under MIT license.
