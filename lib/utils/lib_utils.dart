class Info {
  String type;
  String message;
  String value;

  Info(this.type, this.message, this.value);

  Info.fromJson(Map<dynamic, dynamic> raw) {
    Map<String, dynamic> json = Map<String, dynamic>.from(raw);

    if (json['type'] != null) type = json['type'];

    if (json['message'] != null) message = json['message'];

    if (json['value'] != null) value = json['value'];
  }
}

class Error {
  String code;
  String type;
  String message;

  Error(this.type, this.message);

  Error.fromJson(Map<dynamic, dynamic> raw) {
    Map<String, dynamic> json = Map<String, dynamic>.from(raw);

    if (json['type'] != null) type = json['type'];

    if (json['message'] != null) message = json['message'];
  }
}

class BalanceReport {
  String publicAddress;
  int amount;

  BalanceReport(this.publicAddress, this.amount);

  BalanceReport.fromJson(Map<dynamic, dynamic> raw) {
    Map<String, dynamic> json = Map<String, dynamic>.from(raw);

    if (json['publicAddress'] != null) publicAddress = json['publicAddress'];

    if (json['amount'] != null) amount = json['amount'];
  }
}
