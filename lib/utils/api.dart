import 'dart:async';

import 'package:http/http.dart' as http;

class Api {
  Future<http.Response> postRequest(url, data) async {
    return await http
        .post(url, body: data, headers: {"Content-Type": "application/json"});
  }

  Future<http.Response> getRequest(url) async {
    return await http.get(url);
  }
}
