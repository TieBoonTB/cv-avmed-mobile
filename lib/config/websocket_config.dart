/// WebSocket configuration constants and utilities
class WebSocketConfig {
  // Default server configurations
//   static const String defaultServerUrl = 'wss://avmed-backend-pwa.blackplant-aea8002c.southeastasia.azurecontainerapps.io/detect_pt';
  static const String defaultServerUrl = 'ws://localhost:8008/detect_pt';
  static const String defaultServerHost = 'avmed-backend-pwa.blackplant-aea8002c.southeastasia.azurecontainerapps.io';
  static const int defaultServerPort = 8008;
  static const String defaultEndpoint = '/detect_pt';
  
  // Connection settings
  static const Duration connectionTimeout = Duration(seconds: 10);
  static const Duration reconnectDelay = Duration(seconds: 3);
  static const int maxReconnectAttempts = 5;
  static const Duration heartbeatInterval = Duration(seconds: 30);
  
  // Frame processing settings
  static const Duration minFrameInterval = Duration(milliseconds: 200); // 5 FPS max
  static const int maxFrameWidth = 1280;
  static const int maxFrameHeight = 720;
  static const int defaultFramesPerSecond = 30;
  
  // Detection thresholds
  static const double defaultConfidenceThreshold = 0.7;
  static const double minimumConfidenceThreshold = 0.3;
  static const double maximumConfidenceThreshold = 0.95;
  
  // Session settings
  static const bool defaultShouldRecord = false;
  static const int maxSessionDurationMinutes = 30;
  
  /// Build WebSocket URL from components
  static String buildUrl({
    String host = defaultServerHost,
    int port = defaultServerPort,
    String endpoint = defaultEndpoint,
    bool secure = false,
  }) {
    final protocol = secure ? 'wss' : 'ws';
    return '$protocol://$host:$port$endpoint';
  }
  
  /// Validate server URL format
  static bool isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return (uri.scheme == 'ws' || uri.scheme == 'wss') && 
             uri.host.isNotEmpty && 
             uri.port > 0;
    } catch (e) {
      return false;
    }
  }
  
  /// Extract host from WebSocket URL
  static String? extractHost(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host;
    } catch (e) {
      return null;
    }
  }
  
  /// Extract port from WebSocket URL
  static int? extractPort(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.port;
    } catch (e) {
      return null;
    }
  }
  
  /// Check if URL uses secure WebSocket
  static bool isSecureUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.scheme == 'wss';
    } catch (e) {
      return false;
    }
  }
  
  /// Validate confidence threshold
  static bool isValidConfidenceThreshold(double threshold) {
    return threshold >= minimumConfidenceThreshold && 
           threshold <= maximumConfidenceThreshold;
  }
  
  /// Validate frame dimensions
  static bool isValidFrameDimensions(int width, int height) {
    return width > 0 && 
           height > 0 && 
           width <= maxFrameWidth && 
           height <= maxFrameHeight;
  }
  
  /// Get recommended frame processing interval based on connection quality
  static Duration getRecommendedFrameInterval(ConnectionQuality quality) {
    switch (quality) {
      case ConnectionQuality.excellent:
        return const Duration(milliseconds: 150); // ~6.7 FPS
      case ConnectionQuality.good:
        return const Duration(milliseconds: 200); // 5 FPS
      case ConnectionQuality.fair:
        return const Duration(milliseconds: 300); // ~3.3 FPS
      case ConnectionQuality.poor:
        return const Duration(milliseconds: 500); // 2 FPS
    }
  }
}

/// Connection quality enumeration
enum ConnectionQuality {
  excellent,
  good,
  fair,
  poor,
}

/// WebSocket connection status
enum WebSocketConnectionStatus {
  disconnected,
  connecting,
  connected,
  sessionInitialized,
  error,
  reconnecting,
}

/// Extension for WebSocket connection status
extension WebSocketConnectionStatusExtension on WebSocketConnectionStatus {
  String get displayName {
    switch (this) {
      case WebSocketConnectionStatus.disconnected:
        return 'Disconnected';
      case WebSocketConnectionStatus.connecting:
        return 'Connecting';
      case WebSocketConnectionStatus.connected:
        return 'Connected';
      case WebSocketConnectionStatus.sessionInitialized:
        return 'Session Active';
      case WebSocketConnectionStatus.error:
        return 'Error';
      case WebSocketConnectionStatus.reconnecting:
        return 'Reconnecting';
    }
  }
  
  bool get isConnected {
    return this == WebSocketConnectionStatus.connected ||
           this == WebSocketConnectionStatus.sessionInitialized;
  }
  
  bool get isReady {
    return this == WebSocketConnectionStatus.sessionInitialized;
  }
  
  bool get hasError {
    return this == WebSocketConnectionStatus.error;
  }
}

/// WebSocket server presets for common configurations
class WebSocketServerPresets {
  static const Map<String, String> commonServers = {
    'local': 'ws://localhost:8008/detect_pt',
    'development': 'ws://dev.example.com:8008/detect_pt',
    'staging': 'ws://staging.example.com:8008/detect_pt',
    'production': 'wss://api.example.com/detect_pt',
  };
  
  /// Get server URL by environment name
  static String? getServerUrl(String environment) {
    return commonServers[environment.toLowerCase()];
  }
  
  /// Get all available environments
  static List<String> getAvailableEnvironments() {
    return commonServers.keys.toList();
  }
}

/// Environment configuration for WebSocket connections
class EnvironmentConfig {
  final String name;
  final String serverUrl;
  final bool isSecure;
  final Duration timeout;
  final bool shouldRecord;
  
  const EnvironmentConfig({
    required this.name,
    required this.serverUrl,
    this.isSecure = false,
    this.timeout = WebSocketConfig.connectionTimeout,
    this.shouldRecord = false,
  });
  
  /// Development environment
  static const EnvironmentConfig development = EnvironmentConfig(
    name: 'Development',
    serverUrl: 'ws://localhost:8008/detect_pt',
    isSecure: false,
    shouldRecord: false,
  );
  
  /// Staging environment
  static const EnvironmentConfig staging = EnvironmentConfig(
    name: 'Staging',
    serverUrl: 'ws://staging.example.com:8008/detect_pt',
    isSecure: false,
    shouldRecord: true,
  );
  
  /// Production environment
  static const EnvironmentConfig production = EnvironmentConfig(
    name: 'Production',
    serverUrl: 'wss://api.example.com/detect_pt',
    isSecure: true,
    shouldRecord: true,
  );
  
  /// Get all predefined environments
  static List<EnvironmentConfig> getAllEnvironments() {
    return [development, staging, production];
  }
}