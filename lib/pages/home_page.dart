import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:qr_code_scanner/qr_code_scanner.dart';

import '../widgets/result_dialog.dart';
import 'settings_page.dart';

class HomePage extends StatefulWidget {
  final String url;

  const HomePage({
    Key? key,
    required this.url,
  }) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  late QRViewController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("TAP"),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () async {
              controller.pauseCamera();

              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsPage(),
                ),
              );

              controller.resumeCamera();
            },
          )
        ],
      ),
      body: QRView(
        key: qrKey,
        onQRViewCreated: _onQRViewCreated,
        overlay: QrScannerOverlayShape(
          borderColor: Theme.of(context).primaryColor,
          borderRadius: 10,
          borderLength: 30,
          borderWidth: 10,
          cutOutSize: MediaQuery.of(context).size.width * 0.75,
        ),
      ),
    );
  }

  void _onQRViewCreated(QRViewController controller) {
    setState(() => this.controller = controller);

    controller.scannedDataStream.listen((data) async {
      try {
        controller.pauseCamera();

        final id = _extractId(data.code);
        if (id == null) {
          throw const FormatException("Unsupported QR Code format.");
        }

        final isSuccess = await _submitId(id);
        if (!isSuccess) {
          throw Exception("Submission failied.");
        }

        await ResultDialog.showSuccess(
          context: context,
          description: 'ID ($id) added successfully!',
        );
      } catch (e) {
        await ResultDialog.showError(
          context: context,
          description: e.toString(),
        );
      } finally {
        controller.resumeCamera();
      }
    });
  }

  String? _extractId(String code) {
    final parts = code.split("-");
    return parts.length != 2 || parts[0] != "ID" ? null : parts[1];
  }

  Future<bool> _submitId(String id) async {
    final response = await http.post(Uri.parse("${widget.url}?id=$id"));

    if (response.statusCode == 302) {
      final redirectUrl = response.headers['location']!;
      final redirectResponse = await http.get(Uri.parse(redirectUrl));
      if (redirectResponse.body.contains("FAILURE")) {
        return false;
      }
    } else if (response.statusCode >= 300 ||
        response.body.contains("FAILURE")) {
      return false;
    }

    return true;
  }

  // In order to get hot reload to work we need to pause the camera if the
  // platform is android, or resume the camera if the platform is iOS.
  @override
  void reassemble() {
    super.reassemble();
    if (Platform.isAndroid) {
      controller.pauseCamera();
    }
    controller.resumeCamera();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
