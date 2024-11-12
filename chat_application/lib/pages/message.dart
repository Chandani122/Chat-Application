import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as path;

class MessageBubble extends StatefulWidget {
  final String? senderUsername;
  final Map<String, dynamic> message;
  final bool isMe;

  const MessageBubble(
      {super.key,
      required this.message,
      this.senderUsername,
      required this.isMe});

  @override
  _MessageBubbleState createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  String _downloadPath = '';
  bool _showDownloadPathPopup = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
      child: Column(
        crossAxisAlignment:
            widget.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (widget.senderUsername != null)
            Padding(
              padding: const EdgeInsets.only(left: 10, bottom: 5, right: 10),
              child: Text(
                widget.senderUsername!,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
          Stack(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5.0),
                child: Row(
                  mainAxisAlignment: widget.isMe
                      ? MainAxisAlignment.end
                      : MainAxisAlignment.start,
                  children: [
                    Container(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.8,
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 15, vertical: 10),
                      decoration: BoxDecoration(
                        color: widget.isMe ? Colors.blue : Colors.grey[700],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: _buildMessageContent(context),
                    ),
                  ],
                ),
              ),
              if (_showDownloadPathPopup)
                Positioned(
                  bottom: 10,
                  left: 0,
                  right: 0,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          'File downloaded to: $_downloadPath',
                          style: GoogleFonts.dmSans(
                            fontSize: 14,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessageContent(BuildContext context) {
    if (widget.message['type'] == 'file') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.attachment, color: Colors.white),
              const SizedBox(width: 5),
              Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.6,
                ),
                child: Text(
                  widget.message['filename'],
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          GestureDetector(
              onTap: () async {
                await _openFile(widget.message['content'],
                    widget.message['filename'], context);
              },
              child: Text('Open',
                  style: GoogleFonts.dmSans(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold))),
        ],
      );
    }

    return Text(
      widget.message['content'],
      style: GoogleFonts.dmSans(
          color: Colors.white, fontSize: 16, fontWeight: FontWeight.w400),
    );
  }

  Future<void> _openFile(
      String base64Content, String filename, BuildContext context) async {
    try {
      Uint8List fileBytes = base64Decode(base64Content);

      final downloadsDir = (await getExternalStorageDirectory())?.path ??
          (await getApplicationDocumentsDirectory()).path;
      final filePath = path.join(downloadsDir, filename);

      final file = File(filePath);
      await file.writeAsBytes(fileBytes);

      setState(() {
        _downloadPath = filePath;
        _showDownloadPathPopup = true;
      });

      final result = await OpenFilex.open(filePath);
      if (result.type != ResultType.done) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open file')),
        );
      }

      await Future.delayed(const Duration(seconds: 3), () {
        setState(() {
          _showDownloadPathPopup = false;
        });
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to open file')),
      );
    }
  }
}
