import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import '../services/chat_service.dart';
import 'message.dart';

class GroupChatScreen extends StatefulWidget {
  const GroupChatScreen({Key? key}) : super(key: key);

  @override
  _GroupChatScreenState createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _messageController = TextEditingController();
  final ChatService _chatService = ChatService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeChatService();
  }

  Future<void> _initializeChatService() async {
    final user = _auth.currentUser;
    if (user != null) {
      final token = await user.getIdToken();
      await _chatService.connect(token!);
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final User? user = _auth.currentUser;
    if (user != null) {
      final message = {
        'text': _messageController.text.trim().isNotEmpty
            ? _messageController.text
            : 'No content',
        'senderId': user.uid,
        'senderName': '',
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'text'
      };

      await _firestore.collection('group_chat').add(message);
      await _chatService.sendMessage('general_chat', message);
      _messageController.clear();
    }
  }

  Future<void> _sendFile() async {
    setState(() => _isLoading = true);

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();
      if (result == null) return;

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

      final User? user = _auth.currentUser;
      if (user == null) return;

      final fileBytes = await selectedFile.readAsBytes();
      final fileBase64 = base64Encode(fileBytes);

      final fileMessage = {
        'type': 'file',
        'content': fileBase64.isNotEmpty ? fileBase64 : 'No content',
        'filename': file.name,
        'senderId': user.uid,
        'senderName': user.displayName ?? 'User',
        'timestamp': FieldValue.serverTimestamp(),
        'fileSize': fileSize,
      };

      await _firestore.collection('group_chat').add(fileMessage);
      await _chatService.sendMessage('general_chat', fileMessage);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending file: $e')),
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
        title: Text('Group Chat',
            style: GoogleFonts.dmSans(
                color: Colors.black,
                fontSize: 24,
                fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('group_chat')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!.docs;

                return ListView.builder(
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final messageData =
                        messages[index].data() as Map<String, dynamic>;
                    final currentUser = _auth.currentUser;
                    final isMe = currentUser != null &&
                        messageData['senderId'] == currentUser.uid;

                    return FutureBuilder<DocumentSnapshot>(
                      future: _firestore
                          .collection('users')
                          .doc(messageData['senderId'])
                          .get(),
                      builder: (context, userSnapshot) {
                        if (!userSnapshot.hasData) {
                          return const SizedBox
                              .shrink();
                        }

                        final senderUsername =
                            userSnapshot.data!.get('username') ??
                                'Unknown User';

                        return MessageBubble(
                          message: {
                            ...messageData,
                            'id': messages[index].id,
                            'content': messageData['type'] == 'text'
                                ? (messageData['text'] ?? 'No content')
                                : (messageData['content'] ?? 'No content'),
                          },
                          isMe: isMe,
                          senderUsername: isMe ? 'You' : senderUsername,
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
          if (_isLoading) const LinearProgressIndicator(),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.attach_file,
                      size: 26, color: Colors.black),
                  onPressed: _isLoading ? null : _sendFile,
                  color: Colors.black,
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      labelStyle: GoogleFonts.dmSans(),
                      hintStyle: GoogleFonts.dmSans(),
                      hintText: 'Type a message...',
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
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _chatService.dispose();
    super.dispose();
  }
}
