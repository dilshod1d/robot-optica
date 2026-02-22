import 'package:flutter/material.dart';
import 'package:telephony/telephony.dart';

class SmsProvider extends ChangeNotifier {
  final Telephony _telephony = Telephony.instance;

  bool _isSending = false;
  String? _lastStatus;
  String? _error;

  bool get isSending => _isSending;
  String? get lastStatus => _lastStatus;
  String? get error => _error;

  Future<bool> sendSms({
    required String phone,
    required String message,
  }) async {
    _isSending = true;
    _error = null;
    _lastStatus = null;
    notifyListeners();

    try {
      //  Only SMS permission (safe)
      final bool? granted = await _telephony.requestSmsPermissions;
      if (granted != true) {
        _error = "SMS permission not granted";
        _isSending = false;
        notifyListeners();
        return false;
      }

      //  NO subscriptionId (avoids carrier privilege crash)
      await _telephony.sendSms(
        to: phone,
        message: message,
      );

      _lastStatus = "Sent";
      _isSending = false;
      notifyListeners();
      return true;

    } catch (e) {
      _error = 'Error: $e';
      _lastStatus = "Failed";
      _isSending = false;
      notifyListeners();
      return false;
    }
  }
}



// import 'package:flutter/material.dart';
// import 'package:another_telephony/telephony.dart';
//
// class SmsProvider extends ChangeNotifier {
//   final Telephony _telephony = Telephony.instance;
//
//   bool _isSending = false;
//   String? _lastStatus;
//   String? _error;
//
//   bool get isSending => _isSending;
//   String? get lastStatus => _lastStatus;
//   String? get error => _error;
//
//   Future<bool> sendSms({required String phone, required String message}) async {
//     _isSending = true;
//     _error = null;
//     _lastStatus = null;
//     notifyListeners();
//
//     try {
//       final bool? permissionsGranted = await _telephony.requestPhoneAndSmsPermissions;
//       if (permissionsGranted != true) {
//         _error = "SMS permissions not granted";
//         _isSending = false;
//         notifyListeners();
//         return false;
//       }
//
//       await _telephony.sendSms(
//         to: phone,
//         message: message,
//         subscriptionId: 1,
//       );
//
//       _lastStatus = "Sent";
//       _isSending = false;
//       notifyListeners();
//       return true;
//
//     } catch (e) {
//       _error = 'Error: $e';
//       _lastStatus = "Failed";
//       _isSending = false;
//       notifyListeners();
//       return false;
//     }
//   }
// }
