import 'package:mobile_scanner/mobile_scanner.dart';

class QRScannerService {
  static final QRScannerService _instance = QRScannerService._internal();

  factory QRScannerService() => _instance;
  QRScannerService._internal();

  final MobileScannerController controller = MobileScannerController();

  Future<String?> scanQRCode() async {
    return null; // Will be handled in UI with mobile_scanner
  }

  void dispose() {
    controller.dispose();
  }
}
