import 'dart:typed_data';
import 'dart:async';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';

class BluetoothService {
  static final BluetoothService _instance = BluetoothService._internal();
  factory BluetoothService() => _instance;
  BluetoothService._internal();

  BluetoothConnection? _connection;
  bool get isConnected => _connection != null && _connection!.isConnected;

  // Request Bluetooth permissions
  Future<bool> requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetooth,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.location,
    ].request();

    return statuses.values.every((status) => status.isGranted);
  }

  // Get paired Bluetooth devices
  Future<List<BluetoothDevice>> getPairedDevices() async {
    try {
      List<BluetoothDevice> devices = await FlutterBluetoothSerial.instance.getBondedDevices();
      return devices;
    } catch (e) {
      print('Error getting paired devices: $e');
      return [];
    }
  }

  // Connect to a specific device
  Future<bool> connectToDevice(String address) async {
    try {
      print('🔗 Attempting to connect to: $address');
      _connection = await BluetoothConnection.toAddress(address);
      print('✅ Connected to device: $address');

      // Small delay to ensure connection is stable
      await Future.delayed(const Duration(milliseconds: 500));
      return true;
    } catch (e) {
      print('❌ Failed to connect to device: $e');
      return false;
    }
  }

  // Enhanced command sending with proper timeout and response handling
  Future<String> sendCommand(String command, {int timeoutSeconds = 3}) async {
    if (!isConnected) {
      throw Exception('Not connected to device');
    }

    try {
      print('📤 Sending command: $command');

      // Send command with carriage return and line feed
      _connection!.output.add(Uint8List.fromList('$command\r\n'.codeUnits));
      await _connection!.output.allSent;

      // Read response with proper timeout and termination handling
      String response = await _readResponseWithTimeout(timeoutSeconds * 1000);

      print('📥 Raw response: ${response.replaceAll('\r', '\\r').replaceAll('\n', '\\n')}');

      // Clean and return response
      String cleanResponse = _cleanResponse(response);
      print('📥 Clean response: $cleanResponse');

      return cleanResponse;

    } catch (e) {
      print('❌ Error sending command "$command": $e');
      throw Exception('Failed to send command: $command - $e');
    }
  }

  // Read response with proper timeout and ELM327-specific termination
  Future<String> _readResponseWithTimeout(int timeoutMs) async {
    StringBuffer buffer = StringBuffer();
    DateTime startTime = DateTime.now();
    bool responseComplete = false;

    try {
      await for (Uint8List data in _connection!.input!) {
        // Convert received bytes to string
        String received = String.fromCharCodes(data);
        buffer.write(received);

        String currentBuffer = buffer.toString();
        print('🔍 Buffer content: ${currentBuffer.replaceAll('\r', '\\r').replaceAll('\n', '\\n')}');

        // Check for various ELM327 response termination patterns
        responseComplete = _isResponseComplete(currentBuffer);

        if (responseComplete) {
          print('✅ Response complete detected');
          break;
        }

        // Check timeout
        if (DateTime.now().difference(startTime).inMilliseconds > timeoutMs) {
          print('⏱️ Response timeout after ${timeoutMs}ms');
          if (buffer.toString().trim().isNotEmpty) {
            print('📦 Returning partial response due to timeout');
            break;
          } else {
            throw TimeoutException('No response received within timeout', Duration(milliseconds: timeoutMs));
          }
        }
      }
    } catch (e) {
      if (e is TimeoutException) {
        rethrow;
      }
      print('❌ Error reading response: $e');
      throw Exception('Error reading response: $e');
    }

    return buffer.toString();
  }

  // Check if ELM327 response is complete
  bool _isResponseComplete(String buffer) {
    String upperBuffer = buffer.toUpperCase();

    // ELM327 response termination indicators
    List<String> terminators = [
      '>',              // Standard prompt
      'OK\r',           // Successful AT command
      'OK\n',           // Alternative line ending
      'ERROR\r',        // Error response
      'ERROR\n',        // Alternative line ending
      '?\r',            // Unknown command
      '?\n',            // Alternative line ending
      'NO DATA\r',      // No data available
      'NO DATA\n',      // Alternative line ending
      'UNABLE TO CONNECT\r',  // Connection failure
      'UNABLE TO CONNECT\n',  // Alternative line ending
      'BUS INIT',       // Bus initialization messages
      'SEARCHING',      // Protocol searching (partial, wait for more)
    ];

    // Check for definitive terminators
    for (String terminator in terminators) {
      if (upperBuffer.contains(terminator.toUpperCase())) {
        // Special case: if we see "SEARCHING", we need to wait for more
        if (terminator.contains('SEARCHING') && !upperBuffer.contains('>')) {
          continue;
        }
        return true;
      }
    }

    // Check for OBD-II response patterns (hex data followed by terminator)
    if (upperBuffer.contains('41 ') || upperBuffer.contains('43 ')) {
      // OBD-II data response - wait for prompt or line ending
      return upperBuffer.contains('>') || upperBuffer.endsWith('\r') || upperBuffer.endsWith('\n');
    }

    // Check for voltage reading pattern
    if (upperBuffer.contains('V') && (upperBuffer.contains('\r') || upperBuffer.contains('\n'))) {
      return true;
    }

    // Check for ELM327 identification pattern
    if (upperBuffer.contains('ELM327')) {
      return upperBuffer.contains('\r') || upperBuffer.contains('\n') || upperBuffer.contains('>');
    }

    return false;
  }

  // Clean response by removing unwanted characters and formatting
  String _cleanResponse(String response) {
    if (response.isEmpty) return response;

    // Remove carriage returns, line feeds, and prompts
    String cleaned = response
        .replaceAll('\r', '')
        .replaceAll('\n', ' ')
        .replaceAll('>', '')
        .trim();

    // Handle multiple spaces
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');

    // Special handling for common ELM327 responses
    if (cleaned.toUpperCase().contains('ELM327')) {
      // Extract version info
      RegExp versionRegex = RegExp(r'ELM327\s+v?\d+\.\d+', caseSensitive: false);
      Match? match = versionRegex.firstMatch(cleaned);
      if (match != null) {
        cleaned = match.group(0)!;
      }
    }

    return cleaned;
  }

  // Enhanced disconnect with proper cleanup
  Future<void> disconnect() async {
    if (_connection != null) {
      try {
        print('🔌 Disconnecting from OBD device...');
        await _connection!.close();
        print('✅ Successfully disconnected');
      } catch (e) {
        print('⚠️ Error during disconnect: $e');
      } finally {
        _connection = null;
      }
    }
  }

  // Add method to check connection health
  bool isConnectionHealthy() {
    return _connection != null &&
        _connection!.isConnected &&
        !_connection!.isConnected == false;
  }

  // Add method to get connection info for debugging
  String getConnectionInfo() {
    if (_connection == null) {
      return 'No connection';
    }

    try {
      return 'Connected: ${_connection!.isConnected}';
    } catch (e) {
      return 'Connection status unknown';
    }
  }

  void dispose() {
    disconnect();
  }
}
