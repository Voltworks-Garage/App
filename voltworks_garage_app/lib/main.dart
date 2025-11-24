import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/ble_provider.dart';
import 'screens/home_screen.dart';
import 'utils/app_theme.dart';
import 'utils/constants.dart';

void main() {
  runApp(const VoltworksGarageApp());
}

class VoltworksGarageApp extends StatelessWidget {
  const VoltworksGarageApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => BleProvider(),
      child: MaterialApp(
        title: AppInfo.appName,
        theme: AppTheme.darkTheme,
        home: const HomeScreen(),
      ),
    );
  }
}
