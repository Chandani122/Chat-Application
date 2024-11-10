import asyncio
import websockets
import json
import firebase_admin
from firebase_admin import credentials, auth, db
from cryptography.fernet import Fernet
import os
from datetime import datetime
import base64
from dotenv import load_dotenv

load_dotenv()

cred = credentials.Certificate('serviceAccountKey.json')
firebase_admin.initialize_app(cred, {
    'databaseURL': os.getenv("DATABASE_URL")
})

ENCRYPTION_KEY = Fernet.generate_key()
cipher_suite = Fernet(ENCRYPTION_KEY)

connected_clients = {} 

async def handle_authentication(websocket, data):
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
        return {
            'type': 'auth_response',
            'success': False,
            'error': str(e)
        }

async def store_message(sender_id, receiver_id, message_data, message_type='text'):
    encrypted_content = cipher_suite.encrypt(json.dumps(message_data).encode())
    
    message = {
        'sender_id': sender_id,
        'receiver_id': receiver_id,
        'content': base64.b64encode(encrypted_content).decode(),
        'type': message_type,
        'timestamp': datetime.now().isoformat()
    }
    
    chat_ref = db.reference(f'chats/{sender_id}/{receiver_id}')
    chat_ref.push(message)
    
    return message

async def handle_file_message(websocket, data):
    try:
        sender_id = data['sender_id']
        receiver_id = data['receiver_id']
        file_data = base64.b64decode(data['file_content'])
        
        encrypted_file = cipher_suite.encrypt(file_data)
        
        file_ref = db.reference(f'files/{sender_id}/{receiver_id}')
        file_message = {
            'filename': data['filename'],
            'content': base64.b64encode(encrypted_file).decode(),
            'timestamp': datetime.now().isoformat()
        }
        file_ref.push(file_message)
        
        if receiver_id in connected_clients:
            await connected_clients[receiver_id].send(json.dumps({
                'type': 'file',
                'sender_id': sender_id,
                'filename': data['filename'],
                'timestamp': datetime.now().isoformat()
            }))
        
        return True
    except Exception as e:
        print(f"Error handling file: {str(e)}")
        return False

async def handle_message(websocket, data):
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

async def websocket_handler(websocket, path):
    try:
        async for message in websocket:
            data = json.loads(message)
            await handle_message(websocket, data)
    except websockets.exceptions.ConnectionClosed:
        for user_id, ws in connected_clients.items():
            if ws == websocket:
                del connected_clients[user_id]
                break
    except Exception as e:
        print(f"Error: {str(e)}")

async def main():
    port = int(os.environ.get("PORT", 8765))
    async with websockets.serve(websocket_handler, "0.0.0.0", port) as server:
        print(f"WebSocket server is running on port {port}")
        await asyncio.Future()  # run forever

if __name__ == "__main__":
    asyncio.run(main())