import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/ble_provider.dart';
import '../utils/constants.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BleProvider>(
      builder: (context, bleProvider, child) {
        // Auto-scroll when new messages arrive
        if (bleProvider.isConnected && bleProvider.receivedMessages.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text(AppInfo.appName),
            actions: [
              // Connection status indicator
              if (bleProvider.isConnected)
                IconButton(
                  icon: const Icon(Icons.bluetooth_connected),
                  onPressed: () {
                    bleProvider.disconnect();
                  },
                  tooltip: 'Disconnect',
                ),
            ],
          ),
          body: bleProvider.isConnected
              ? _buildConnectedView(context, bleProvider)
              : _buildDisconnectedView(context, bleProvider),
        );
      },
    );
  }

  /// View when disconnected - shows scan button and device list
  Widget _buildDisconnectedView(BuildContext context, BleProvider bleProvider) {
    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(AppLayout.paddingLarge),
          child: Column(
            children: [
              Icon(
                Icons.electric_bike,
                size: 80,
                color: AppColors.primary,
              ),
              const SizedBox(height: AppLayout.paddingMedium),
              Text(
                'Welcome to ${AppInfo.appName}',
                style: AppTextStyles.heading2,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppLayout.paddingSmall),
              Text(
                'Scan for your motorcycle',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),

        // Scan button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppLayout.paddingLarge),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: bleProvider.isScanning
                  ? null
                  : () => bleProvider.startScan(),
              icon: Icon(
                bleProvider.isScanning
                    ? Icons.bluetooth_searching
                    : Icons.bluetooth,
              ),
              label: Text(
                bleProvider.isScanning ? 'Scanning...' : 'Scan for Devices',
              ),
            ),
          ),
        ),

        // Error message
        if (bleProvider.lastError != null)
          Padding(
            padding: const EdgeInsets.all(AppLayout.paddingMedium),
            child: Container(
              padding: const EdgeInsets.all(AppLayout.paddingMedium),
              decoration: BoxDecoration(
                color: AppColors.danger.withOpacity(0.2),
                borderRadius: BorderRadius.circular(AppLayout.borderRadiusSmall),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.danger),
                  const SizedBox(width: AppLayout.paddingSmall),
                  Expanded(
                    child: Text(
                      bleProvider.lastError!,
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.danger),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => bleProvider.clearError(),
                  ),
                ],
              ),
            ),
          ),

        // Device list
        Expanded(
          child: bleProvider.scanResults.isEmpty
              ? Center(
                  child: Text(
                    bleProvider.isScanning
                        ? 'Looking for devices...'
                        : 'No devices found.\nTap "Scan for Devices" to start.',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.builder(
                  itemCount: bleProvider.scanResults.length,
                  itemBuilder: (context, index) {
                    final result = bleProvider.scanResults[index];
                    final device = result.device;
                    final deviceName = device.platformName.isNotEmpty
                        ? device.platformName
                        : 'Unknown Device';

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: AppLayout.paddingMedium,
                        vertical: AppLayout.paddingSmall,
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.bluetooth, color: AppColors.primary),
                        title: Text(deviceName),
                        subtitle: Text(
                          device.remoteId.toString(),
                          style: AppTextStyles.bodySmall,
                        ),
                        trailing: Text(
                          '${result.rssi} dBm',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        onTap: () async {
                          await bleProvider.stopScan();
                          await bleProvider.connect(device);
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  /// View when connected - shows device info and received data
  Widget _buildConnectedView(BuildContext context, BleProvider bleProvider) {
    return Column(
      children: [
        // Connected device info
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppLayout.paddingLarge),
          color: AppColors.surface,
          child: Column(
            children: [
              const Icon(
                Icons.check_circle,
                color: AppColors.success,
                size: 48,
              ),
              const SizedBox(height: AppLayout.paddingMedium),
              Text(
                'Connected to',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppLayout.paddingSmall),
              Text(
                bleProvider.connectedDeviceName ?? 'Device',
                style: AppTextStyles.heading2,
              ),
              const SizedBox(height: AppLayout.paddingMedium),
              ElevatedButton.icon(
                onPressed: () => bleProvider.disconnect(),
                icon: const Icon(Icons.bluetooth_disabled),
                label: const Text('Disconnect'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.danger,
                ),
              ),
            ],
          ),
        ),

        // Console header
        Padding(
          padding: const EdgeInsets.all(AppLayout.paddingMedium),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Console',
                style: AppTextStyles.heading3,
              ),
              if (bleProvider.receivedMessages.isNotEmpty)
                TextButton(
                  onPressed: () => bleProvider.clearMessages(),
                  child: const Text('Clear'),
                ),
            ],
          ),
        ),

        // Console output
        Expanded(
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(
              horizontal: AppLayout.paddingMedium,
              vertical: AppLayout.paddingSmall,
            ),
            padding: const EdgeInsets.all(AppLayout.paddingMedium),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(AppLayout.borderRadiusSmall),
              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
            ),
            child: bleProvider.receivedMessages.isEmpty
                ? Center(
                    child: Text(
                      'Waiting for data...',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                        fontFamily: 'monospace',
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    controller: _scrollController,
                    child: SelectableText(
                      bleProvider.receivedMessages.join('\n'),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: AppColors.primary,
                        height: 1.4,
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
