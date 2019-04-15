import 'dart:convert';

import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter_kin_sdk/flutter_kin_sdk.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _platformVersion = 'Unknown';
  String firstPublicAddress;
  String secondPublicAddress;
  String recoveryString;
  int count = 0;

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    FlutterKinSdk.infoStream.receiveBroadcastStream().listen((data) async {
      streamReceiver(data);
    }, onError: (error) {
      print(error);
    });

    FlutterKinSdk.balanceStream.receiveBroadcastStream().listen((data) async{
      print(data);
    });

    FlutterKinSdk.initKinClient("wBu7");
  }

  Future streamReceiver(data) async {
    Info info = Info().fromJson(json.decode(data));
    
    switch (info.type) {
      case "InitKinClient":
        print(info.message);
        firstPublicAddress = await FlutterKinSdk.createAccount();
        secondPublicAddress = await FlutterKinSdk.createAccount();
        break;
      case "CreateAccountOnPlaygroundBlockchain":
        print(info.type + " Wallet: " + info.value);
        // FlutterKinSdk.sendTransaction(firstPublicAddress, secondPublicAddress, 100, "some", 10);
        break;
      case "DeleteAccount":
        print(info.message);
        break;
      case "SendTransaction":
        print(info.message + " Amount: " + info.value);
        break;
      case "SendWhitelistTransaction":
        print(info.message + " Amount: " + info.value);
        break;
      case "PaymentEvent":
        print(info.message + " Amount: " + info.value);
        print(await FlutterKinSdk.getAccountBalance(secondPublicAddress));
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Center(
          child: Text('Running on: $_platformVersion\n'),
        ),
      ),
    );
  }
}

class Info {
  String type;
  String message;
  String value;

  Info fromJson(Map<dynamic, dynamic> raw) {
    Map<String, dynamic> json = Map<String, dynamic>.from(raw);

    if (json['type'] != null) type = json['type'];

    if (json['message'] != null) message = json['message'];

    if (json['value'] != null) value = json['value'];

    return this;
  }
}
