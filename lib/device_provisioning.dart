library device_provisioning;

import 'dart:convert';

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
  static const int _packageValue = 0x01;
  static const int _Neg = 0x00;
  static const int _StaWifiBssid = 0x01;
  static const int _StaWifiSsid = 0x02;
  static const int _StaWifiPassword = 0x03;
  static const int _SoftapWifiSsid = 0x04;
  static const int _SoftapWifiPassword = 0x05;
  static const int _SoftapMaxConnectionCount = 0x06;
  static const int _SoftapAuthMode = 0x07;
  static const int _SoftapChannel = 0x08;
  static const int _Username = 0x09;
  static const int _CaCertification = 0x0a;
  static const int _ClientCertification = 0x0b;
  static const int _ServerCertification = 0x0c;
  static const int _ClientPrivateKey = 0x0d;
  static const int _ServerPrivateKey = 0x0e;
  static const int _WifiConnectionState = 0x0f;
  static const int _Version = 0x10;
  static const int _WifiList = 0x11;
  static const int _Error = 0x12;
  static const int _CustomData = 0x13;
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
    bool encrypt, bool checksum, bool requireAck, int type) {
  final frameCtrl =
      getFrameCtrlValue(encrypt, checksum, false, requireAck, false);
  final sequence = generateSequence();
  return [type, frameCtrl, sequence, 0];
}

List<(String, int)> constructApInfo(List<int> buffer) {
  List<(String, int)> ssids = [];
  for (int i = 0, l = 0; i < buffer.length; i += l + 1) {
    l = buffer[i];
    if (l == 0 || i + l > buffer.length) break;
    final rssi = buffer[i + 1].toSigned(8);
    final ssid = utf8.decode(buffer.sublist(i + 2, i + l + 1));
    ssids.add((ssid, rssi));
  }
  return ssids;
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
    case DataFrameType._WifiConnectionState:
      // evtText = "WiFi operation mode: " + ["NULL", "STA", "AP", "STA+AP"][data[0]];
      // if (data[0] == 1) evtText += ", State: " + ["connected", "disconnected", "connecting", "connected(no IP)"][data[1]];
      // evtText += utf8.decode(data.sublist(3)).replaceAll(RegExp(r'[^ -~]+'), ' '); //TODO: check hub code and parse more data
      break;
    case DataFrameType._Error:
      // print("Error: ", data[0]);
      break;
    case DataFrameType._WifiList:
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

  static const _ctrlFrame = 0;
  static const _dataFrame = 1;
  static const _scanWifi = (0x09 << 2) | _ctrlFrame;

  /// Sets the log level
  static Future<void> setLogLevel(LogLevel level, {color = true}) async {
    FlutterBluePlus.setLogLevel(level, color: color);
  }

  static Future<void> startScan({Duration? timeout}) async {
    FlutterBluePlus.startScan(withServices: _services, timeout: timeout);
  }

  static Future<Stream<List<int>>> scanWiFi(BluetoothDevice device,
      {int timeout = 15}) async {
    List<BluetoothService> services = await device.discoverServices();
    for (BluetoothService s in services) {
      for (BluetoothCharacteristic c in s.characteristics) {
        if (c.uuid == Guid(_uuidWriteCharacteristic)) {
          List<int> req = buildReqestMessage(false, false, false, _scanWifi);
          await c.write(req);
        } else if (c.uuid == Guid(_uuidNotificationCahracteristic)) {
          await c.setNotifyValue(true);
          if (c.properties.read) await c.read();
          return c.onValueReceived;
        }
      }
    }
    throw Exception("Characteristic not found");
  }
}