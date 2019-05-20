import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_kin_sdk/flutter_kin_sdk.dart';
import 'package:flutter_kin_sdk/utils/lib_utils.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  FlutterKinSdk flutterKinSdk;

  String firstPublicAddress;
  String secondPublicAddress;
  String recoveryString;
  int count = 0;

  @override
  void initState() {
    super.initState();

    FlutterKinSdk.infoStream.stream.listen((data) async {
      streamReceiver(data);
    }, onError: (error) {
      throw PlatformException(
          code: error.code, message: error.type, details: error.message);
    });

    FlutterKinSdk.balanceStream.stream
        .listen((BalanceReport balanceReport) async {
      if (balanceReport.publicAddress == firstPublicAddress) {
        print(balanceReport.amount);
      }
    });

    flutterKinSdk = FlutterKinSdk.playground("wBu7");
    flutterKinSdk.initKinClient();
  }

  void streamReceiver(Info info) async {
    switch (info.type) {
      case FlutterKinSDKConstans.INIT_KIN_CLIENT:
        print(info.message);
        firstPublicAddress = await flutterKinSdk.createAccount();
        secondPublicAddress = await flutterKinSdk.createAccount();
        break;
      case FlutterKinSDKConstans.CREATE_ACCOUNT_ON_PLAYGROUND_BLOCKCHAIN:
        print(info.type + " Wallet: " + info.value);
        count++;
        if (count > 1) {
          flutterKinSdk.sendTransaction(
              firstPublicAddress, secondPublicAddress, 10, "some", 1000);
        }
        break;
      case FlutterKinSDKConstans.DELETE_ACCOUNT:
        print(info.message);
        break;
      case FlutterKinSDKConstans.SEND_TRANSACTION:
        print(info.message + " Amount: " + info.value);
        flutterKinSdk.fund(firstPublicAddress, 30);
        break;
      case FlutterKinSDKConstans.SEND_WHITELIST_PLAYGROUND_TRANSACTION:
        print(info.message + " Amount: " + info.value);
        break;
      case FlutterKinSDKConstans.PAYMENT_EVENT:
        print(info.message + " Amount: " + info.value);
        print(await flutterKinSdk.getAccountBalance(firstPublicAddress));
        print(await flutterKinSdk.getAccountBalance(secondPublicAddress));
        break;
      case FlutterKinSDKConstans.FUND:
        print(info.message + " Amount: " + info.value);
        print(await flutterKinSdk.getAccountBalance(firstPublicAddress));
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text('Plugin example app'),
        ),
        body: Container(),
      ),
    );
  }
}
