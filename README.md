# Secure Real-Time Chat Application

## Overview

This project is a secure, real-time chat application developed using Flutter for the frontend, Firebase for authentication and data storage, and Render for cloud hosting. The application allows users to send individual and group messages, transfer files securely, and interact in a real-time, encrypted communication environment.

### Key Features:
- **Real-time Messaging**: Fast, secure chat between users with WebSocket communication.
- **Authentication**: Firebase email and password login with encrypted credentials.
- **Data Encryption**: End-to-end encryption for messages and files.
- **File Transfer**: Secure file transfer functionality.
- **Cloud Storage**: Firebase Firestore stores user data, messages, and media securely.

## Technologies Used

- **Flutter**: Open-source UI SDK for building natively compiled applications for mobile, web, and desktop.
- **Firebase**: Cloud-based platform providing tools for user authentication, database management, and storage.
- **Firestore**: NoSQL cloud database used for real-time data synchronization and storage.
- **Render**: Cloud platform for hosting the server and ensuring global connectivity.
- **WebSocket**: WebSocket protocol for real-time, bidirectional communication between clients and server.

## Architecture

### Client-Server Model
- **Server Side**: The server listens for incoming connections, binding to a specific IP address and port. It facilitates communication by receiving messages from clients and sending responses.
- **Client Side**: Each client connects to the server using a WebSocket connection, which enables real-time messaging.

### Communication Flow
1. **Login/Authentication**: Users log in via Firebase Authentication using their email and password. Credentials are encrypted for security.
2. **Real-time Messaging**: The client sends messages using WebSocket, which are encrypted and stored in Firestore with metadata (sender, receiver, timestamp).
3. **File Transfer**: Files are encrypted before being uploaded to Firebase Storage and associated with the corresponding chat messages.

## Setup

### Prerequisites

- Flutter SDK installed on your system.
- Firebase account and Firestore database setup.
- Render account for cloud hosting.
- A valid email address for Firebase Authentication.

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/Chandani122/Chat-Application.git
   cd secure-chat-app
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Set up Firebase:
   - Create a Firebase project.
   - Add Firebase Authentication and Firestore services.
   - Configure your Firebase project by following the instructions for Flutter.

4. Set up Render:
   - Create an account on Render and deploy your backend server.
   - Link the server with your Flutter frontend.

5. Configure the necessary Firebase keys and URLs in your app's environment configuration.

## Features

### 1. User Authentication
- **Login**: Users can log in using their email and password.
- **Encryption**: User credentials are encrypted for added security.

### 2. Real-time Chat
- **WebSocket Communication**: Messages are sent and received in real-time using WebSocket, allowing for a smooth chat experience.
- **Individual and Group Chats**: Support for one-on-one messaging and group chat rooms.

### 3. Data Encryption
- **End-to-End Encryption**: All messages and files are encrypted both in transit and at rest.
- **Secure File Upload**: Files are encrypted before being uploaded to Firebase Storage.

### 4. Firebase Integration
- **Firestore**: Stores user data, messages, and media securely.
- **Real-Time Synchronization**: Any changes to data are immediately synced with all connected clients.

## How It Works

### 1. Client-Server Communication
- The Flutter frontend communicates with the server using the `web_socket_channel` package for WebSocket connections.
- When a user sends a message, the message is encrypted before being transmitted to the server.
- The server processes the message and stores it in Firestore, along with metadata like sender and receiver IDs, timestamps, and message type.

### 2. Firebase Authentication
- Users log in via Firebase Authentication. The email and password are securely hashed before being stored.
- Upon successful authentication, users are granted access to their chat rooms.

### 3. Firestore Database
- All user-related data (username, email) is stored in Firestore, where each user is assigned a unique ID.
- Messages and files are stored securely in Firestore, with encryption ensuring privacy.

## Real-Time Applications

This secure chat application can be adapted for a variety of use cases:
- **Instant Messaging Platforms**: For personal and professional communication.
- **Customer Support**: Secure channels for customer support chatbots.
- **Remote Collaboration**: Real-time communication for teams.
- **Healthcare & Counseling**: Ensures confidentiality and privacy for medical or counseling services.

## Conclusion

This project demonstrates a real-time, secure chat application leveraging modern cloud technologies like Firebase and Render. By combining Flutter for frontend development and WebSocket for real-time messaging, it provides a scalable and efficient communication platform. Data encryption ensures the privacy and security of messages and files, making it a robust solution for secure messaging.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.