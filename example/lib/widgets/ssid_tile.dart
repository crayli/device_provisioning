import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'password_input_tile.dart';

class SsidTile extends StatelessWidget {
  final BluetoothDevice device;
  final String ssid;
  final int rssi;

  const SsidTile({super.key, required this.ssid, required this.rssi, required this.device});

  Widget buildSsid(BuildContext context) {
    return Text(ssid, style: const TextStyle(fontSize: 13, color: Colors.blue));
  }

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
            title: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                buildSsid(context),
                Text('$rssi dBm', style: const TextStyle(fontSize: 12))
              ],
            ),
            children: [PasswordInputTile(ssid: ssid, device: device)],
          );
  }
}
