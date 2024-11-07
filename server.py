import socket
import threading
import os
import json
import base64

HOST = '127.0.0.1'
PORT = 1234
LISTENER_LIMIT = 5
active_clients = []  # List of all currently connected users

def encode_file_data(file_path):
    with open(file_path, 'rb') as file:
        return base64.b64encode(file.read()).decode('utf-8')

def decode_file_data(base64_data):
    return base64.b64decode(base64_data.encode('utf-8'))

def create_file_message(username, filename, file_data):
    message = {
        'type': 'file',
        'username': username,
        'filename': filename,
        'data': file_data
    }
    return json.dumps(message)

def create_text_message(username, content):
    message = {
        'type': 'text',
        'username': username,
        'content': content
    }
    return json.dumps(message)

def send_message_to_client(client, message):
    try:
        message_length = len(message).to_bytes(8, byteorder='big')
        client.sendall(message_length + message.encode('utf-8'))
    except Exception as e:
        print(f"Error sending message: {str(e)}")
        remove_client(client)

def send_messages_to_all(message):
    disconnected_clients = []
    for user in active_clients:
        try:
            send_message_to_client(user[1], message)
        except:
            disconnected_clients.append(user)
    
    # Remove disconnected clients
    for client in disconnected_clients:
        remove_client(client[1])

def remove_client(client):
    for user in active_clients:
        if user[1] == client:
            active_clients.remove(user)
            username = user[0]
            system_message = create_text_message("SERVER", f"{username} left the chat")
            send_messages_to_all(system_message)
            break

def receive_message_with_length(client):
    try:
        # First receive the message length (8 bytes)
        message_length_bytes = client.recv(8)
        if not message_length_bytes:
            return None
        
        message_length = int.from_bytes(message_length_bytes, byteorder='big')
        
        # Now receive the actual message
        chunks = []
        bytes_received = 0
        while bytes_received < message_length:
            chunk = client.recv(min(2048, message_length - bytes_received))
            if not chunk:
                return None
            chunks.append(chunk)
            bytes_received += len(chunk)
        
        return b''.join(chunks).decode('utf-8')
    except:
        return None

def listen_for_messages(client, username):
    while True:
        message = receive_message_with_length(client)
        if not message:
            remove_client(client)
            break
        
        try:
            message_data = json.loads(message)
            
            if message_data['type'] == 'file':
                # Save the file in a 'received_files' directory
                os.makedirs('received_files', exist_ok=True)
                
                filename = message_data['filename']
                file_data = decode_file_data(message_data['data'])
                
                # Save the file
                file_path = os.path.join('received_files', filename)
                with open(file_path, 'wb') as file:
                    file.write(file_data)
                
                # Notify all clients about the file
                notification = create_text_message(
                    "SERVER",
                    f"{username} shared a file: {filename}"
                )
                send_messages_to_all(notification)
                
                # Forward the file to all other clients
                send_messages_to_all(message)
            
            elif message_data['type'] == 'text':
                send_messages_to_all(message)
        
        except json.JSONDecodeError:
            print(f"Invalid message format from {username}")
        except Exception as e:
            print(f"Error processing message from {username}: {str(e)}")

def client_handler(client):
    while True:
        username = receive_message_with_length(client)
        if username:
            active_clients.append((username, client))
            welcome_message = create_text_message("SERVER", f"{username} joined the chat")
            send_messages_to_all(welcome_message)
            break
        else:
            print("Client username is empty")
            return

    threading.Thread(target=listen_for_messages, args=(client, username,)).start()

def main():
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    
    try:
        server.bind((HOST, PORT))
        print(f"Running the server on {HOST} {PORT}")
    except:
        print(f"Unable to bind to host {HOST} and port {PORT}")
        return

    server.listen(LISTENER_LIMIT)
    
    while True:
        client, address = server.accept()
        print(f"Successfully connected to client {address[0]} {address[1]}")
        threading.Thread(target=client_handler, args=(client,)).start()

if __name__ == '__main__':
    main()
