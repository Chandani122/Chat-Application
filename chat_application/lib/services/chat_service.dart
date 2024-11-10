import 'dart:convert';
import 'dart:io';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:encrypt/encrypt.dart' as encrypt;

class ChatService {
  late WebSocketChannel _channel;
  final String _serverUrl = 'ws://localhost:8765';
  final encrypt.Key _encryptionKey = encrypt.Key.fromSecureRandom(32);
  final encrypt.IV _iv = encrypt.IV.fromSecureRandom(16);

  late String _userId;
  String get userId => _userId;
  
  Function(Map<String, dynamic>)? onMessageReceived;
  Function(Map<String, dynamic>)? onFileReceived;

  Future<void> connect(String authToken) async {
    _channel = WebSocketChannel.connect(
      Uri.parse('$_serverUrl?token=$authToken'),
    );

    _channel.stream.listen((message) {
      final data = json.decode(message);
      
      if (data['type'] == 'auth_response' && data['success']) {
        _userId = data['user_id'];
      } else if (data['type'] == 'message' && onMessageReceived != null) {
        onMessageReceived!(data);
      } else if (data['type'] == 'file' && onFileReceived != null) {
        onFileReceived!(data);
      }
    });

    _channel.sink.add(json.encode({
      'type': 'authentication',
      'auth_token': authToken,
    }));
  }

  Future<void> sendMessage(String receiverId, Map<String, dynamic> message) async {
    final encryptedContent = _encryptMessage(message['content']);
    final messageToSend = {
      ...message,
      'content': encryptedContent,
    };
    
    _channel.sink.add(json.encode(messageToSend));
  }

  Future<void> sendFile(String receiverId, String filePath) async {
    final file = await File(filePath).readAsBytes();
    final encrypted = _encryptData(file);
    
    _channel.sink.add(json.encode({
      'type': 'file',
      'sender_id': _userId,
      'receiver_id': receiverId,
      'filename': filePath.split('/').last,
      'file_content': base64Encode(encrypted),
    }));
  }

  String _encryptMessage(String message) {
    final encrypter = encrypt.Encrypter(encrypt.AES(_encryptionKey));
    final encrypted = encrypter.encrypt(message, iv: _iv);
    return encrypted.base64;
  }

  List<int> _encryptData(List<int> data) {
    final encrypter = encrypt.Encrypter(encrypt.AES(_encryptionKey));
    final encrypted = encrypter.encryptBytes(data, iv: _iv);
    return encrypted.bytes;
  }

  void dispose() {
    _channel.sink.close();
  }
}