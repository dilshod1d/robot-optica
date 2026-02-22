import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';

Future<bool> checkOnline() async {
  final List<ConnectivityResult> connectivityResult = await Connectivity().checkConnectivity();

  // Check if mobile or wifi is among active connections
  if (connectivityResult.contains(ConnectivityResult.mobile) ||
      connectivityResult.contains(ConnectivityResult.wifi)) {
    try {
      final result = await InternetAddress.lookup('example.com');

      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {

        return true;
      } else {
        print('DNS lookup returned empty result');
        return false;
      }
    } on SocketException catch (e) {
      print('SocketException during DNS lookup: $e');
      return false;
    }
  } else {
    print('No mobile or wifi connection found in: $connectivityResult');
    return false;
  }
}
