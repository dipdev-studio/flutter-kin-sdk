# flutter_kin_sdk

A flutter Kin SDK plugin to create, import accounts and transferring Kin.

Unofficial Kin SDK plugin written in Dart for Flutter.

## Usage
To use this plugin, add `flutter_kin_sdk` as a [dependency in your pubspec.yaml file](https://flutter.io/platform-plugins/).


```yaml
dependencies:
  flutter_kin_sdk: '^0.2.1'
```

### Initializing

``` dart
import 'package:flutter_kin_sdk/flutter_kin_sdk.dart';

FlutterKinSdk.infoStream.stream.listen((data) async {
    streamReceiver(data);
}, onError: (error){
    throw PlatformException(code: error.code, message: error.type, details: error.message);
});

FlutterKinSdk.balanceStream.stream.listen((BalanceReport balanceReport) async {
    if (balanceReport.publicAddress == firstPublicAddress) {
        print(balanceReport.amount);
    }
});

//Insert your appId
FlutterKinSdk.initKinClient("some");
```

### Some methods inserted in reciever

``` dart
String firstPublicAddress;
String secondPublicAddress;
String recoveryString;
int count = 0;

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
          FlutterKinSdk.sendTransaction(firstPublicAddress, secondPublicAddress, 10, "some", 1000);
        }
        break;
      case FlutterKinSDKConstans.DELETE_ACCOUNT:
        print(info.message);
        break;
      case FlutterKinSDKConstans.SEND_TRANSACTION:
        print(info.message + " Amount: " + info.value);
        FlutterKinSdk.fund(firstPublicAddress, 30);
        break;
      case FlutterKinSDKConstans.SEND_WHITELIST_TRANSACTION:
        print(info.message + " Amount: " + info.value);
        break;
      case FlutterKinSDKConstans.PAYMENT_EVENT:
        print(info.message + " Amount: " + info.value);
        print(await FlutterKinSdk.getAccountBalance(firstPublicAddress));
        print(await FlutterKinSdk.getAccountBalance(secondPublicAddress));
        break;
      case FlutterKinSDKConstans.FUND:
        print(info.message + " Amount: " + info.value);
        print(await FlutterKinSdk.getAccountBalance(firstPublicAddress));
        break;
    }
  }
```

## Installation

### iOS

``` xml
<key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key>
        <true/>
        <key>NSExceptionDomains</key>
        <dict>
            <key>yourdomain.com</key>
            <dict>
                <key>NSIncludesSubdomains</key>
                <true/>
                <key>NSThirdPartyExceptionRequiresForwardSecrecy</key>
                <false/>
            </dict>
       </dict>
  </dict>
```