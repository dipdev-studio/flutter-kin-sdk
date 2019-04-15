import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

import 'lib_utils.dart';

class FlutterKinSdk {
  static MethodChannel _methodChannel = MethodChannel('flutter_kin_sdk');

  static const _streamBalance = const EventChannel('flutter_kin_sdk_balance');
  static const _streamInfo = const EventChannel('flutter_kin_sdk_info');

  static StreamController<Info> _streamInfoController =
      new StreamController.broadcast();

  static StreamController<BalanceReport> _streamBalanceController =
      new StreamController.broadcast();

  static initStreams() {
    _streamInfo.receiveBroadcastStream().listen((data) {
      Info info = Info.fromJson(json.decode(data));
      _streamInfoController.add(info);
    }, onError: (error) {
      Error err = Error.fromJson(json.decode(error.details));
      throw PlatformException(code: error.code, message: error.message, details: err);
    });

    _streamBalance.receiveBroadcastStream().listen((data) {
      _streamBalanceController.add(BalanceReport.fromJson(json.decode(data)));
    }, onError: (error) {
      throw error;
    });
  }

  static StreamController<BalanceReport> get balanceStream {
    return _streamBalanceController;
  }

  static StreamController<Info> get infoStream {
    return _streamInfoController;
  }

  static void initKinClient(String appId,
      {bool isProduction = false, String serverUrl}) async {
    initStreams();
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

  static void deleteAccount(String publicAddress) async {
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

  static Future<String> exportAccount(
      String publicAddress, String secretPassphrase) async {
    Map<String, dynamic> params = <String, dynamic>{
      'publicAddress': publicAddress,
      'secretPassphrase': secretPassphrase,
    };
    return await _methodChannel.invokeMethod('exportAccount', params);
  }

  static Future<int> getAccountBalance(String publicAddress) async {
    Map<String, dynamic> params = <String, dynamic>{
      'publicAddress': publicAddress,
    };

    return await _methodChannel.invokeMethod('getAccountBalance', params);
  }

  static Future<AccountStates> getAccountState(String publicAddress) async {
    Map<String, dynamic> params = <String, dynamic>{
      'publicAddress': publicAddress,
    };

    var state = await _methodChannel.invokeMethod('getAccountState', params);

    if (state == "Account is created") return AccountStates.Created;
    return AccountStates.NotCreated;
  }

  static void sendTransaction(String publicAddress, String toAddress,
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

  static void sendWhitelistTransaction(
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

  static Future<String> earn(String publicAddress, int kinAmount) async {
    Map<String, dynamic> params = <String, dynamic>{
      'publicAddress': publicAddress,
      'kinAmount': kinAmount,
    };
    // getting response by stream
    return await _methodChannel.invokeMethod('earn');
  }
}

enum AccountStates { Created, NotCreated }
