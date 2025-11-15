import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/device_provider.dart';
import '../services/device_service.dart';
import '../utils/api_exception.dart';

/// Screen for adding a new device by claiming it with Device ID
class AddDeviceScreen extends StatefulWidget {
  const AddDeviceScreen({Key? key}) : super(key: key);

  @override
  State<AddDeviceScreen> createState() => _AddDeviceScreenState();
}

class _AddDeviceScreenState extends State<AddDeviceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _deviceIdController = TextEditingController();
  final _deviceService = DeviceService();

  bool _isLoading = false;
  String? _errorMessage;
  bool _isValid = false;

  // Device ID format validation regex
  static final _deviceIdRegex = RegExp(r'^[\w-]+-DEV-\d{2}-[a-f0-9]{24}$');

  @override
  void initState() {
    super.initState();
    _deviceService.initialize();
    _deviceIdController.addListener(_validateDeviceId);
  }

  @override
  void dispose() {
    _deviceIdController.dispose();
    super.dispose();
  }

  void _validateDeviceId() {
    final deviceId = _deviceIdController.text.trim();
    setState(() {
      _isValid = _deviceIdRegex.hasMatch(deviceId);
      if (_errorMessage != null && _isValid) {
        _errorMessage = null;
      }
    });
  }

  Future<void> _handleAddDevice() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_isValid) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final deviceId = _deviceIdController.text.trim();
      final result = await _deviceService.claimDevice(deviceId);

      if (!mounted) return;

      // Show success message
      final message = result['message'] ?? 'Device added successfully';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );

      // Refresh device list
      await context.read<DeviceProvider>().refreshDevices();

      // Navigate back
      if (mounted) {
        Navigator.pop(context);
      }
    } on ApiException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'An unexpected error occurred. Please try again.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add My Device'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),

                // Info Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        // Icon
                        Icon(
                          Icons.qr_code_2,
                          size: 80,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(height: 24),

                        // Title
                        Text(
                          'Claim Your Device',
                          style: textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),

                        // Subtitle
                        Text(
                          'Enter the Device ID from your device',
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),

                        // Device ID TextField
                        TextFormField(
                          controller: _deviceIdController,
                          enabled: !_isLoading,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _handleAddDevice(),
                          decoration: InputDecoration(
                            labelText: 'Device ID',
                            hintText: 'wt001-DEV-01-xxxxxxxx',
                            helperText: 'You can find this ID on your device or from admin',
                            prefixIcon: const Icon(Icons.qr_code_scanner),
                            suffixIcon: _deviceIdController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _deviceIdController.clear();
                                      setState(() {
                                        _errorMessage = null;
                                      });
                                    },
                                  )
                                : null,
                            errorText: _errorMessage,
                            errorMaxLines: 3,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter a Device ID';
                            }
                            if (!_deviceIdRegex.hasMatch(value.trim())) {
                              return 'Invalid Device ID format';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),

                        // Add Device Button
                        FilledButton(
                          onPressed: _isLoading || !_isValid
                              ? null
                              : _handleAddDevice,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Add Device',
                                  style: TextStyle(fontSize: 16),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Info Section
                Card(
                  color: colorScheme.surfaceVariant.withOpacity(0.3),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 20,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Device ID Format',
                              style: textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Expected format: projectId-DEV-01-xxxxx',
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Example: wt001-DEV-01-690e6a9d092433c0acfb9178',
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
