import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:livekit_client/livekit_client.dart';
import '/widgets/text_field.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;

import '../exts.dart';
import 'room.dart';

class LoginPage extends StatefulWidget {
  //
  const LoginPage({
    Key? key,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  //
  static const _storeKeyUri = 'uri';
  static const _storeKeyToken = 'token';
  static const _storeKeySimulcast = 'simulcast';
  static const _storeKeyAdaptiveStream = 'adaptive-stream';
  static const _storeKeyDynacast = 'dynacast';
  static const _storeKeyFastConnect = 'fast-connect';
  static const _storeKeyE2EE = 'e2ee';
  static const _storeKeySharedKey = 'shared-key';
  static const _storeKeyMultiCodec = 'multi-codec';

  final _machineId = TextEditingController();
  final _userId = TextEditingController();

  String _uriCtrl = 'wss://bookendus.asuscomm.com';
  String _tokenCtrl = '';
  String _sharedKeyCtrl = '';
  bool _simulcast = true;
  bool _adaptiveStream = true;
  bool _dynacast = true;
  bool _busy = false;
  bool _fastConnect = false;
  bool _e2ee = false;
  bool _multiCodec = false;
  String _preferredCodec = 'Preferred Codec';

  @override
  void initState() {
    super.initState();
    // _readPrefs();
    if (lkPlatformIs(PlatformType.android)) {
      _checkPremissions();
    }
  }

  @override
  void dispose() {
    _userId.dispose();
    super.dispose();
  }

  Future<void> _checkPremissions() async {
    var status = await Permission.bluetooth.request();
    if (status.isPermanentlyDenied) {
      print('Bluetooth Permission disabled');
    }

    status = await Permission.bluetoothConnect.request();
    if (status.isPermanentlyDenied) {
      print('Bluetooth Connect Permission disabled');
    }

    status = await Permission.camera.request();
    if (status.isPermanentlyDenied) {
      print('Camera Permission disabled');
    }

    status = await Permission.microphone.request();
    if (status.isPermanentlyDenied) {
      print('Microphone Permission disabled');
    }
  }

  // Get Token
  Future<void> _getToken() async {
    final url = Uri.parse(
      'http://bookendus.asuscomm.com:8080/getToken?Room=${_machineId.text}&Id=${_userId.text}',
    );

    print('Token Url: ${url}');

    final response = await http.get(url);
    _tokenCtrl = response.body;

    print('Token: ${_tokenCtrl}');
  }

  // Save URL and Token
  Future<void> _writePrefs() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_storeKeyUri, _uriCtrl);
    await prefs.setString(_storeKeyToken, _tokenCtrl);
    await prefs.setString(_storeKeySharedKey, _sharedKeyCtrl);
    await prefs.setBool(_storeKeySimulcast, _simulcast);
    await prefs.setBool(_storeKeyAdaptiveStream, _adaptiveStream);
    await prefs.setBool(_storeKeyDynacast, _dynacast);
    await prefs.setBool(_storeKeyFastConnect, _fastConnect);
    await prefs.setBool(_storeKeyE2EE, _e2ee);
    await prefs.setBool(_storeKeyMultiCodec, _multiCodec);
  }

  Future<void> _connect(BuildContext ctx) async {
    //
    try {
      setState(() {
        _busy = true;
      });

      // get Token
      await _getToken();
      // Save URL and Token for convenience
      await _writePrefs();

      print('Connecting with url: ${_uriCtrl}, '
          'token: ${_tokenCtrl}...');

      E2EEOptions? e2eeOptions;
      if (_e2ee) {
        final keyProvider = await BaseKeyProvider.create();
        e2eeOptions = E2EEOptions(keyProvider: keyProvider);
        var sharedKey = _sharedKeyCtrl;
        await keyProvider.setKey(sharedKey);
      }

      String preferredCodec = 'VP8';
      if (_preferredCodec != 'Preferred Codec') {
        preferredCodec = _preferredCodec;
      }

      // create new room
      final room = Room(
          roomOptions: RoomOptions(
        adaptiveStream: _adaptiveStream,
        dynacast: _dynacast,
        defaultAudioPublishOptions: const AudioPublishOptions(
          dtx: true,
        ),
        defaultVideoPublishOptions: VideoPublishOptions(
          simulcast: _simulcast,
          videoCodec: preferredCodec,
        ),
        defaultScreenShareCaptureOptions: const ScreenShareCaptureOptions(
            useiOSBroadcastExtension: true,
            params: VideoParametersPresets.screenShareH1080FPS30),
        e2eeOptions: e2eeOptions,
        defaultCameraCaptureOptions: const CameraCaptureOptions(
          maxFrameRate: 30,
          params: VideoParametersPresets.h720_169,
        ),
      ));

      // Create a Listener before connecting
      final listener = room.createListener();

      // Try to connect to the room
      // This will throw an Exception if it fails for any reason.
      await room.connect(
        _uriCtrl,
        _tokenCtrl,
        fastConnectOptions: _fastConnect
            ? FastConnectOptions(
                microphone: const TrackOption(enabled: true),
                camera: const TrackOption(enabled: true),
              )
            : null,
      );

      await Navigator.push<void>(
        ctx,
        MaterialPageRoute(builder: (_) => RoomPage(room, listener)),
      );
    } catch (error) {
      print('Could not connect $error');
      await ctx.showErrorDialog(error);
    } finally {
      setState(() {
        _busy = false;
      });
    }
  }

  void _setSimulcast(bool? value) async {
    if (value == null || _simulcast == value) return;
    setState(() {
      _simulcast = value;
    });
  }

  void _setE2EE(bool? value) async {
    if (value == null || _e2ee == value) return;
    setState(() {
      _e2ee = value;
    });
  }

  void _setAdaptiveStream(bool? value) async {
    if (value == null || _adaptiveStream == value) return;
    setState(() {
      _adaptiveStream = value;
    });
  }

  void _setDynacast(bool? value) async {
    if (value == null || _dynacast == value) return;
    setState(() {
      _dynacast = value;
    });
  }

  void _setFastConnect(bool? value) async {
    if (value == null || _fastConnect == value) return;
    setState(() {
      _fastConnect = value;
    });
  }

  void _setMultiCodec(bool? value) async {
    if (value == null || _multiCodec == value) return;
    setState(() {
      _multiCodec = value;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Container(
          alignment: Alignment.center,
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 20,
              ),
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 70),
                    child: SvgPicture.asset(
                      'images/logo-dark.svg',
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 25),
                    child: LKTextField(
                      label: 'Machine ID',
                      ctrl: _machineId,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 25),
                    child: LKTextField(
                      label: 'User ID',
                      ctrl: _userId,
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _busy ? null : () => _connect(context),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_busy)
                          const Padding(
                            padding: EdgeInsets.only(right: 10),
                            child: SizedBox(
                              height: 15,
                              width: 15,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                        const Text('CONNECT'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
