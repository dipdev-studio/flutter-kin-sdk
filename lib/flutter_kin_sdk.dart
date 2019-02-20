import 'dart:async';

import 'package:flutter/services.dart';

class FlutterKinSdk {
  static MethodChannel _methodChannel = MethodChannel('flutter_kin_sdk');

  static const _stream = const EventChannel('flutter_kin_sdk_balance');
  static const _streamInfo = const EventChannel('flutter_kin_sdk_info');

  static EventChannel get balanceStream {
    return _stream;
  }

  static EventChannel get infoStream {
    return _streamInfo;
  }

  static Future kinInit({int accountNum = 0, bool isTest = false}) async {
    final Map<String, dynamic> params = <String, dynamic>{
      'isTest': isTest,
      'accountNum': accountNum,
    };
    await _methodChannel.invokeMethod('kinInit', params);
  }

  static Future getPublicAddress({int accountNum = 0}) async {
    final Map<String, dynamic> params = <String, dynamic>{
      'accountNum': accountNum,
    };
    await _methodChannel.invokeMethod('getPublicAddress', params);
  }

  static Future kinTransfer(String toAccountAddress, int amount, {int fromAccount = 0, String memo}) async {
    final Map<String, dynamic> params = <String, dynamic>{
      'fromAccount': fromAccount,
      'toAccountAddress': toAccountAddress,
      'amount': amount,
      'memo': memo,
    };
    await _methodChannel.invokeMethod('kinTransfer', params);
  }

  static Future kinTransferToYourself(int fromAccount, int toAccount, int amount, {String memo}) async {
    final Map<String, dynamic> params = <String, dynamic>{
      'fromAccount': fromAccount,
      'toAccount': toAccount,
      'amount': amount,
      'memo': memo,
    };
    await _methodChannel.invokeMethod('kinTransferToYourself', params);
  }

  static Future accountStateCheck(int accountNum) async {
    final Map<String, dynamic> params = <String, dynamic>{
      'accountNum': accountNum,
    };
    await _methodChannel.invokeMethod('accountStateCheck', params);
  }
}
