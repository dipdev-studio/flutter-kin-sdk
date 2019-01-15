import 'dart:async';

import 'package:flutter/services.dart';

class FlutterKinSdk {
static MethodChannel _methodChannel = MethodChannel('flutter_kin_sdk');

  static const _stream = const EventChannel('flutter_kin_sdk_balance');
  static const _streamInfo = const EventChannel('flutter_kin_sdk_info');

  static Future<String> get platformVersion async {
    final String version = await _methodChannel.invokeMethod('getPlatformVersion');
    return version;
  }

  static EventChannel get balanceStream{
    return _stream;
  }

  static EventChannel get infoStream{
    return _streamInfo;
  }

  static Future kinStart(String token, balanceObserver) async {
    final Map<String, dynamic> params = <String, dynamic>{
      'token': token,
    };
    await _methodChannel.invokeMethod('kinStart', params);
  }

  static Future launchKinMarket() async {
    await _methodChannel.invokeMethod('launchKinMarket');
  }

  static Future kinEarn(String jwt) async {
    final Map<String, dynamic> params = <String, dynamic>{
      'jwt': jwt,
    };
    await _methodChannel.invokeMethod('kinEarn', params);
  }

  static Future kinSpend(String jwt) async {
    final Map<String, dynamic> params = <String, dynamic>{
      'jwt': jwt,
    };
    await _methodChannel.invokeMethod('kinSpend', params);
  }

  static Future kinPayToUser(String jwt) async {
    final Map<String, dynamic> params = <String, dynamic>{
      'jwt': jwt,
    };
    await _methodChannel.invokeMethod('kinPayToUser', params);
  }

  static Future orderConfirmation(String offerId) async {
    final Map<String, dynamic> params = <String, dynamic>{
    'offerId': offerId,
    };
    await _methodChannel.invokeMethod('orderConfirmation', params);
  }
}