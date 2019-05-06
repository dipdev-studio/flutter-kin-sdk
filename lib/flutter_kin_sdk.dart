import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

import 'lib_utils.dart';

class FlutterKinSdk {
  static MethodChannel _methodChannel = MethodChannel(FlutterKinSDKConstans.FLUTTER_KIN_SDK);

  static const _streamBalance = const EventChannel(FlutterKinSDKConstans.FLUTTER_KIN_SDK_BALANCE);
  static const _streamInfo = const EventChannel(FlutterKinSDKConstans.FLUTTER_KIN_SDK_INFO);

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
      err.code = error.code;
      _streamInfoController.addError(err);
    });

    _streamBalance.receiveBroadcastStream().listen((data) {
      _streamBalanceController.add(BalanceReport.fromJson(json.decode(data)));
    }, onError: (error) {
      Error err = Error.fromJson(json.decode(error.details));
      err.code = error.code;
      _streamBalanceController.addError(err);
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
    await _methodChannel.invokeMethod(FlutterKinSDKConstans.INIT_KIN_CLIENT, params);
  }

  static Future<String> createAccount() async {
    // public address will be returned
    return await _methodChannel.invokeMethod(FlutterKinSDKConstans.CREATE_ACCOUNT);
  }

  static void deleteAccount(String publicAddress) async {
    Map<String, dynamic> params = <String, dynamic>{
      'publicAddress': publicAddress,
    };
    // getting response by stream
    await _methodChannel.invokeMethod(FlutterKinSDKConstans.DELETE_ACCOUNT, params);
  }

  static Future<String> importAccount(
      String recoveryString, String secretPassphrase) async {
    Map<String, dynamic> params = <String, dynamic>{
      'recoveryString': recoveryString,
      'secretPassphrase': secretPassphrase,
    };
    // public address will be returned
    return await _methodChannel.invokeMethod(FlutterKinSDKConstans.IMPORT_ACCOUNT, params);
  }

  static Future<String> exportAccount(
      String publicAddress, String secretPassphrase) async {
    Map<String, dynamic> params = <String, dynamic>{
      'publicAddress': publicAddress,
      'secretPassphrase': secretPassphrase,
    };
    return await _methodChannel.invokeMethod(FlutterKinSDKConstans.EXPORT_ACCOUNT, params);
  }

  static Future<int> getAccountBalance(String publicAddress) async {
    Map<String, dynamic> params = <String, dynamic>{
      'publicAddress': publicAddress,
    };

    return await _methodChannel.invokeMethod(FlutterKinSDKConstans.GET_ACCOUNT_BALANCE, params);
  }

  static Future<AccountStates> getAccountState(String publicAddress) async {
    Map<String, dynamic> params = <String, dynamic>{
      'publicAddress': publicAddress,
    };

    var state = await _methodChannel.invokeMethod(FlutterKinSDKConstans.GET_ACCOUNT_STATE, params);

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
    await _methodChannel.invokeMethod(FlutterKinSDKConstans.SEND_TRANSACTION, params);
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
    await _methodChannel.invokeMethod(FlutterKinSDKConstans.SEND_WHITELIST_TRANSACTION, params);
  }

  static Future<String> fund(String publicAddress, int kinAmount) async {
    Map<String, dynamic> params = <String, dynamic>{
      'publicAddress': publicAddress,
      'kinAmount': kinAmount,
    };
    // getting response by stream
    return await _methodChannel.invokeMethod(FlutterKinSDKConstans.FUND, params);
  }
}

enum AccountStates { Created, NotCreated }

class FlutterKinSDKConstans {
  static const String FLUTTER_KIN_SDK = 'flutter_kin_sdk';
  static const String FLUTTER_KIN_SDK_BALANCE = 'flutter_kin_sdk_balance';
  static const String FLUTTER_KIN_SDK_INFO = 'flutter_kin_sdk_info';
  static const String INIT_KIN_CLIENT = 'InitKinClient';
  static const String CREATE_ACCOUNT = 'CreateAccount';
  static const String DELETE_ACCOUNT = 'DeleteAccount';
  static const String IMPORT_ACCOUNT = 'ImportAccount';
  static const String EXPORT_ACCOUNT = 'ExportAccount';
  static const String GET_ACCOUNT_BALANCE = 'GetAccountBalance';
  static const String GET_ACCOUNT_STATE = 'GetAccountState';
  static const String SEND_TRANSACTION = 'SendTransaction';
  static const String SEND_WHITELIST_TRANSACTION = 'SendWhitelistTransaction';
  static const String FUND = 'Fund';
  static const String CREATE_ACCOUNT_ON_PLAYGROUND_BLOCKCHAIN = 'CreateAccountOnPlaygroundBlockchain';
  static const String PAYMENT_EVENT = 'PaymentEvent';
  static const String ACCOUNT_STATE_CHECK = 'AccountStateCheck';
  static const String SEND_INFO_JSON = "SendInfoJson";
  static const String SEND_BALANCE_JSON = "SendBalanceJson";
  static const String SEND_ERROR_JSON = "SendErrorJson";
}
