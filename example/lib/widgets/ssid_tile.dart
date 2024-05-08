import 'package:flutter/material.dart';

class SsidTile extends StatelessWidget {
  final String ssid;
  final int rssi;

  const SsidTile({super.key, required this.ssid, required this.rssi});

  Widget buildSsid(BuildContext context) {
    return Text(ssid, style: const TextStyle(fontSize: 13));
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
            title: buildSsid(context),
            trailing: Text('$rssi dBm', style: const TextStyle(fontSize: 13))
          );
  }
}
