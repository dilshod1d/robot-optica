import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../widgets/common/app_loader.dart';

class BarcodeScannerScreen extends StatefulWidget {
  final String title;
  final String hint;

  const BarcodeScannerScreen({
    super.key,
    this.title = "Shtrix-kodni skanerlash",
    this.hint = "Kamerani shtrix-kodga yo'naltiring",
  });

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _found = false;
  bool _checkingPermission = true;
  bool _hasPermission = false;
  bool _permanentlyDenied = false;

  @override
  void initState() {
    super.initState();
    _ensurePermission();
  }

  Future<void> _ensurePermission() async {
    final status = await Permission.camera.status;
    if (status.isGranted) {
      if (!mounted) return;
      setState(() {
        _hasPermission = true;
        _checkingPermission = false;
        _permanentlyDenied = false;
      });
      return;
    }

    if (status.isPermanentlyDenied) {
      if (!mounted) return;
      setState(() {
        _hasPermission = false;
        _checkingPermission = false;
        _permanentlyDenied = true;
      });
      return;
    }

    final request = await Permission.camera.request();
    if (!mounted) return;
    setState(() {
      _hasPermission = request.isGranted;
      _checkingPermission = false;
      _permanentlyDenied = request.isPermanentlyDenied;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_found) return;
    String? value;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw != null && raw.trim().isNotEmpty) {
        value = raw.trim();
        break;
      }
    }
    if (value == null || value.trim().isEmpty) return;

    _found = true;
    _controller.stop();
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: _hasPermission ? () => _controller.toggleTorch() : null,
          ),
        ],
      ),
      body: _checkingPermission
          ? const Center(child: AppLoader())
          : !_hasPermission
              ? _permissionView()
              : Stack(
                  children: [
                    MobileScanner(
                      controller: _controller,
                      onDetect: _onDetect,
                    ),
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 24,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          widget.hint,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _permissionView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.camera_alt_outlined, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            const Text(
              "Kameraga ruxsat kerak",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            const Text(
              "QR yoki shtrix-kodni skanerlash uchun kameraga ruxsat bering.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final permanentlyDenied =
                      await Permission.camera.isPermanentlyDenied;
                  if (permanentlyDenied) {
                    await openAppSettings();
                    await _ensurePermission();
                  } else {
                    setState(() => _checkingPermission = true);
                    await _ensurePermission();
                  }
                },
                child: Text(
                  _permanentlyDenied ? "Sozlamalarni ochish" : "Ruxsat berish",
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
