# flutter_kin_sdk

A flutter Kin SDK plugin to use offers features and launch Kin Marketplace.

Unofficial Kin SDK plugin written in Dart for Flutter.

## Usage
To use this plugin, add `flutter_kin_sdk` as a [dependency in your pubspec.yaml file](https://flutter.io/platform-plugins/).


```yaml
dependencies:
  flutter_kin_sdk: '^0.1.2'
```

### Initializing

``` dart
import 'package:flutter_kin_sdk/flutter_kin_sdk.dart';

// Generate jwt_token and all jwt by yourself and setting in the plugin to have a response
// true - initializing balance observer
// true - production mode (false - playground)
await FlutterKinSdk.kinStart(jwt_token, true, true);
```

### Receivers

To receive some changes in plugin you can use such ones:

``` dart
// Receive balance scream and get all balance changes
FlutterKinSdk.balanceStream.receiveBroadcastStream().listen((balance) {
    print(balance);
});

// Receive all info and error messages from plugin
FlutterKinSdk.infoStream.receiveBroadcastStream().listen((jsonStr) {
    print(jsonStr);
});
```

### Some methods

``` dart
// A custom Earn offer allows your users to earn Kin
// as a reward for performing tasks you want to incentives,
// such as setting a profile picture or rating your app
FlutterKinSdk.kinEarn(jwt);

// A custom Spend offer allows your users to unlock unique spend opportunities
// that you define within your app
FlutterKinSdk.kinSpend(jwt);

// A custom pay to user offer allows your users to unlock
// unique spend opportunities that you define
// within your app offered by other users
FlutterKinSdk.kinPayToUser(jwt);
```

## Installation


### Android and iOS

No configuration required - the plugin should work out of the box.