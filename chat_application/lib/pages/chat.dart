import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import '../services/chat_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'message.dart';
import 'dart:io';

class ChatScreen extends StatefulWidget {
  final String receiverId;
  final String receiverName;
  final String authToken;

  const ChatScreen({
    super.key,
    required this.receiverId,
    required this.receiverName,
    required this.authToken,
  });

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;
  bool _isOnline = false;
  String? _error;
  late String _chatRoomId;

  @override
  void initState() {
    super.initState();
    _setupChatService();
  }

  Future<void> _setupChatService() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      _chatService.onConnectionStateChanged = (isConnected) {
        if (mounted) {
          setState(() => _isOnline = isConnected);
          if (isConnected) {
            _syncPendingMessages();
          }
        }
      };

      await _chatService.connect(widget.authToken);

      _chatService.onMessageReceived = (Map<String, dynamic> message) {
        _handleMessage(message);
      };

      _chatService.onFileReceived = (Map<String, dynamic> fileData) {
        _handleFile(fileData);
      };

      await _loadMessages();
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Unable to connect to chat server'),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: _setupChatService,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadMessages() async {
    try {
      final List<String> ids = [_chatService.userId, widget.receiverId];
      ids.sort();
      _chatRoomId = ids.join('_');

      final QuerySnapshot messages = await _firestore
          .collection('chats')
          .doc(_chatRoomId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();

      setState(() {
        _messages.clear();
        _messages.addAll(
          messages.docs
              .map((doc) => {
                    ...doc.data() as Map<String, dynamic>,
                    'id': doc.id,
                  })
              .toList(),
        );
      });

      _firestore
          .collection('chats')
          .doc(_chatRoomId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .snapshots()
          .listen(_handleFirestoreUpdate);
    } catch (e) {
      setState(() => _error = 'Error loading messages');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error loading messages')),
      );
    }
  }

  void _handleFirestoreUpdate(QuerySnapshot snapshot) {
    if (snapshot.docs.isEmpty) return;

    final latestMessage = snapshot.docs.first;
    final messageData = {
      ...latestMessage.data() as Map<String, dynamic>,
      'id': latestMessage.id,
    };

    final existingIndex =
        _messages.indexWhere((m) => m['id'] == messageData['id']);

    setState(() {
      if (existingIndex >= 0) {
        _messages[existingIndex] = messageData;
      } else {
        _messages.insert(0, messageData);
      }
    });
  }

  Future<void> _syncPendingMessages() async {
    final pendingMessages =
        _messages.where((m) => m['status'] == 'pending').toList();

    for (final message in pendingMessages) {
      try {
        await _chatService.sendMessage(widget.receiverId, message);

        final messageIndex =
            _messages.indexWhere((m) => m['id'] == message['id']);
        if (messageIndex >= 0) {
          setState(() {
            _messages[messageIndex] = {
              ..._messages[messageIndex],
              'status': 'sent'
            };
          });
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error')),
        );
      }
    }
  }

  void _handleMessage(Map<String, dynamic> message) {
    setState(() {
      final existingIndex =
          _messages.indexWhere((m) => m['id'] == message['id']);
      if (existingIndex >= 0) {
        _messages[existingIndex] = message;
      } else {
        _messages.insert(0, message);
      }
    });
  }

  void _handleFile(Map<String, dynamic> fileData) async {
    final fileContent = base64Decode(fileData['content']);
    final filename = fileData['filename'];

    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/$filename';
    final file = File(filePath);

    await file.writeAsBytes(fileContent);

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('File received: $filename')));
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final message = {
      'content': _messageController.text,
      'sender_id': _chatService.userId,
      'receiver_id': widget.receiverId,
      'timestamp': DateTime.now().toIso8601String(),
      'type': 'text',
      'status': _isOnline ? 'sent' : 'pending'
    };

    _messageController.clear();

    final docRef = await _firestore
        .collection('chats')
        .doc(_chatRoomId)
        .collection('messages')
        .add(message);

    final messageWithId = {
      ...message,
      'id': docRef.id,
    };

    if (_isOnline) {
      await _chatService.sendMessage(widget.receiverId, messageWithId);
    }
  }

  Future<void> _sendFile() async {
    if (!_isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot send files while offline')),
      );
      return;
    }

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();
      if (result == null) return;

      setState(() => _isLoading = true);

      final file = result.files.first;
      if (file.path == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No file path available')),
        );
        return;
      }

      final selectedFile = File(file.path!);
      final fileSize = await selectedFile.length();

      if (fileSize > 10 * 1024 * 1024) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File size must be less than 10MB')),
        );
        return;
      }

      final fileBytes = await selectedFile.readAsBytes();
      final fileBase64 = base64Encode(fileBytes);

      final fileMessage = {
        'type': 'file',
        'content': fileBase64,
        'filename': file.name,
        'sender_id': _chatService.userId,
        'receiver_id': widget.receiverId,
        'timestamp': DateTime.now().toIso8601String(),
        'fileSize': fileSize,
        'status': 'sent',
      };

      final docRef = await _firestore
          .collection('chats')
          .doc(_chatRoomId)
          .collection('messages')
          .add(fileMessage);

      final messageWithId = {
        ...fileMessage,
        'id': docRef.id,
      };

      setState(() {
        _messages.insert(0, messageWithId);
      });

      if (_isOnline) {
        await _chatService.sendMessage(widget.receiverId, messageWithId);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Error sending file'),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: _sendFile,
          ),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.receiverName,
              style: GoogleFonts.dmSans(
                  color: Colors.black,
                  fontSize: 22,
                  fontWeight: FontWeight.w500),
            ),
            if (_error != null)
              Text(
                'Offline',
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  color: Colors.red[300],
                ),
              )
            else
              Text(
                _isOnline ? 'Online' : 'Connecting...',
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  color: _isOnline ? Colors.green[300] : Colors.grey[300],
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_isOnline ? Icons.cloud_done : Icons.cloud_off),
            onPressed: _isOnline ? null : _setupChatService,
            color: _isOnline ? Colors.green : Colors.grey,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_error != null)
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.red[100],
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                  TextButton(
                    onPressed: _setupChatService,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _isLoading
                ? Center(
                    child: Center(
                        child: Text(
                    "Start chatting...",
                    style: GoogleFonts.dmSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w300,
                        color: Colors.black38),
                  )))
                : ListView.builder(
                    reverse: true,
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      return MessageBubble(
                        message: message,
                        isMe: message['sender_id'] == _chatService.userId,
                      );
                    },
                  ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.attach_file, size: 26, color: Colors.black),
            onPressed: _isLoading || !_isOnline ? null : _sendFile,
            color: _isOnline ? null : Colors.grey,
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                labelStyle: GoogleFonts.dmSans(),
                hintStyle: GoogleFonts.dmSans(),
                hintText: _isOnline ? 'Type a message...' : 'Connecting...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
              enabled: !_isLoading,
              minLines: 1,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.send,
              color: Colors.black,
              size: 24,
            ),
            onPressed: _isLoading ? null : _sendMessage,
            color: _messageController.text.trim().isEmpty
                ? Colors.grey
                : Theme.of(context).primaryColor,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _chatService.dispose();
    _messageController.dispose();
    super.dispose();
  }
}
