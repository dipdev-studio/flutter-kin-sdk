import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_kin_sdk/utils/api.dart';
import 'utils/lib_utils.dart';

class FlutterKinSdk {
  Api api = Api();

  bool isProduction = false;

  String appId;

  FlutterKinSdk(this.isProduction, this.appId);

  static MethodChannel _methodChannel =
      MethodChannel(FlutterKinSDKConstans.FLUTTER_KIN_SDK);

  static const _streamBalance =
      const EventChannel(FlutterKinSDKConstans.FLUTTER_KIN_SDK_BALANCE);
  static const _streamInfo =
      const EventChannel(FlutterKinSDKConstans.FLUTTER_KIN_SDK_INFO);

  static StreamController<Info> _streamInfoController =
      new StreamController.broadcast();

  static StreamController<BalanceReport> _streamBalanceController =
      new StreamController.broadcast();

  void initStreams() {
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

  void initKinClient() async {
    initStreams();
    Map<String, dynamic> params = <String, dynamic>{
      'appId': appId,
      'isProduction': isProduction,
    };
    // getting response by stream
    await _methodChannel.invokeMethod(
        FlutterKinSDKConstans.INIT_KIN_CLIENT, params);
  }

  Future<String> createAccount(
      {String requestProductionUrl,
      int productionStartingBalance,
      String productionStartingMemo}) async {
    if (isProduction &&
        (requestProductionUrl == null || productionStartingBalance == null))
      return null;

    var publicAddress =
        await _methodChannel.invokeMethod(FlutterKinSDKConstans.CREATE_ACCOUNT);
    if (publicAddress == null) return null;

    if (isProduction) {
      var isSuccessful = await _createAccountOnProduction(
          publicAddress,
          requestProductionUrl,
          productionStartingBalance,
          productionStartingMemo);
      if (!isSuccessful) return null;
    }
    // public address will be returned
    return publicAddress;
  }

  Future<bool> _createAccountOnProduction(String publicAddress,
      String requestUrl, int startingBalance, String memo) async {
    var isSuccessfulRequest = false;

    Map<String, dynamic> requestJson = <String, dynamic>{
      'destination': publicAddress,
      'starting_balance': startingBalance,
      'memo': memo,
    };

    await api.postRequest(requestUrl, requestJson).then((response) {
      if (response.statusCode == 200) {
        isSuccessfulRequest = true;
      } else {
        _sendError(response.body, "-17",
            FlutterKinSDKConstans.CREATE_ACCOUNT_ON_PRODUCTION_BLOCKCHAIN);
        deleteAccount(publicAddress);
      }
    });
    return isSuccessfulRequest;
  }

  void deleteAccount(String publicAddress) async {
    Map<String, dynamic> params = <String, dynamic>{
      'publicAddress': publicAddress,
    };
    // getting response by stream
    await _methodChannel.invokeMethod(
        FlutterKinSDKConstans.DELETE_ACCOUNT, params);
  }

  Future<String> importAccount(
      String recoveryString, String secretPassphrase) async {
    Map<String, dynamic> params = <String, dynamic>{
      'recoveryString': recoveryString,
      'secretPassphrase': secretPassphrase,
    };
    // public address will be returned
    return await _methodChannel.invokeMethod(
        FlutterKinSDKConstans.IMPORT_ACCOUNT, params);
  }

  Future<String> exportAccount(
      String publicAddress, String secretPassphrase) async {
    Map<String, dynamic> params = <String, dynamic>{
      'publicAddress': publicAddress,
      'secretPassphrase': secretPassphrase,
    };
    return await _methodChannel.invokeMethod(
        FlutterKinSDKConstans.EXPORT_ACCOUNT, params);
  }

  Future<int> getAccountBalance(String publicAddress,
      {String requestProductionUrl}) async {
    int balance = 0;
    if (isProduction) {
      await api
          .getRequest(requestProductionUrl + "/" + publicAddress)
          .then((response) {
        if (response.statusCode == 200)
          balance = json.decode(response.body)['balance'];
        else
          _sendError(
              response.body, "-6", FlutterKinSDKConstans.GET_ACCOUNT_BALANCE);
      });
    } else {
      Map<String, dynamic> params = <String, dynamic>{
        'publicAddress': publicAddress,
      };
      balance = await _methodChannel.invokeMethod(
          FlutterKinSDKConstans.GET_ACCOUNT_BALANCE, params);
    }

    return balance;
  }

  Future<AccountStates> getAccountState(String publicAddress) async {
    Map<String, dynamic> params = <String, dynamic>{
      'publicAddress': publicAddress,
    };

    var state = await _methodChannel.invokeMethod(
        FlutterKinSDKConstans.GET_ACCOUNT_STATE, params);

    if (state == "Account is created") return AccountStates.Created;
    return AccountStates.NotCreated;
  }

  void sendTransaction(String publicAddress, String toAddress, int kinAmount,
      String memo, int fee) async {
    Map<String, dynamic> params = <String, dynamic>{
      'publicAddress': publicAddress,
      'toAddress': toAddress,
      'kinAmount': kinAmount,
      'memo': memo,
      'fee': fee,
    };
    // getting response by stream
    await _methodChannel.invokeMethod(
        FlutterKinSDKConstans.SEND_TRANSACTION, params);
  }

  void sendWhitelistTransaction(
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
    await _methodChannel.invokeMethod(
        FlutterKinSDKConstans.SEND_WHITELIST_TRANSACTION, params);
  }

  Future fund(String publicAddress, int kinAmount,
      {String requestProductionUrl, String requestProductionMemo}) async {
    if (isProduction) {
      Map<String, dynamic> params = <String, dynamic>{
        'destination': publicAddress,
        'amount': kinAmount,
        'memo': requestProductionMemo,
      };

      await api.postRequest(requestProductionUrl, params).then((response) {
        if (response.statusCode == 200) {
          Info info = Info(FlutterKinSDKConstans.FUND,
              "Fund successful to $publicAddress", kinAmount.toString());
          _streamInfoController.add(info);
        } else {
          _sendError(response.body, "-16", FlutterKinSDKConstans.FUND);
        }
      });
    } else {
      Map<String, dynamic> params = <String, dynamic>{
        'publicAddress': publicAddress,
        'kinAmount': kinAmount,
      };
      // getting response by stream
      await _methodChannel.invokeMethod(FlutterKinSDKConstans.FUND, params);
    }
  }

  void _sendError(
      String responseStringJson, String errorCode, String errorType) {
    var responseJson = json.decode(responseStringJson);
    String details = "";
    if (responseJson['details'] is List) {
      for (String detail in responseJson['details']) {
        details += detail + " ";
      }
    } else {
      details = responseJson['details'];
    }

    Error error = Error(errorType, details);
    error.code = errorCode;
    _streamInfoController.addError(error);
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
  static const String CREATE_ACCOUNT_ON_PLAYGROUND_BLOCKCHAIN =
      'CreateAccountOnPlaygroundBlockchain';
  static const String CREATE_ACCOUNT_ON_PRODUCTION_BLOCKCHAIN =
      'CreateAccountOnProductionBlockchain';
  static const String PAYMENT_EVENT = 'PaymentEvent';
  static const String ACCOUNT_STATE_CHECK = 'AccountStateCheck';
  static const String SEND_INFO_JSON = "SendInfoJson";
  static const String SEND_BALANCE_JSON = "SendBalanceJson";
  static const String SEND_ERROR_JSON = "SendErrorJson";
}
