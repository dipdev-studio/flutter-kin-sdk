import 'dart:async';

import 'package:flutter/services.dart';

class FlutterKinSdk {
  static const MethodChannel _channel =
      const MethodChannel('flutter_kin_sdk');

  static Future<String> get platformVersion async {
    final String version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }

  static Future kinStart(String token) async {
    final Map<String, dynamic> params = <String, dynamic>{
      'token': token,
    };
    await _channel.invokeMethod('kinStart', params);
  }

  static Future launchKinMarket() async {
    await _channel.invokeMethod('launchKinMarket');
  }
}