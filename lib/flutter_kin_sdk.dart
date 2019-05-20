import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_kin_sdk/utils/api.dart';
import 'utils/lib_utils.dart';

class FlutterKinSdk {
  //TODO
  //send whitelist playground transaction iOS
  //send whitelist playground transaction Android
  //send production transaction iOS
  //send whitelist production transaction iOS
  //send whitelist production transaction Android

  Api api = Api();

  bool _isProduction;
  String _appId;
  String _productionBalaceUrl;

  FlutterKinSdk.playground(this._appId) {
    _isProduction = false;
  }

  FlutterKinSdk.production(this._appId, this._productionBalaceUrl) {
    _isProduction = true;
  }

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
      _checkAccountBalanceEvents(info);
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
      'appId': _appId,
      'isProduction': _isProduction,
    };
    // getting response by stream
    await _methodChannel.invokeMethod(
        FlutterKinSDKConstans.INIT_KIN_CLIENT, params);
  }

  Future<String> createAccount(
      {String requestProductionUrl,
      int productionStartingBalance,
      String productionStartingMemo}) async {
    if (_isProduction &&
        (requestProductionUrl == null || productionStartingBalance == null))
      return null;

    var publicAddress =
        await _methodChannel.invokeMethod(FlutterKinSDKConstans.CREATE_ACCOUNT);
    if (publicAddress == null) return null;

    if (_isProduction) {
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

    await api
        .postRequest(requestUrl, json.encode(requestJson))
        .then((response) {
      if (response.statusCode == 200) {
        isSuccessfulRequest = true;
      } else {
        _sendError(response.body, "-17",
            FlutterKinSDKConstans.CREATE_ACCOUNT_ON_PRODUCTION_BLOCKCHAIN);
        deleteAccount(publicAddress);
      }
    });

    if (isSuccessfulRequest) {
      Map<String, dynamic> params = <String, dynamic>{
        'publicAddress': publicAddress,
      };

      _methodChannel.invokeMethod(
          FlutterKinSDKConstans.RECEIVE_PRODUCTION_PAYMENTS_AND_BALANCE,
          params);
      _checkAccountBalance(publicAddress);
    }
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

  Future<int> getAccountBalance(String publicAddress) async {
    double balance = 0;
    if (_isProduction) {
      await api
          .getRequest(_productionBalaceUrl + "/" + publicAddress)
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

    return balance.toInt();
  }

  void _checkAccountBalance(String publicAddress) async {
    int currentBalance = await getAccountBalance(publicAddress);
    _streamBalanceController.add(BalanceReport(publicAddress, currentBalance));
  }

  void _checkAccountBalanceEvents(Info info) async {
    if (info.type == FlutterKinSDKConstans.SEND_TRANSACTION ||
        info.type == FlutterKinSDKConstans.PAYMENT_EVENT) {
      int currentBalance = await getAccountBalance(info.message);
      _streamBalanceController.add(BalanceReport(info.message, currentBalance));
    }
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
    _methodChannel.invokeMethod(FlutterKinSDKConstans.SEND_TRANSACTION, params);
  }

  void sendWhitelistTransaction(
      String publicAddress,
      String whitelistServiceUrl,
      String toAddress,
      int kinAmount,
      String memo,
      int fee,
      {String productionNetworkId}) async {
    Map<String, dynamic> params = <String, dynamic>{
      'publicAddress': publicAddress,
      'whitelistServiceUrl': whitelistServiceUrl,
      'toAddress': toAddress,
      'kinAmount': kinAmount,
      'memo': memo,
      'fee': fee,
    };

    if (_isProduction) {
      if (productionNetworkId == null) return;
      sendWhitelistProductionTransaction(
          params, whitelistServiceUrl, productionNetworkId);
    } else {
      // getting response by stream
      _methodChannel.invokeMethod(
          FlutterKinSDKConstans.SEND_WHITELIST_PLAYGROUND_TRANSACTION, params);
    }
  }

  void sendWhitelistProductionTransaction(Map<String, dynamic> params,
      String whitelistServiceUrl, String productionNetworkId) async {
    String everlope = await _methodChannel.invokeMethod(
        FlutterKinSDKConstans.SEND_WHITELIST_PRODUCTION_TRANSACTION, params);

    Map<String, dynamic> serverParams = <String, dynamic>{
      'envelope': everlope,
      'network_id': productionNetworkId,
    };

    await api
        .postRequest(whitelistServiceUrl, json.encode(serverParams))
        .then((response) {
      if (response.statusCode == 200) {
        Info info = Info(
            FlutterKinSDKConstans.FUND,
            "Payment was successful from ${params['publicAddress']} to ${params['toAddress']}",
            params['kinAmount'].toString());
        _streamInfoController.add(info);
        _checkAccountBalance(params['publicAddress']);
      } else {
        _sendError(response.body, "-11",
            FlutterKinSDKConstans.SEND_WHITELIST_PRODUCTION_TRANSACTION);
      }
    });
  }

  Future fund(String publicAddress, int kinAmount,
      {String requestProductionUrl, String requestProductionMemo}) async {
    if (_isProduction) {
      Map<String, dynamic> params = <String, dynamic>{
        'destination': publicAddress,
        'amount': kinAmount,
        'memo': requestProductionMemo,
      };

      await api
          .postRequest(requestProductionUrl, json.encode(params))
          .then((response) {
        if (response.statusCode == 200) {
          Info info = Info(FlutterKinSDKConstans.FUND,
              "Fund successful to $publicAddress", kinAmount.toString());
          _streamInfoController.add(info);
          _checkAccountBalance(publicAddress);
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
  static const String SEND_WHITELIST_PRODUCTION_TRANSACTION =
      'SendWhitelistProductionTransaction';
  static const String SEND_WHITELIST_PLAYGROUND_TRANSACTION =
      'SendWhitelistPlaygroundTransaction';
  static const String FUND = 'Fund';
  static const String CREATE_ACCOUNT_ON_PLAYGROUND_BLOCKCHAIN =
      'CreateAccountOnPlaygroundBlockchain';
  static const String CREATE_ACCOUNT_ON_PRODUCTION_BLOCKCHAIN =
      'CreateAccountOnProductionBlockchain';
  static const String RECEIVE_PRODUCTION_PAYMENTS_AND_BALANCE =
      'ReceiveProductionPaymentsAndBalance';
  static const String PAYMENT_EVENT = 'PaymentEvent';
  static const String ACCOUNT_STATE_CHECK = 'AccountStateCheck';
  static const String SEND_INFO_JSON = "SendInfoJson";
  static const String SEND_BALANCE_JSON = "SendBalanceJson";
  static const String SEND_ERROR_JSON = "SendErrorJson";
}
