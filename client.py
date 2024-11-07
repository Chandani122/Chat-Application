import socket
import threading
import tkinter as tk
from tkinter import ttk, messagebox, scrolledtext, filedialog
import json
import base64
import os
import datetime

class ChatClientGUI:
    def __init__(self):
        self.HOST = '127.0.0.1'
        self.PORT = 1234
        
        self.root = tk.Tk()
        self.root.title("Chat Application")
        self.root.geometry("800x600")
        self.root.minsize(600, 400)
        
        self.style = ttk.Style()
        self.style.configure('Messages.TFrame', background='#f0f0f0')
        self.style.configure('Controls.TFrame', background='#e0e0e0')
        
        # Create downloads directory
        self.downloads_dir = "downloads"
        os.makedirs(self.downloads_dir, exist_ok=True)
        
        self.create_widgets()
        self.client = None
        self.connected = False
        
    def create_widgets(self):
        main_container = ttk.Frame(self.root)
        main_container.pack(fill=tk.BOTH, expand=True, padx=10, pady=10)
        
        # Connection frame
        connection_frame = ttk.Frame(main_container)
        connection_frame.pack(fill=tk.X, pady=(0, 10))
        
        username_label = ttk.Label(connection_frame, text="Username:")
        username_label.pack(side=tk.LEFT, padx=(0, 5))
        
        self.username_var = tk.StringVar()
        self.username_entry = ttk.Entry(connection_frame, textvariable=self.username_var)
        self.username_entry.pack(side=tk.LEFT, padx=(0, 10))
        
        self.connect_btn = ttk.Button(connection_frame, text="Connect", command=self.connect_to_server)
        self.connect_btn.pack(side=tk.LEFT)
        
        # Chat area
        chat_frame = ttk.Frame(main_container, style='Messages.TFrame')
        chat_frame.pack(fill=tk.BOTH, expand=True)
        
        self.messages_area = scrolledtext.ScrolledText(
            chat_frame,
            wrap=tk.WORD,
            height=20,
            font=('Arial', 10),
            background='#ffffff',
            borderwidth=1,
            relief="solid"
        )
        self.messages_area.pack(fill=tk.BOTH, expand=True, padx=5, pady=5)
        self.messages_area.config(state=tk.DISABLED)
        
        # Controls frame
        controls_frame = ttk.Frame(main_container, style='Controls.TFrame')
        controls_frame.pack(fill=tk.X, pady=(10, 0))
        
        # File upload button
        self.file_btn = ttk.Button(
            controls_frame,
            text="Send File",
            command=self.send_file,
            state=tk.DISABLED
        )
        self.file_btn.pack(side=tk.LEFT, padx=(0, 10))
        
        # Message input
        self.message_var = tk.StringVar()
        self.message_entry = ttk.Entry(controls_frame, textvariable=self.message_var)
        self.message_entry.pack(side=tk.LEFT, fill=tk.X, expand=True, padx=(0, 10))
        self.message_entry.bind('<Return>', lambda e: self.send_message())
        self.message_entry.config(state=tk.DISABLED)
        
        # Send button
        self.send_btn = ttk.Button(
            controls_frame,
            text="Send",
            command=self.send_message,
            state=tk.DISABLED
        )
        self.send_btn.pack(side=tk.RIGHT)

    def connect_to_server(self):
        username = self.username_var.get().strip()
        if not username:
            messagebox.showerror("Error", "Username cannot be empty!")
            return
            
        self.client = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        
        try:
            self.client.connect((self.HOST, self.PORT))
            self.connected = True
            
            # Send only username for initial connection
            self.send_message_to_server(username)
            
            threading.Thread(target=self.listen_for_messages, daemon=True).start()
            
            self.username_entry.config(state=tk.DISABLED)
            self.connect_btn.config(state=tk.DISABLED)
            self.message_entry.config(state=tk.NORMAL)
            self.send_btn.config(state=tk.NORMAL)
            self.file_btn.config(state=tk.NORMAL)
            
            self.add_message("System", "Connected to server successfully!")
            
        except Exception as e:
            messagebox.showerror("Connection Error", f"Unable to connect to server: {str(e)}")

    def send_message_to_server(self, message):
        try:
            # If message is a string, encode it directly
            if isinstance(message, str):
                message_bytes = message.encode('utf-8')
            # If message is a dictionary, convert to JSON first
            else:
                message_bytes = json.dumps(message).encode('utf-8')
                
            message_length = len(message_bytes).to_bytes(8, byteorder='big')
            self.client.sendall(message_length + message_bytes)
        except Exception as e:
            print(f"Error sending message: {str(e)}")
            self.handle_disconnect()

    def receive_message_with_length(self):
        try:
            message_length_bytes = self.client.recv(8)
            if not message_length_bytes:
                return None
            
            message_length = int.from_bytes(message_length_bytes, byteorder='big')
            
            chunks = []
            bytes_received = 0
            while bytes_received < message_length:
                chunk = self.client.recv(min(2048, message_length - bytes_received))
                if not chunk:
                    return None
                chunks.append(chunk)
                bytes_received += len(chunk)
            
            return b''.join(chunks).decode('utf-8')
        except:
            return None

    def listen_for_messages(self):
        while self.connected:
            message = self.receive_message_with_length()
            if not message:
                self.handle_disconnect()
                break
                
            try:
                # Try to parse as JSON first
                try:
                    message_data = json.loads(message)
                    if message_data['type'] == 'file':
                        self.handle_file_message(message_data)
                    else:
                        self.add_message(message_data['username'], message_data['content'])
                # If not JSON, treat as server message with ~ separator
                except json.JSONDecodeError:
                    if '~' in message:
                        username, content = message.split('~', 1)
                        self.add_message(username, content)
                    else:
                        self.add_message("System", message)
            
            except Exception as e:
                print(f"Error processing message: {str(e)}")

    def handle_file_message(self, message_data):
        sender = message_data['username']
        filename = message_data['filename']
        file_data = base64.b64decode(message_data['data'].encode('utf-8'))
        
        # Save the file
        file_path = os.path.join(self.downloads_dir, filename)
        with open(file_path, 'wb') as file:
            file.write(file_data)
        
        self.add_message("System", f"Received file from {sender}: {filename}")
        self.add_message("System", f"File saved in {self.downloads_dir} folder")

    def send_message(self):
        message = self.message_var.get().strip()
        if message and self.connected:
            try:
                message_data = {
                    'type': 'text',
                    'username': self.username_var.get(),
                    'content': message
                }
                self.send_message_to_server(json.dumps(message_data))
                self.message_var.set("")
            except:
                messagebox.showerror("Error", "Failed to send message")
                self.handle_disconnect()

    def send_file(self):
        if not self.connected:
            return
            
        file_path = filedialog.askopenfilename()
        if file_path:
            try:
                filename = os.path.basename(file_path)
                file_data = base64.b64encode(open(file_path, 'rb').read()).decode('utf-8')
                
                message_data = {
                    'type': 'file',
                    'username': self.username_var.get(),
                    'filename': filename,
                    'data': file_data
                }
                
                self.send_message_to_server(json.dumps(message_data))
                self.add_message("System", f"File sent: {filename}")
                
            except Exception as e:
                messagebox.showerror("Error", f"Failed to send file: {str(e)}")

    def add_message(self, username, content):
        self.messages_area.config(state=tk.NORMAL)
        timestamp = datetime.datetime.now().strftime("%H:%M:%S")
        message = f"[{timestamp}] {username}: {content}\n"
        self.messages_area.insert(tk.END, message)
        self.messages_area.see(tk.END)
        self.messages_area.config(state=tk.DISABLED)

    def handle_disconnect(self):
        self.connected = False
        self.client.close()
        self.username_entry.config(state=tk.NORMAL)
        self.connect_btn.config(state=tk.NORMAL)
        self.message_entry.config(state=tk.DISABLED)
        self.send_btn.config(state=tk.DISABLED)
        self.file_btn.config(state=tk.DISABLED)
        self.add_message("System", "Disconnected from server")

    def run(self):
        self.root.mainloop()
        if self.client:
            self.client.close()

if __name__ == '__main__':
    app = ChatClientGUI()
    app.run()
