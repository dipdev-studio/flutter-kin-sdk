class Info {
  String type;
  String message;
  int amount;

  Info();

  Info.params(this.type, this.message, this.amount);

  Info.fromJson(Map<String, dynamic> json)
      : type = json['type'],
        message = json['message'],
        amount = json['amount'];
}

class Error {
  String code;
  String message;
  Info details;

  Error(this.code, this.message, this.details);
}
