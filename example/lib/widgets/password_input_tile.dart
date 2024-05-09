import 'package:device_provisioning/device_provisioning.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import "../utils/snackbar.dart";

class PasswordInputTile extends StatefulWidget {
  final BluetoothDevice device;
  final String ssid;

  const PasswordInputTile({super.key, required this.ssid, required this.device});

  @override 
  State<PasswordInputTile> createState() => _PasswordInputTileState(); 
}

class _PasswordInputTileState extends State<PasswordInputTile> {
  bool passwordVisible = false; 
  final passwordController = TextEditingController();

  @override
  void dispose() {
    // Clean up the controller when the widget is disposed.
    passwordController.dispose();
    super.dispose();
  }

  Future onConnectPressed() async {
    try {
      final stream = await DevProv.connectWifi(widget.device, widget.ssid, passwordController.text);
      stream.listen((value) {
          final result = parseWifiState(value);
          Snackbar.show(ABC.c, "WiFi state: ${result.$2}", success: true);
          if (mounted) setState(() {});
      });
      Snackbar.show(ABC.c, "Connecting to ${widget.ssid}", success: true);
    } catch (e) {
      Snackbar.show(ABC.c, prettyException("Descriptor Write Error:", e), success: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children:<Widget>[
          const Text('WiFi Password', style: TextStyle(fontSize: 12)),
          buildInputField(context),
        ],      
      ),
      subtitle: buildConnectButton(context),
    );
  }

  Widget buildInputField(BuildContext context) {
  return TextField(
    obscureText: !passwordVisible,
    decoration: InputDecoration(
      suffixIcon: IconButton(
        icon: Icon(passwordVisible ? Icons.visibility : Icons.visibility_off),
        onPressed: () {
          setState(() {
            passwordVisible = !passwordVisible;
          });
        },
      ),
      // labelText: "WiFi Password",
      border: InputBorder.none,
      errorText: passwordController.value.text.length < 8 && passwordController.value.text.isNotEmpty ? "Too short" : null,
    ),
    controller:passwordController,
    onChanged: (t) => setState(() {}),);
  }

  Widget buildConnectButton(BuildContext context) {
    return TextButton(
      onPressed: passwordController.value.text.length >= 8 ? onConnectPressed : null,
      child: const Text("Connect"),
    );
  }
}
/*
Scaffold( 
        appBar: AppBar(title: Text('Show or Hide Password in TextField'),), 
        body: Container( 
                padding: EdgeInsets.all(20.0), 
                child: TextField( 
                  obscureText: passwordVisible, 
                  decoration: InputDecoration( 
                    border: UnderlineInputBorder(), 
                    hintText: "Password", 
                    labelText: "Password", 
                    helperText:"Password must contain special character", 
                    helperStyle:TextStyle(color:Colors.green), 
                    suffixIcon: IconButton( 
                      icon: Icon(passwordVisible 
                          ? Icons.visibility 
                          : Icons.visibility_off), 
                      onPressed: () { 
                        setState( 
                          () { 
                            passwordVisible = !passwordVisible; 
                          }, 
                        ); 
                      }, 
                    ), 
                    alignLabelWithHint: false, 
                    filled: true, 
                  ), 
                  keyboardType: TextInputType.visiblePassword, 
                  textInputAction: TextInputAction.done, 
                ), 
              ),  
              */
  