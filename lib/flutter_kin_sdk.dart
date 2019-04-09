import 'dart:async';

import 'package:flutter/services.dart';

class FlutterKinSdk {
  static MethodChannel _methodChannel = MethodChannel('flutter_kin_sdk');

  static const _streamBalance = const EventChannel('flutter_kin_sdk_balance');
  static const _streamInfo = const EventChannel('flutter_kin_sdk_info');

  static EventChannel get balanceStream {
    return _streamBalance;
  }

  static EventChannel get infoStream {
    return _streamInfo;
  }

  static Future initKinClient(String appId,
      {bool isProduction = false, String serverUrl}) async {
    Map<String, dynamic> params = <String, dynamic>{
      'appId': appId,
      'isProduction': isProduction,
    };
    if (serverUrl != null) params.addAll({"serverUrl": serverUrl});
    await _methodChannel.invokeMethod('initKinClient', params);
  }

  static Future createAccount() async {
    // getting response by stream
    await _methodChannel.invokeMethod('createAccount');
  }

  static Future deleteAccount() async {
    // getting response by stream
    await _methodChannel.invokeMethod('deleteAccount');
  }

  static Future importAccount(String recoveryString, String secretPassphrase) async {
    Map<String, dynamic> params = <String, dynamic>{
      'recoveryString': recoveryString,
      'secretPassphrase': secretPassphrase,
    };
    // getting response by stream
    await _methodChannel.invokeMethod('importAccount', params);
  }

  static Future<String> exportAccount(String secretPassphrase) async {
    Map<String, dynamic> params = <String, dynamic>{
      'secretPassphrase': secretPassphrase,
    };
    return await _methodChannel.invokeMethod('importAccount', params);
  }

  static Future getAccountBalance() async {
    // getting response by stream
    await _methodChannel.invokeMethod('getAccountBalance');
  }

  static Future getAccountState() async {
    // getting response by stream
    await _methodChannel.invokeMethod('getAccountState');
  }

  static Future<String> getPublicAddress() async {
    return await _methodChannel.invokeMethod('getPublicAddress');
  }

  static Future sendTransaction(String toAddress, int kinAmount, String memo, int fee) async {
    Map<String, dynamic> params = <String, dynamic>{
      'toAddress': toAddress,
      'kinAmount': kinAmount,
      'memo': memo,
      'fee': fee,
    };
    // getting response by stream
    await _methodChannel.invokeMethod('sendTransaction', params);
  }

  static Future sendWhitelistTransaction(String whitelistServiceUrl, String toAddress, int kinAmount, String memo, int fee) async {
    Map<String, dynamic> params = <String, dynamic>{
      'whitelistServiceUrl': whitelistServiceUrl,
      'toAddress': toAddress,
      'kinAmount': kinAmount,
      'memo': memo,
      'fee': fee,
    };
    // getting response by stream
    await _methodChannel.invokeMethod('sendWhitelistTransaction', params);
  }

  static Future<String> fund(int kinAmount) async {
    // getting response by stream
    return await _methodChannel.invokeMethod('fund');
  }
}
