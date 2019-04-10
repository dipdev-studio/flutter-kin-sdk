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
  String publicAddress;

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

    FlutterKinSdk.initKinClient("wBu7");
  }

  Future streamReceiver(data) async {
    Info info = Info().fromJson(json.decode(data));


    switch (info.type) {
      case "InitKinClient":
        print(info.message);
        publicAddress = await FlutterKinSdk.createAccount();
        break;
      case "CreateAccountOnPlaygroundBlockchain":
        print(info.type + " Wallet: " + info.value);
        await FlutterKinSdk.getAccountState(publicAddress);
        break;
      case "DeleteAccount":
        print(info.message);
        break;
      case "GetAccountState":
        print(info.message);
        await FlutterKinSdk.getAccountBalance(publicAddress);
        break;
      case "GetAccountBalance":
        print(info.message + " Balance: " + info.value);
        await FlutterKinSdk.deleteAccount(publicAddress);
        break;
      case "SendTransaction":
        print(info.message + " Amount: " + info.value);
        break;
      case "SendWhitelistTransaction":
        print(info.message + " Amount: " + info.value);
        break;
      case "PaymentEvent":
        print(info.message + " Amount: " + info.value);
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
