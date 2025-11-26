import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/ble_provider.dart';
import 'screens/home_screen.dart';
import 'services/foreground_service.dart';
import 'utils/app_theme.dart';
import 'utils/constants.dart';

void main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize foreground service for Android
  await ForegroundService.initialize();

  runApp(const VoltworksGarageApp());
}

class VoltworksGarageApp extends StatefulWidget {
  const VoltworksGarageApp({super.key});

  @override
  State<VoltworksGarageApp> createState() => _VoltworksGarageAppState();
}

class _VoltworksGarageAppState extends State<VoltworksGarageApp> {
  // Keep a single instance of BleProvider that survives app backgrounding
  late final BleProvider _bleProvider;

  @override
  void initState() {
    super.initState();
    // Create provider once and keep it alive
    _bleProvider = BleProvider();
  }

  @override
  void dispose() {
    // Disconnect BLE before disposing
    _bleProvider.disconnect();
    _bleProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _bleProvider, // Use the persistent provider instance
      child: MaterialApp(
        title: AppInfo.appName,
        theme: AppTheme.darkTheme,
        home: const HomeScreen(),
      ),
    );
  }
}
