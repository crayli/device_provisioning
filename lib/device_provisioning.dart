library device_provisioning;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

int getTypeValue(int type, int subtype) {
  return (subtype << 2) | type;
}

class FrameCtrlBit {
  static const int _encrypted = 0;
  static const int _checksum = 1;
  static const int _direction = 2;
  static const int _requiresAck = 3;
  static const int _frag = 4;
}

class DataFrameType {
  static const int _typeId = 0x01;
  static const int _neg = 0x00;
  static const int _staWifiBssid = 0x01;
  static const int _staWifiSsid = 0x02;
  static const int _staWifiPassword = 0x03;
  static const int _softapWifiSsid = 0x04;
  static const int _softapWifiPassword = 0x05;
  static const int _softapMaxConnectionCount = 0x06;
  static const int _softapAuthMode = 0x07;
  static const int _softapChannel = 0x08;
  static const int _username = 0x09;
  static const int _caCertification = 0x0a;
  static const int _clientCertification = 0x0b;
  static const int _serverCertification = 0x0c;
  static const int _clientPrivateKey = 0x0d;
  static const int _serverPrivateKey = 0x0e;
  static const int _wifiConnectionState = 0x0f;
  static const int _version = 0x10;
  static const int _wifiList = 0x11;
  static const int _error = 0x12;
  static const int _customData = 0x13;
}

class CtrlFrameType {
  static const int _typeId = 0x00;
  static const int _ack = 0x00;
  static const int _setSecMode = 0x01;
  static const int _setOpMode = 0x02;
  static const int _connectWifi = 0x03;
  static const int _disconnectWifi = 0x04;
  static const int _getWifiStatus = 0x05;
  static const int _deauthenticate = 0x06;
  static const int _getVersion = 0x07;
  static const int _closeConnection = 0x08;
  static const int _getWifiList = 0x09;
}

int _sequenceNumber = 0;
int generateSequence() {
  return _sequenceNumber++ & 0xff;
}

int getFrameCtrlValue(
    bool encrypted, bool checksum, bool isInput, bool requireAck, bool frag) {
  int frame = 0;
  if (encrypted) frame = frame | (1 << FrameCtrlBit._encrypted);
  if (checksum) frame = frame | (1 << FrameCtrlBit._checksum);
  if (isInput) frame = frame | (1 << FrameCtrlBit._direction);
  if (requireAck) frame = frame | (1 << FrameCtrlBit._requiresAck);
  if (frag) frame = frame | (1 << FrameCtrlBit._frag);
  return frame;
}

List<int> buildReqestMessage(
  bool encrypt, bool checksum, bool requireAck, int type, List<int> body) {
  final frameCtrl = getFrameCtrlValue(encrypt, checksum, false, requireAck, false);
  final sequence = generateSequence();
  return [type, frameCtrl, sequence, body.length, ...body];
}

List<(String, int)> constructApInfo(List<int> buffer) {
  if (buffer.length < 5) throw Exception("Invalid buffer length");
  if (buffer[0] >> 2 != DataFrameType._wifiList) return [];
  List<(String, int)> ssids = [];
  for (int i = 4, l; i < buffer.length; i += l + 1) {
    l = buffer[i];
    if (l == 0 || i + l > buffer.length) break;
    final rssi = buffer[i + 1].toSigned(8);
    final ssid = utf8.decode(buffer.sublist(i + 2, i + l + 1));
    ssids.add((ssid, rssi));
  }
  return ssids;
}

enum WifiOperationMode {
  unknown,
  station,
  ap,
  stationAndAp
}

enum WifiConnectionState {
  connected,
  disconnected,
  connecting,
  connectedWithoutIp,
  unknown
}

(WifiOperationMode, WifiConnectionState) parseWifiState(List<int> buffer) {
  if (buffer.length < 6) throw Exception("Invalid buffer length");
  if (buffer[0] >> 2 != DataFrameType._wifiConnectionState) return (WifiOperationMode.unknown, WifiConnectionState.unknown);

  final opMode = buffer[4];
  final state = buffer[5];
  if (state > WifiConnectionState.values.length || opMode >= WifiOperationMode.values.length) {
    return (WifiOperationMode.unknown, WifiConnectionState.unknown);
  }
  return (WifiOperationMode.values[opMode], WifiConnectionState.values[state]);
}

void handleNotifications(List<int> buffer) {
  if (buffer.length < 6) return;
  final msgType = buffer[0] >> 2;
  final frameType = buffer[0] & 0x03;
  final frameCtrl = buffer[1];
  final seq = buffer[2];
  final len = buffer[3];
  // final data = Int8List.view(buffer.buffer, 4, len);
  // print("Notification: ", msgType, frameType, frameCtrl, seq, len);
  if (frameType == 0) {
    // print("Control frame not handled yet: ", msgType);
    return;
  }

  // var evtText = "Event: 0x${msgType.toRadixString(16)} not handled yet";
  switch (msgType) {
    case DataFrameType._wifiConnectionState:
      // evtText = "WiFi operation mode: " + ["NULL", "STA", "AP", "STA+AP"][data[0]];
      // if (data[0] == 1) evtText += ", State: " + ["connected", "disconnected", "connecting", "connected(no IP)"][data[1]];
      // evtText += utf8.decode(data.sublist(3)).replaceAll(RegExp(r'[^ -~]+'), ' '); //TODO: check hub code and parse more data
      break;
    case DataFrameType._error:
      // print("Error: ", data[0]);
      break;
    case DataFrameType._wifiList:
      break;
    default:
      break;
  }
}

class DevProv {
  static final List<Guid> _services = [
    Guid("0000ffff-0000-1000-8000-00805f9b34fb"),
  ];
  static const _uuidWriteCharacteristic = "ff01";
  static const _uuidNotificationCahracteristic = "ff02";

  static const _scanWifi = (0x09 << 2) | CtrlFrameType._typeId;
  static const _configWifiSsid = (DataFrameType._staWifiSsid << 2) | DataFrameType._typeId;
  static const _configWifiPassword = (DataFrameType._staWifiPassword << 2) | DataFrameType._typeId;
  static const _connectWifi = (CtrlFrameType._connectWifi << 2) | CtrlFrameType._typeId;

  /// Sets the log level
  static Future<void> setLogLevel(LogLevel level, {color = true}) async {
    FlutterBluePlus.setLogLevel(level, color: color);
  }

  static Future<void> startScan({Duration? timeout}) async {
    FlutterBluePlus.startScan(withServices: _services, timeout: timeout);
  }

  static Future<Stream<List<int>>> scanWiFi(BluetoothDevice device, {int timeout = 15}) async {
    if (Platform.isAndroid) await device.requestMtu(223, predelay: 0);
    List<BluetoothService> services = await device.discoverServices();
    for (BluetoothService s in services) {
      for (BluetoothCharacteristic c in s.characteristics) {
        if (c.uuid == Guid(_uuidWriteCharacteristic)) {
          List<int> req =
              buildReqestMessage(false, false, false, _scanWifi, []);
          await c.write(req);
        } else if (c.uuid == Guid(_uuidNotificationCahracteristic)) {
          await c.setNotifyValue(true);
          // if (c.properties.read) await c.read();
          return c.onValueReceived;
        }
      }
    }
    throw Exception("Characteristic not found");
  }

  static Future<Stream<List<int>>> connectWifi(BluetoothDevice device, String ssid, String password) async {
    List<BluetoothService> services = await device.discoverServices();
    for (BluetoothService s in services) {
      for (BluetoothCharacteristic c in s.characteristics) {
        if (c.uuid == Guid(_uuidWriteCharacteristic)) {
          const encoder = Utf8Encoder();
          final ssidBytes = encoder.convert(ssid);
          final passwordBytes = encoder.convert(password);
          List<int> req = buildReqestMessage(
              false, false, false, _configWifiSsid, ssidBytes);
          await c.write(req);
          req = buildReqestMessage(
              false, false, false, _configWifiPassword, passwordBytes);
          await c.write(req);
          req = buildReqestMessage(false, false, false, _connectWifi, []);
          await c.write(req);
        } else if (c.uuid == Guid(_uuidNotificationCahracteristic)) {
          await c.setNotifyValue(true);
          // if (c.properties.read) await c.read();
          return c.onValueReceived;
        }
      }
    }
    throw Exception("Characteristic not found");
  }
}
