import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'package:encrypt/encrypt.dart' as encrypt;

class ChatService {
  WebSocketChannel? _channel;
  final String _serverUrl = '<BACKEND SERVER URL>';
  final encrypt.Key _encryptionKey = encrypt.Key.fromSecureRandom(32);
  final encrypt.IV _iv = encrypt.IV.fromSecureRandom(16);

  late String _userId;
  String get userId => _userId;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  Function(Map<String, dynamic>)? onMessageReceived;
  Function(Map<String, dynamic>)? onFileReceived;
  Function(bool)? onConnectionStateChanged;

  String _lastAuthToken = '';

  Future<void> connect(String authToken) async {
    _lastAuthToken = authToken;
    _isConnected = false;

    try {
      _channel = IOWebSocketChannel.connect(
        Uri.parse('$_serverUrl?token=$authToken'),
        headers: {
          'Connection': 'Upgrade',
          'Upgrade': 'websocket',
        },
        pingInterval: const Duration(seconds: 10),
      );

      _channel?.stream.listen(
        (message) => _processMessage(message),
        onError: (error) => _handleConnectionError(error),
        onDone: _handleConnectionClosed,
      );

      await _authenticate(authToken);
    } catch (e) {
      print('Connection error: $e');
      _handleConnectionError(e);
    }
  }

  void _processMessage(dynamic message) {
    try {
      final data = json.decode(message);

      if (data['type'] == 'auth_response' && data['success']) {
        _userId = data['user_id'];
        _isConnected = true;
        onConnectionStateChanged?.call(true);
      } else if (data['type'] == 'message' && onMessageReceived != null) {
        onMessageReceived!(data);
      } else if (data['type'] == 'file' && onFileReceived != null) {
        onFileReceived!(data);
      } else if (data['type'] == 'error') {
        print('Server error: ${data['message']}');
      }
    } catch (e) {
      print('Error processing message: $e');
    }
  }

  void _handleConnectionError(dynamic error) {
    print('WebSocket error: $error');
    _isConnected = false;
    onConnectionStateChanged?.call(false);
    _reconnect();
  }

  void _handleConnectionClosed() {
    print('WebSocket connection closed');
    _isConnected = false;
    onConnectionStateChanged?.call(false);
    _reconnect();
  }

  Future<void> _reconnect() async {
    await Future.delayed(const Duration(seconds: 5));
    if (!_isConnected && _lastAuthToken.isNotEmpty) {
      print('Attempting to reconnect...');
      connect(_lastAuthToken);
    }
  }

  Future<void> _authenticate(String authToken) async {
    try {
      _channel?.sink.add(json.encode({
        'type': 'authentication',
        'auth_token': authToken,
      }));

      await Future.delayed(Duration(seconds: 5));
      if (!_isConnected) throw Exception("Authentication timed out");
    } catch (e) {
      print("Authentication error: $e");
      _handleConnectionError(e);
    }
  }

  Future<void> sendMessage(String receiverId, Map message) async {
    try {
      if (!_isConnected) throw Exception('Not connected to chat server');

      final encryptedContent = _encryptMessage(message['content']);
      final messageToSend = {
        ...message,
        'content': encryptedContent,
      };

      _channel?.sink.add(json.encode(messageToSend));
    } catch (e) {
      print('Error sending message: $e');
    }
  }

  String _encryptMessage(String message) {
    final encrypter = encrypt.Encrypter(encrypt.AES(_encryptionKey));
    final encrypted = encrypter.encrypt(message, iv: _iv);
    return encrypted.base64;
  }

  void dispose() {
    _channel?.sink.close();
    _isConnected = false;
  }
}