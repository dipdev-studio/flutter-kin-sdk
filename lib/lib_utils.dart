class Info {
  String type;
  String message;
  String value;

  Info.fromJson(Map<dynamic, dynamic> raw) {
    Map<String, dynamic> json = Map<String, dynamic>.from(raw);

    if (json['type'] != null) type = json['type'];

    if (json['message'] != null) message = json['message'];

    if (json['value'] != null) value = json['value'];
  }
}

class Error {
  String code;
  String message;
  Info details;

  Error(this.code, this.message, this.details);

  Error.fromJson(Map<dynamic, dynamic> raw) {
    Map<String, dynamic> json = Map<String, dynamic>.from(raw);

    if (json['code'] != null) code = json['code'];

    if (json['message'] != null) message = json['message'];

    if (json['details'] != null) details = json['details'];
  }
}

class BalanceReport {
  String publicAddress;
  int amount;

  BalanceReport.fromJson(Map<dynamic, dynamic> raw) {
    Map<String, dynamic> json = Map<String, dynamic>.from(raw);

    if (json['publicAddress'] != null) publicAddress = json['publicAddress'];

    if (json['amount'] != null) amount = json['amount'];
  }
}
