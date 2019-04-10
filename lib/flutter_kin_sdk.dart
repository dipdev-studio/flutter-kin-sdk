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
    // getting response by stream
    await _methodChannel.invokeMethod('initKinClient', params);
  }

  static Future<String> createAccount() async {
    // public address will be returned
    return await _methodChannel.invokeMethod('createAccount');
  }

  static Future deleteAccount(String publicAddress) async {
    Map<String, dynamic> params = <String, dynamic>{
      'publicAddress': publicAddress,
    };
    // getting response by stream
    await _methodChannel.invokeMethod('deleteAccount', params);
  }

  static Future<String> importAccount(
      String recoveryString, String secretPassphrase) async {
    Map<String, dynamic> params = <String, dynamic>{
      'recoveryString': recoveryString,
      'secretPassphrase': secretPassphrase,
    };
    // public address will be returned
    return await _methodChannel.invokeMethod('importAccount', params);
  }

  static Future<String> exportAccount(String secretPassphrase) async {
    Map<String, dynamic> params = <String, dynamic>{
      'secretPassphrase': secretPassphrase,
    };
    return await _methodChannel.invokeMethod('importAccount', params);
  }

  static Future getAccountBalance(String publicAddress) async {
    Map<String, dynamic> params = <String, dynamic>{
      'publicAddress': publicAddress,
    };
    // getting response by stream
    await _methodChannel.invokeMethod('getAccountBalance', params);
  }

  static Future getAccountState(String publicAddress) async {
    Map<String, dynamic> params = <String, dynamic>{
      'publicAddress': publicAddress,
    };
    // getting response by stream
    await _methodChannel.invokeMethod('getAccountState', params);
  }

  static Future sendTransaction(String publicAddress, String toAddress,
      int kinAmount, String memo, int fee) async {
    Map<String, dynamic> params = <String, dynamic>{
      'publicAddress': publicAddress,
      'toAddress': toAddress,
      'kinAmount': kinAmount,
      'memo': memo,
      'fee': fee,
    };
    // getting response by stream
    await _methodChannel.invokeMethod('sendTransaction', params);
  }

  static Future sendWhitelistTransaction(
      String publicAddress,
      String whitelistServiceUrl,
      String toAddress,
      int kinAmount,
      String memo,
      int fee) async {
    Map<String, dynamic> params = <String, dynamic>{
      'publicAddress': publicAddress,
      'whitelistServiceUrl': whitelistServiceUrl,
      'toAddress': toAddress,
      'kinAmount': kinAmount,
      'memo': memo,
      'fee': fee,
    };
    // getting response by stream
    await _methodChannel.invokeMethod('sendWhitelistTransaction', params);
  }

  static Future<String> fund(String publicAddress, int kinAmount) async {
    Map<String, dynamic> params = <String, dynamic>{
      'publicAddress': publicAddress,
      'kinAmount': kinAmount,
    };
    // getting response by stream
    return await _methodChannel.invokeMethod('fund');
  }
}
