import 'package:flutter/material.dart';

class MessageBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isMe;

  const MessageBubble({super.key, required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.7,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            decoration: BoxDecoration(
              color: isMe ? Colors.blue : Colors.grey[300],
              borderRadius: BorderRadius.circular(20),
            ),
            child: _buildMessageContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageContent() {
    if (message['type'] == 'file') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.attachment),
          const SizedBox(height: 5),
          Text(
            message['filename'],
            style: TextStyle(
              color: isMe ? Colors.white : Colors.black,
            ),
          ),
        ],
      );
    }

    return Text(
      message['content'],
      style: TextStyle(
        color: isMe ? Colors.white : Colors.black,
      ),
    );
  }
}