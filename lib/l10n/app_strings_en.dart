import 'app_strings.dart';

/// English texts. It is also the fallback language when the system asks for
/// one that is not translated.
class AppStringsEn extends AppStrings {
  const AppStringsEn();

  @override
  List<String> get cardinals => const [
    'N',
    'NE',
    'E',
    'SE',
    'S',
    'SW',
    'W',
    'NW',
  ];

  @override
  String selfieView({required bool front}) =>
      front ? 'Mirror: front camera' : 'Mirror: main camera';

  @override
  String viewToggle({required bool selfie, required bool flat}) {
    if (selfie) {
      return flat
          ? 'Mirror. Tap to go back to the compass.'
          : 'Mirror. Tap to go back to the bearing ruler.';
    }
    return flat
        ? 'Compass. Tap to see the mirror.'
        : 'Bearing ruler. Tap to see the mirror.';
  }

  @override
  String cameraSwitch({required bool front}) => front
      ? 'Front camera. Tap to see the main camera.'
      : 'Main camera. Tap to see the front camera.';

  @override
  String get cameraOpening => 'Opening the camera…';

  @override
  String get cameraDenied => 'No camera permission';

  @override
  String get cameraDeniedHint =>
      'Grant CompassTorch camera permission in the phone settings to use the '
      'screen as a mirror.';

  @override
  String get cameraUnavailable => 'Camera unavailable';

  @override
  String get cameraUnavailableHint =>
      'This device has no usable camera, or another app is using it.';

  @override
  String torchState({required bool on, int? percent}) {
    if (!on) return 'Torch off';
    return percent == null ? 'Torch on' : 'Torch on at $percent percent';
  }

  @override
  String beaconState({required bool on, int? percent}) {
    if (!on) return 'Beacon off';
    return percent == null ? 'Beacon on' : 'Beacon on at $percent percent';
  }

  @override
  String padLabel({required bool keepAwake}) {
    const pad = 'Torch and beacon pad.';
    return keepAwake
        ? '$pad The screen is kept awake; press and hold the rest square to '
              'let it switch off.'
        : '$pad The screen may switch off; press and hold the rest square to '
              'keep it awake.';
  }

  @override
  String get levelCentered => 'Phone level';

  @override
  String get levelOff => 'Phone tilted';

  @override
  String get calibrating => 'Looking for the magnetic field…';

  @override
  String get calibrateHintFlat =>
      'Move the phone in a figure of eight to calibrate the compass.';

  @override
  String get calibrateHintUpright =>
      'Raise the phone and move it in a figure of eight to calibrate.';

  @override
  String elevation(String degrees) => 'elevation $degrees';

  @override
  String get torchUnavailable =>
      'The torch could not be switched on: this device has no flash '
      'available, or another app is using it.';

  @override
  String get torchOffFailed => 'The torch could not be switched off.';

  @override
  String get beaconPartial =>
      'Beacon mode is only partly on: the system did not allow changing the '
      'brightness or keeping the screen awake.';
}
