import 'package:flutter/material.dart';
import '../config/websocket_config.dart';
import '../utils/websocket_utils.dart';

/// WebSocket configuration widget for AVMED detection service
class WebSocketConfigWidget extends StatefulWidget {
  final String? initialServerUrl;
  final String? initialPatientCode;
  final bool initialShouldRecord;
  final Function(String serverUrl, String patientCode, bool shouldRecord)? onConfigChanged;
  
  const WebSocketConfigWidget({
    super.key,
    this.initialServerUrl,
    this.initialPatientCode,
    this.initialShouldRecord = false,
    this.onConfigChanged,
  });

  @override
  State<WebSocketConfigWidget> createState() => _WebSocketConfigWidgetState();
}

class _WebSocketConfigWidgetState extends State<WebSocketConfigWidget> {
  late TextEditingController _serverUrlController;
  late TextEditingController _patientCodeController;
  bool _shouldRecord = false;
  EnvironmentConfig? _selectedEnvironment;
  String? _urlError;
  String? _patientCodeError;

  @override
  void initState() {
    super.initState();
    
    _serverUrlController = TextEditingController(
      text: widget.initialServerUrl ?? WebSocketConfig.defaultServerUrl,
    );
    _patientCodeController = TextEditingController(
      text: widget.initialPatientCode ?? WebSocketUtils.generatePatientCode(),
    );
    _shouldRecord = widget.initialShouldRecord;
    
    // Set default environment
    _selectedEnvironment = EnvironmentConfig.development;
    
    _serverUrlController.addListener(_validateUrl);
    _patientCodeController.addListener(_validatePatientCode);
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    _patientCodeController.dispose();
    super.dispose();
  }

  void _validateUrl() {
    setState(() {
      final url = _serverUrlController.text.trim();
      if (url.isEmpty) {
        _urlError = 'Server URL is required';
      } else if (!WebSocketConfig.isValidUrl(url)) {
        _urlError = 'Invalid WebSocket URL format';
      } else {
        _urlError = null;
      }
    });
    _notifyConfigChanged();
  }

  void _validatePatientCode() {
    setState(() {
      final code = _patientCodeController.text.trim();
      if (code.isEmpty) {
        _patientCodeError = 'Patient code is required';
      } else if (code.length < 3) {
        _patientCodeError = 'Patient code too short';
      } else {
        _patientCodeError = null;
      }
    });
    _notifyConfigChanged();
  }

  void _notifyConfigChanged() {
    if (_urlError == null && _patientCodeError == null && widget.onConfigChanged != null) {
      widget.onConfigChanged!(
        _serverUrlController.text.trim(),
        _patientCodeController.text.trim(),
        _shouldRecord,
      );
    }
  }

  void _selectEnvironment(EnvironmentConfig? environment) {
    if (environment != null) {
      setState(() {
        _selectedEnvironment = environment;
        _serverUrlController.text = environment.serverUrl;
        _shouldRecord = environment.shouldRecord;
      });
      _validateUrl();
    }
  }

  void _generatePatientCode() {
    setState(() {
      _patientCodeController.text = WebSocketUtils.generatePatientCode();
    });
    _validatePatientCode();
  }

  bool get isValid => _urlError == null && _patientCodeError == null;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.settings, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'WebSocket Configuration',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Environment presets
            Text(
              'Environment Presets',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: EnvironmentConfig.getAllEnvironments().map((env) {
                final isSelected = _selectedEnvironment?.name == env.name;
                return FilterChip(
                  label: Text(env.name),
                  selected: isSelected,
                  onSelected: (selected) => selected ? _selectEnvironment(env) : null,
                  avatar: env.isSecure ? const Icon(Icons.security, size: 16) : null,
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            
            // Server URL
            TextField(
              controller: _serverUrlController,
              decoration: InputDecoration(
                labelText: 'Server URL',
                hintText: 'ws://localhost:8008/detect_pt',
                prefixIcon: const Icon(Icons.link),
                errorText: _urlError,
                border: const OutlineInputBorder(),
                suffixIcon: _urlError == null
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : const Icon(Icons.error, color: Colors.red),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 8),
            
            // URL info
            if (_serverUrlController.text.isNotEmpty)
              Row(
                children: [
                  Icon(
                    WebSocketConfig.isSecureUrl(_serverUrlController.text)
                        ? Icons.security
                        : Icons.security_outlined,
                    size: 16,
                    color: WebSocketConfig.isSecureUrl(_serverUrlController.text)
                        ? Colors.green
                        : Colors.orange,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    WebSocketConfig.isSecureUrl(_serverUrlController.text)
                        ? 'Secure connection (WSS)'
                        : 'Unsecure connection (WS)',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            const SizedBox(height: 16),
            
            // Patient Code
            TextField(
              controller: _patientCodeController,
              decoration: InputDecoration(
                labelText: 'Patient Code',
                hintText: 'PT_12345678',
                prefixIcon: const Icon(Icons.person),
                errorText: _patientCodeError,
                border: const OutlineInputBorder(),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _generatePatientCode,
                      tooltip: 'Generate new code',
                    ),
                    if (_patientCodeError == null)
                      const Icon(Icons.check_circle, color: Colors.green)
                    else
                      const Icon(Icons.error, color: Colors.red),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Recording option
            SwitchListTile(
              title: const Text('Enable Recording'),
              subtitle: const Text('Record session for later analysis'),
              value: _shouldRecord,
              onChanged: (value) {
                setState(() {
                  _shouldRecord = value;
                });
                _notifyConfigChanged();
              },
              secondary: const Icon(Icons.videocam),
            ),
            const SizedBox(height: 16),
            
            // Status indicator
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isValid ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isValid ? Colors.green : Colors.red,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isValid ? Icons.check_circle : Icons.error,
                    color: isValid ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isValid
                          ? 'Configuration is valid and ready'
                          : 'Please fix configuration errors',
                      style: TextStyle(
                        color: isValid ? Colors.green : Colors.red,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Simple WebSocket configuration dialog
class WebSocketConfigDialog extends StatefulWidget {
  final String? initialServerUrl;
  final String? initialPatientCode;
  final bool initialShouldRecord;
  
  const WebSocketConfigDialog({
    super.key,
    this.initialServerUrl,
    this.initialPatientCode,
    this.initialShouldRecord = false,
  });

  @override
  State<WebSocketConfigDialog> createState() => _WebSocketConfigDialogState();
}

class _WebSocketConfigDialogState extends State<WebSocketConfigDialog> {
  String? _serverUrl;
  String? _patientCode;
  bool _shouldRecord = false;
  bool _isValid = false;

  @override
  void initState() {
    super.initState();
    _serverUrl = widget.initialServerUrl;
    _patientCode = widget.initialPatientCode;
    _shouldRecord = widget.initialShouldRecord;
    _validateConfig();
  }

  void _validateConfig() {
    setState(() {
      _isValid = _serverUrl != null &&
                 _serverUrl!.isNotEmpty &&
                 WebSocketConfig.isValidUrl(_serverUrl!) &&
                 _patientCode != null &&
                 _patientCode!.isNotEmpty &&
                 _patientCode!.length >= 3;
    });
  }

  void _onConfigChanged(String serverUrl, String patientCode, bool shouldRecord) {
    _serverUrl = serverUrl;
    _patientCode = patientCode;
    _shouldRecord = shouldRecord;
    _validateConfig();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('WebSocket Configuration'),
      content: SingleChildScrollView(
        child: WebSocketConfigWidget(
          initialServerUrl: widget.initialServerUrl,
          initialPatientCode: widget.initialPatientCode,
          initialShouldRecord: widget.initialShouldRecord,
          onConfigChanged: _onConfigChanged,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isValid
              ? () => Navigator.of(context).pop({
                    'serverUrl': _serverUrl,
                    'patientCode': _patientCode,
                    'shouldRecord': _shouldRecord,
                  })
              : null,
          child: const Text('Connect'),
        ),
      ],
    );
  }
}