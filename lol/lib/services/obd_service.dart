import '../models/vehicle_data.dart';
import 'bluetooth_service.dart';

class OBDService {
  final BluetoothService _bluetooth = BluetoothService();
  bool _isInitialized = false;

  // Enhanced initialization with proper delays and error handling
  Future<bool> initialize() async {
    if (!_bluetooth.isConnected) {
      throw Exception('Bluetooth not connected');
    }

    try {
      print('🔧 Starting OBD initialization...');
      _isInitialized = false;

      // Step 1: Basic ELM327 initialization with proper delays
      bool basicInit = await _performBasicInitialization();
      if (!basicInit) {
        print('❌ Basic initialization failed');
        return false;
      }

      // Step 2: Protocol detection and setup (bike-optimized)
      bool protocolInit = await _performProtocolInitialization();
      if (!protocolInit) {
        print('❌ Protocol initialization failed');
        return false;
      }

      // Step 3: Test OBD communication
      bool testInit = await _testObdCommunication();
      if (!testInit) {
        print('❌ OBD communication test failed');
        return false;
      }

      _isInitialized = true;
      print('✅ OBD initialized successfully!');
      return true;

    } catch (e) {
      print('❌ Failed to initialize OBD: $e');
      _isInitialized = false;
      return false;
    }
  }

  // Step 1: Basic ELM327 initialization with proper delays
  Future<bool> _performBasicInitialization() async {
    print('🔧 Performing basic ELM327 initialization...');

    // Basic initialization commands with descriptions
    List<Map<String, dynamic>> basicCommands = [
      {'cmd': 'ATD', 'delay': 500, 'desc': 'Set all to defaults'},
      {'cmd': 'ATZ', 'delay': 2000, 'desc': 'Reset ELM327'}, // Longer delay for reset
      {'cmd': 'ATE0', 'delay': 500, 'desc': 'Turn off echo'},
      {'cmd': 'ATL0', 'delay': 500, 'desc': 'Turn off line feeds'},
      {'cmd': 'ATS0', 'delay': 500, 'desc': 'Turn off spaces'},
      {'cmd': 'ATH1', 'delay': 500, 'desc': 'Turn on headers (important for bikes)'},
      {'cmd': 'ATST32', 'delay': 500, 'desc': 'Set timeout to 32 x 4ms = 128ms'},
    ];

    for (var cmdInfo in basicCommands) {
      print('📤 ${cmdInfo['desc']}: ${cmdInfo['cmd']}');

      bool success = await _sendCommandWithRetry(cmdInfo['cmd'], maxRetries: 2);
      if (!success) {
        print('❌ Failed: ${cmdInfo['desc']}');
        return false;
      }

      // CRITICAL: Wait between commands for Bluetooth
      await Future.delayed(Duration(milliseconds: cmdInfo['delay']));
    }

    return true;
  }

  // Step 2: Protocol initialization with bike-specific fallbacks
  Future<bool> _performProtocolInitialization() async {
    print('🔧 Performing protocol initialization...');

    // Try multiple protocol strategies (bike-optimized order)
    List<Map<String, String>> protocolStrategies = [
      {'cmd': 'ATSP6', 'desc': 'CAN 11/500 (common for modern bikes)'},
      {'cmd': 'ATSP0', 'desc': 'Auto-detect protocol'},
      {'cmd': 'ATSP7', 'desc': 'CAN 29/500'},
      {'cmd': 'ATSP3', 'desc': 'KWP2000 (older bikes)'},
      {'cmd': 'ATSP5', 'desc': 'ISO 9141-2 (legacy bikes)'},
      {'cmd': 'ATSP8', 'desc': 'CAN 11/250'},
    ];

    for (var protocol in protocolStrategies) {
      print('🔍 Trying ${protocol['desc']}: ${protocol['cmd']}');

      // Send protocol command
      bool protocolSet = await _sendCommandWithRetry(protocol['cmd']!, maxRetries: 2);
      if (!protocolSet) {
        print('❌ Failed to set: ${protocol['cmd']!}');
        continue;
      }

      // Extra delay for protocol setup
      await Future.delayed(const Duration(milliseconds: 1000));

      // Test protocol with initialization command
      print('🧪 Testing protocol with supported PIDs...');
      bool initTest = await _sendCommandWithRetry('0100', maxRetries: 2, timeoutSeconds: 5);

      if (initTest) {
        print('✅ Protocol successful: ${protocol['desc']}');
        return true;
      } else {
        print('❌ Protocol test failed: ${protocol['desc']}');
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }

    print('❌ All protocols failed');
    return false;
  }

  // Step 3: Test OBD communication
  Future<bool> _testObdCommunication() async {
    print('🔧 Testing OBD communication...');

    // Test with supported PIDs command
    bool pidsTest = await _sendCommandWithRetry('0100', maxRetries: 3, timeoutSeconds: 3);
    if (pidsTest) {
      print('✅ PIDs test successful');
      return true;
    }

    // Fallback: Test with voltage reading
    print('🔄 Trying voltage reading as fallback...');
    bool voltageTest = await _sendCommandWithRetry('ATRV', maxRetries: 2, timeoutSeconds: 3);
    if (voltageTest) {
      print('✅ Voltage test successful');
      return true;
    }

    print('❌ All communication tests failed');
    return false;
  }

  // Enhanced command sending with retry logic and proper error handling
  Future<bool> _sendCommandWithRetry(String command, {int maxRetries = 3, int timeoutSeconds = 2}) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      print('📤 Sending: $command (attempt $attempt/$maxRetries)');

      try {
        // Send command and wait for response
        String response = await _bluetooth.sendCommand(command);
        print('📥 Response: $response');

        // Check for error responses
        if (_isErrorResponse(response)) {
          print('❌ Error response: $response');
          if (attempt < maxRetries) {
            print('🔄 Retrying in 1 second...');
            await Future.delayed(const Duration(seconds: 1));
            continue;
          }
          return false;
        }

        // Check for successful responses
        if (_isSuccessfulResponse(response, command)) {
          print('✅ Command successful: $command');
          return true;
        } else {
          print('❌ Unexpected response for $command: $response');
          if (attempt < maxRetries) {
            await Future.delayed(const Duration(seconds: 1));
            continue;
          }
          return false;
        }

      } catch (e) {
        print('❌ Command error: $e');
        if (attempt < maxRetries) {
          print('🔄 Retrying in 1 second...');
          await Future.delayed(const Duration(seconds: 1));
          continue;
        }
        return false;
      }
    }

    return false;
  }

  // Check if response indicates an error
  bool _isErrorResponse(String response) {
    List<String> errorIndicators = [
      'ERROR',
      'UNABLE TO CONNECT',
      'BUS INIT',
      'NO DATA',
      'STOPPED',
      '?',
      'CAN ERROR',
      'BUSINIT',
      'BUFFER FULL',
      'BUS BUSY',
    ];

    String upperResponse = response.toUpperCase();
    return errorIndicators.any((error) => upperResponse.contains(error));
  }

  // Check if response indicates success
  bool _isSuccessfulResponse(String response, String command) {
    String upperResponse = response.toUpperCase();

    // For AT commands, expect OK
    if (command.startsWith('AT')) {
      return upperResponse.contains('OK') ||
          upperResponse.contains('ELM327') ||
          (command == 'ATRV' && upperResponse.contains('V')); // Voltage reading
    }

    // For OBD PIDs, expect response with data
    if (command.startsWith('01')) {
      return upperResponse.startsWith('41') || upperResponse.contains('41');
    }

    // Default: any non-error response
    return !_isErrorResponse(response) && response.trim().isNotEmpty;
  }

  // Read vehicle speed (unchanged but with better error handling)
  Future<int?> getVehicleSpeed() async {
    if (!_isInitialized) {
      print('⚠️ OBD not initialized - cannot read speed');
      return null;
    }

    try {
      String response = await _bluetooth.sendCommand(OBDPIDs.VEHICLE_SPEED);
      print('🏍️ Speed response: $response');

      if (response.contains('41 0D')) {
        List<String> parts = response.split(' ');
        if (parts.length >= 3) {
          int speed = int.parse(parts[2], radix: 16);
          print('🏍️ Vehicle speed: ${speed} km/h');
          return speed;
        }
      }
    } catch (e) {
      print('❌ Error reading vehicle speed: $e');
    }
    return null;
  }

  // Read engine RPM (unchanged but with better error handling)
  Future<int?> getEngineRPM() async {
    if (!_isInitialized) {
      print('⚠️ OBD not initialized - cannot read RPM');
      return null;
    }

    try {
      String response = await _bluetooth.sendCommand(OBDPIDs.ENGINE_RPM);
      print('🏍️ RPM response: $response');

      if (response.contains('41 0C')) {
        List<String> parts = response.split(' ');
        if (parts.length >= 4) {
          int a = int.parse(parts[2], radix: 16);
          int b = int.parse(parts[3], radix: 16);
          int rpm = ((a * 256) + b) ~/ 4;
          print('🏍️ Engine RPM: $rpm');
          return rpm;
        }
      }
    } catch (e) {
      print('❌ Error reading engine RPM: $e');
    }
    return null;
  }

  // Read diagnostic trouble codes (unchanged)
  Future<List<String>> getDiagnosticCodes() async {
    if (!_isInitialized) return [];

    try {
      String response = await _bluetooth.sendCommand(OBDPIDs.DIAGNOSTIC_CODES);
      List<String> codes = [];

      if (response.startsWith('43')) {
        List<String> parts = response.split(' ');
        if (parts.length > 1) {
          int numCodes = int.parse(parts[1], radix: 16);

          for (int i = 0; i < numCodes; i++) {
            if (parts.length >= (3 + i * 2)) {
              String code1 = parts[2 + i * 2];
              String code2 = parts[3 + i * 2];
              String dtcCode = _parseDTCCode(code1 + code2);
              codes.add(dtcCode);
            }
          }
        }
      }
      return codes;
    } catch (e) {
      print('Error reading diagnostic codes: $e');
      return [];
    }
  }

  // Parse DTC code from hex to standard format (unchanged)
  String _parseDTCCode(String hexCode) {
    try {
      int code = int.parse(hexCode, radix: 16);

      late String firstChar;
      int firstTwoBits = (code >> 14) & 0x03;
      switch (firstTwoBits) {
        case 0: firstChar = 'P'; break;
        case 1: firstChar = 'C'; break;
        case 2: firstChar = 'B'; break;
        case 3: firstChar = 'U'; break;
        default: firstChar = 'P';
      }

      int remaining = code & 0x3FFF;
      return '$firstChar${remaining.toRadixString(16).toUpperCase().padLeft(4, '0')}';
    } catch (e) {
      return 'UNKNOWN';
    }
  }

  // Get all vehicle data at once (unchanged)
  Future<VehicleData> getAllData() async {
    if (!_isInitialized) {
      return VehicleData(isConnected: false);
    }

    try {
      int? speed = await getVehicleSpeed();
      int? rpm = await getEngineRPM();
      List<String> errors = await getDiagnosticCodes();

      return VehicleData(
        speed: speed,
        rpm: rpm,
        errorCodes: errors,
        isConnected: true,
      );
    } catch (e) {
      print('Error getting all data: $e');
      return VehicleData(isConnected: false);
    }
  }

  // Add method to check initialization status
  bool get isInitialized => _isInitialized;

  void dispose() {
    _isInitialized = false;
    _bluetooth.dispose();
  }
}
