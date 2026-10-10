import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  late final MobileScannerController _controller;
  String? _errorMessage;
  bool _didScan = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      autoStart: true,
      detectionSpeed: DetectionSpeed.noDuplicates,
      formats: const [
        BarcodeFormat.ean13,
        BarcodeFormat.ean8,
        BarcodeFormat.upcA,
        BarcodeFormat.upcE,
        BarcodeFormat.code128,
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleCapture(BarcodeCapture capture) {
    if (_didScan) return;

    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue?.trim();
      if (value == null || value.isEmpty) continue;

      _didScan = true;
      Navigator.of(context).pop(value);
      return;
    }
  }

  void _handleScanError(Object error, StackTrace stackTrace) {
    developer.log(
      'Barkod tarayıcı hatası.',
      name: 'ucuzgetir.scanner',
      error: error,
      stackTrace: stackTrace,
    );
    if (!mounted) return;
    setState(() {
      _errorMessage = 'Kamera başlatılamadı. Kamera iznini Ayarlar bölümünden kontrol edin.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final errorMessage = _errorMessage;

    return Scaffold(
      appBar: AppBar(title: const Text('Barkod tara')),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 18),
            child: Text(
              'Ürünün barkodunu çerçevenin içine hizalayın. Görüntü kaydedilmez.',
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: errorMessage == null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: MobileScanner(
                      controller: _controller,
                      onDetect: _handleCapture,
                      onDetectError: _handleScanError,
                      errorBuilder: (context, error) => Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            errorMessage ??
                                'Kamera açılamadı. Kamera iznini kontrol edin.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  )
                : Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(errorMessage, textAlign: TextAlign.center),
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.close),
              label: const Text('Kapat'),
            ),
          ),
        ],
      ),
    );
  }
}
