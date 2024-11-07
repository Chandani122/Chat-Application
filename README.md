# Chat Application with Web Socket Programming

A real-time chat application built with Python, featuring both a server and a GUI client that supports text messaging and file sharing capabilities.

## Features

- Real-time text messaging
- File sharing functionality
- Graphical user interface for the client
- Multiple simultaneous connections
- User presence notifications (join/leave)
- Automatic file downloads
- Connection status indicators
- Simple and intuitive interface

## Prerequisites

- Python 3.6 or higher
- tkinter (usually comes with Python installation)
- Basic understanding of networking concepts

## Installation

1. Clone the repository or download the source files:
   ```bash
   git clone <repository-url>
   ```

2. Navigate to the project directory:
   ```bash
   cd python-chat-app
   ```

## Usage

### Starting the Server

1. Run the server script:
   ```bash
   python server.py
   ```
   The server will start listening on localhost (127.0.0.1) port 1234.

### Running the Client

1. Run the client script:
   ```bash
   python client.py
   ```

2. In the client GUI:
   - Enter your username
   - Click "Connect" to join the chat
   - Start sending messages or files

### Features Usage

#### Sending Messages
1. Type your message in the text input field
2. Press Enter or click the "Send" button

#### Sharing Files
1. Click the "Send File" button
2. Select the file you want to share
3. The file will be automatically sent to all connected users

## Project Structure

```
python-chat-app/
├── server.py          # Server implementation
├── client.py          # GUI client implementation
├── downloads/         # Client downloads directory
└── received_files/    # Server received files directory
```

## Technical Details

### Server
- Supports multiple concurrent connections using threading
- Handles both text messages and file transfers
- Maintains a list of active clients
- Broadcasts messages to all connected clients
- Saves received files in a 'received_files' directory

### Client
- GUI built with tkinter
- Supports file sharing with file picker dialog
- Automatic file downloads to 'downloads' directory
- Real-time message updates
- Connection status monitoring
- Error handling and reconnection capabilities

### Communication Protocol
- Messages are length-prefixed for reliable transmission
- JSON-based message format for both text and files
- Base64 encoding for file transfers
- Supports UTF-8 encoded messages

## Error Handling

The application includes handling for:
- Connection failures
- Disconnections
- Invalid messages
- File transfer errors
- JSON parsing errors

## Limitations

- Runs on localhost by default
- No message history persistence
- No encryption
- No user authentication
- Basic error recovery

## Future Improvements

Potential areas for enhancement:
1. Add message encryption
2. Implement user authentication
3. Add message history storage
4. Support for private messaging
5. Add file transfer progress indicators
6. Implement reconnection mechanism
7. Add server configuration options
8. Enhance UI/UX with themes and customization
9. Add support for emojis and rich text
10. Implement message delivery confirmation

## License

This project is licensed under the MIT License - see the LICENSE file for details.
