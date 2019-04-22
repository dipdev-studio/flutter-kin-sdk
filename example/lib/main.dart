import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_kin_sdk/flutter_kin_sdk.dart';
import 'package:flutter_kin_sdk/lib_utils.dart';

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
  void initPlatformState() async {
    FlutterKinSdk.infoStream.stream.listen((data) async {
      streamReceiver(data);
    }, onError: (error){
      throw PlatformException(code: error.code, message: error.type, details: error.message);
    });

    FlutterKinSdk.balanceStream.stream.listen(
        (BalanceReport balanceReport) async {
      if (balanceReport.publicAddress == firstPublicAddress) {
        print(balanceReport.amount);
      }
    });

    FlutterKinSdk.initKinClient("wBu7");
  }

  void streamReceiver(Info info) async {
    switch (info.type) {
      case FlutterKinSDKConstans.INIT_KIN_CLIENT:
        print(info.message);
        firstPublicAddress = await FlutterKinSdk.createAccount();
        secondPublicAddress = await FlutterKinSdk.createAccount();
        break;
      case FlutterKinSDKConstans.CREATE_ACCOUNT_ON_PLAYGROUND_BLOCKCHAIN:
        print(info.type + " Wallet: " + info.value);
        count++;
        if (count > 1){
          FlutterKinSdk.sendTransaction(firstPublicAddress, secondPublicAddress, 100, "some", 1000);
        }
        break;
      case FlutterKinSDKConstans.DELETE_ACCOUNT:
        print(info.message);
        break;
      case FlutterKinSDKConstans.SEND_TRANSACTION:
        print(info.message + " Amount: " + info.value);
        break;
      case FlutterKinSDKConstans.SEND_WHITELIST_TRANSACTION:
        print(info.message + " Amount: " + info.value);
        break;
      case FlutterKinSDKConstans.PAYMENT_EVENT:
        print(info.message + " Amount: " + info.value);
        print(await FlutterKinSdk.getAccountBalance(firstPublicAddress));
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
