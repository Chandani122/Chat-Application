import asyncio
import json
import firebase_admin
from firebase_admin import credentials, auth, db
from cryptography.fernet import Fernet
import os
from datetime import datetime
import base64
from dotenv import load_dotenv
from websockets.exceptions import ConnectionClosedError
from websockets.server import serve

load_dotenv()

cred = credentials.Certificate('serviceAccountKey.json')
firebase_admin.initialize_app(cred, {
    'databaseURL': os.getenv("DATABASE_URL")
})

ENCRYPTION_KEY = Fernet.generate_key()
cipher_suite = Fernet(ENCRYPTION_KEY)

connected_clients = {}

async def handle_authentication(websocket, data):
    """
    Handle client authentication using Firebase token
    """
    try:
        decoded_token = auth.verify_id_token(data['auth_token'])
        user_id = decoded_token['uid']
        
        connected_clients[user_id] = websocket
        
        return {
            'type': 'auth_response',
            'success': True,
            'user_id': user_id
        }
    except Exception as e:
        print(f"Authentication error: {str(e)}")
        return {
            'type': 'auth_response',
            'success': False,
            'error': str(e)
        }

async def store_message(sender_id, receiver_id, message_data, message_type='text'):
    try:
        encrypted_content = cipher_suite.encrypt(json.dumps(message_data).encode())
        
        chat_ids = sorted([sender_id, receiver_id])
        chat_room_id = f"{chat_ids[0]}_{chat_ids[1]}"
        
        message = {
            'sender_id': sender_id,
            'receiver_id': receiver_id,
            'content': base64.b64encode(encrypted_content).decode(),
            'type': message_type,
            'timestamp': datetime.now().isoformat()
        }
        
        chat_ref = db.reference(f'chats/{chat_room_id}/messages')
        message_ref = chat_ref.push(message)
        
        return {**message, 'message_id': message_ref.key}
    except Exception as e:
        print(f"Error storing message: {str(e)}")
        raise

async def handle_file_message(websocket, data):
    try:
        sender_id = data.get('sender_id')
        receiver_id = data.get('receiver_id')
        file_content = data.get('file_content')
        filename = data.get('filename')
        
        if not all([sender_id, receiver_id, file_content, filename]):
            raise ValueError("Missing required file data")

        try:
            file_data = base64.b64decode(file_content)
            encrypted_file = cipher_suite.encrypt(file_data)
        except Exception as e:
            raise ValueError(f"Invalid file content: {str(e)}")

        chat_ids = sorted([sender_id, receiver_id])
        chat_room_id = f"{chat_ids[0]}_{chat_ids[1]}"
        
        file_message = {
            'sender_id': sender_id,
            'receiver_id': receiver_id,
            'filename': filename,
            'content': base64.b64encode(encrypted_file).decode(),
            'timestamp': datetime.now().isoformat(),
            'type': 'file'
        }
        
        chat_ref = db.reference(f'chats/{chat_room_id}/messages')
        message_ref = chat_ref.push(file_message)
        
        if receiver_id in connected_clients:
            notification = {
                'type': 'file',
                'sender_id': sender_id,
                'receiver_id': receiver_id,
                'filename': filename,
                'message_id': message_ref.key,
                'timestamp': file_message['timestamp']
            }
            await connected_clients[receiver_id].send(json.dumps(notification))
        
        return True
        
    except Exception as e:
        print(f"Error handling file message: {str(e)}")
        await websocket.send(json.dumps({
            'type': 'error',
            'message': f"File processing failed: {str(e)}"
        }))
        return False

async def handle_message(websocket, data):
    try:
        if data['type'] == 'authentication':
            response = await handle_authentication(websocket, data)
            await websocket.send(json.dumps(response))
        
        elif data['type'] == 'message':
            message = await store_message(
                data['sender_id'],
                data['receiver_id'],
                data['content']
            )
            
            if data['receiver_id'] in connected_clients:
                await connected_clients[data['receiver_id']].send(
                    json.dumps({
                        'type': 'message',
                        'content': message
                    })
                )
        
        elif data['type'] == 'file':
            success = await handle_file_message(websocket, data)
            await websocket.send(json.dumps({
                'type': 'file_response',
                'success': success
            }))
            
    except Exception as e:
        print(f"Error handling message: {str(e)}")
        await websocket.send(json.dumps({
            'type': 'error',
            'message': str(e)
        }))

async def websocket_handler(websocket):
    try:
        print("New client connected")
        async for message in websocket:
            try:
                data = json.loads(message)
                await handle_message(websocket, data)
            except json.JSONDecodeError:
                print("Invalid JSON received")
                await websocket.send(json.dumps({
                    'type': 'error',
                    'message': 'Invalid JSON format'
                }))
    except ConnectionClosedError:
        print("Client connection closed")
    except Exception as e:
        print(f"WebSocket handler error: {str(e)}")
    finally:
        for user_id, ws in list(connected_clients.items()):
            if ws == websocket:
                del connected_clients[user_id]
                print(f"Cleaned up connection for user {user_id}")
                break

async def main():
    port = int(os.environ.get("PORT", 8765))
    
    print(f"Starting WebSocket server on port {port}")
    
    async with serve(
        websocket_handler,
        "0.0.0.0",
        port,
        ping_interval=20,
        ping_timeout=20,
        close_timeout=20,
        compression=None 
    ) as server:
        print(f"WebSocket server is running on port {port}")
        await asyncio.Future()

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except Exception as e:
        print(f"Server error: {str(e)}")