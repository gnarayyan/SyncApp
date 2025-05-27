import tkinter as tk
from tkinter import ttk, filedialog, messagebox, scrolledtext
import socket
import threading
import json
import qrcode
from PIL import Image, ImageTk
import pyperclip
import os
import time
import base64
from datetime import datetime
import hashlib

class SyncDesktopApp:
    def __init__(self):
        self.root = tk.Tk()
        self.root.title("Desktop Sync App")
        self.root.geometry("800x600")
        self.root.configure(bg='#f0f0f0')
        
        # Configuration
        self.config_file = "sync_config.json"
        self.default_folder = os.path.join(os.path.expanduser("~"), "Downloads", "sync-files")
        self.config = self.load_config()
        
        # Network variables
        self.server_socket = None
        self.client_socket = None
        self.is_server_running = False
        self.connected_device = None
        self.server_thread = None
        
        # Ensure sync folder exists
        os.makedirs(self.config['sync_folder'], exist_ok=True)
        
        # Clipboard monitoring
        self.last_clipboard = ""
        self.clipboard_enabled = tk.BooleanVar(value=True)
        
        self.setup_ui()
        self.start_clipboard_monitor()
        
    def load_config(self):
        default_config = {
            'sync_folder': self.default_folder,
            'port': 8888,
            'auto_accept_files': False
        }
        
        try:
            if os.path.exists(self.config_file):
                with open(self.config_file, 'r') as f:
                    config = json.load(f)
                    # Ensure all default keys exist
                    for key, value in default_config.items():
                        if key not in config:
                            config[key] = value
                    return config
        except:
            pass
        
        return default_config
    
    def save_config(self):
        try:
            with open(self.config_file, 'w') as f:
                json.dump(self.config, f, indent=2)
        except Exception as e:
            messagebox.showerror("Error", f"Failed to save configuration: {e}")
    
    def setup_ui(self):
        # Main notebook for tabs
        notebook = ttk.Notebook(self.root)
        notebook.pack(fill='both', expand=True, padx=10, pady=10)
        
        # Connection Tab
        self.setup_connection_tab(notebook)
        
        # Files Tab
        self.setup_files_tab(notebook)
        
        # Settings Tab
        self.setup_settings_tab(notebook)
    
    def setup_connection_tab(self, notebook):
        conn_frame = ttk.Frame(notebook)
        notebook.add(conn_frame, text="Connection")
        
        # Status section
        status_frame = ttk.LabelFrame(conn_frame, text="Connection Status", padding=10)
        status_frame.pack(fill='x', padx=10, pady=5)
        
        self.status_label = ttk.Label(status_frame, text="Not Connected", 
                                     font=('Arial', 12, 'bold'))
        self.status_label.pack()
        
        self.device_label = ttk.Label(status_frame, text="")
        self.device_label.pack()
        
        # Control buttons
        control_frame = ttk.Frame(conn_frame)
        control_frame.pack(fill='x', padx=10, pady=5)
        
        self.start_btn = ttk.Button(control_frame, text="Start Hotspot Server", 
                                   command=self.start_server)
        self.start_btn.pack(side='left', padx=5)
        
        self.stop_btn = ttk.Button(control_frame, text="Stop Server", 
                                  command=self.stop_server, state='disabled')
        self.stop_btn.pack(side='left', padx=5)
        
        # QR Code section
        qr_frame = ttk.LabelFrame(conn_frame, text="QR Code for Mobile Connection", padding=10)
        qr_frame.pack(fill='both', expand=True, padx=10, pady=5)
        
        self.qr_label = ttk.Label(qr_frame, text="Start server to generate QR code")
        self.qr_label.pack(expand=True)
        
        # Clipboard section
        clip_frame = ttk.LabelFrame(conn_frame, text="Clipboard Sync", padding=10)
        clip_frame.pack(fill='x', padx=10, pady=5)
        
        ttk.Checkbutton(clip_frame, text="Enable Clipboard Sync", 
                       variable=self.clipboard_enabled).pack(anchor='w')
        
        clip_control = ttk.Frame(clip_frame)
        clip_control.pack(fill='x', pady=5)
        
        ttk.Button(clip_control, text="Send Clipboard", 
                  command=self.send_clipboard).pack(side='left', padx=5)
        
        ttk.Button(clip_control, text="Get Clipboard", 
                  command=self.request_clipboard).pack(side='left', padx=5)
    
    def setup_files_tab(self, notebook):
        files_frame = ttk.Frame(notebook)
        notebook.add(files_frame, text="Files")
        
        # File transfer section
        transfer_frame = ttk.LabelFrame(files_frame, text="File Transfer", padding=10)
        transfer_frame.pack(fill='x', padx=10, pady=5)
        
        ttk.Button(transfer_frame, text="Send File", 
                  command=self.send_file).pack(side='left', padx=5)
        
        ttk.Button(transfer_frame, text="Send Folder", 
                  command=self.send_folder).pack(side='left', padx=5)
        
        # Progress bar
        self.progress_var = tk.DoubleVar()
        self.progress_bar = ttk.Progressbar(transfer_frame, variable=self.progress_var, 
                                          maximum=100)
        self.progress_bar.pack(fill='x', pady=5)
        
        self.progress_label = ttk.Label(transfer_frame, text="")
        self.progress_label.pack()
        
        # File list section
        list_frame = ttk.LabelFrame(files_frame, text="Sync Folder Contents", padding=10)
        list_frame.pack(fill='both', expand=True, padx=10, pady=5)
        
        # Treeview for file list
        self.file_tree = ttk.Treeview(list_frame, columns=('size', 'modified'), show='tree headings')
        self.file_tree.heading('#0', text='Name')
        self.file_tree.heading('size', text='Size')
        self.file_tree.heading('modified', text='Modified')
        
        scrollbar = ttk.Scrollbar(list_frame, orient='vertical', command=self.file_tree.yview)
        self.file_tree.configure(yscrollcommand=scrollbar.set)
        
        self.file_tree.pack(side='left', fill='both', expand=True)
        scrollbar.pack(side='right', fill='y')
        
        # Refresh button
        ttk.Button(list_frame, text="Refresh", command=self.refresh_file_list).pack(pady=5)
        
        self.refresh_file_list()
    
    def setup_settings_tab(self, notebook):
        settings_frame = ttk.Frame(notebook)
        notebook.add(settings_frame, text="Settings")
        
        # Sync folder setting
        folder_frame = ttk.LabelFrame(settings_frame, text="Sync Folder", padding=10)
        folder_frame.pack(fill='x', padx=10, pady=5)
        
        self.folder_var = tk.StringVar(value=self.config['sync_folder'])
        folder_entry = ttk.Entry(folder_frame, textvariable=self.folder_var, width=50)
        folder_entry.pack(side='left', padx=5)
        
        ttk.Button(folder_frame, text="Browse", 
                  command=self.browse_folder).pack(side='left', padx=5)
        
        ttk.Button(folder_frame, text="Open Folder", 
                  command=self.open_sync_folder).pack(side='left', padx=5)
        
        # Port setting
        port_frame = ttk.LabelFrame(settings_frame, text="Network Settings", padding=10)
        port_frame.pack(fill='x', padx=10, pady=5)
        
        ttk.Label(port_frame, text="Port:").pack(side='left', padx=5)
        self.port_var = tk.StringVar(value=str(self.config['port']))
        port_entry = ttk.Entry(port_frame, textvariable=self.port_var, width=10)
        port_entry.pack(side='left', padx=5)
        
        # Auto-accept files
        ttk.Checkbutton(port_frame, text="Auto-accept incoming files", 
                       variable=tk.BooleanVar(value=self.config['auto_accept_files'])).pack(anchor='w', pady=5)
        
        # Save button
        ttk.Button(settings_frame, text="Save Settings", 
                  command=self.save_settings).pack(pady=10)
    
    def get_local_ip(self):
        try:
            # Connect to a remote address to determine local IP
            s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            s.connect(("8.8.8.8", 80))
            ip = s.getsockname()[0]
            s.close()
            return ip
        except:
            return "127.0.0.1"
    
    def generate_qr_code(self, ip, port):
        connection_info = {
            "ip": ip,
            "port": port,
            "device_name": socket.gethostname(),
            "timestamp": int(time.time())
        }
        
        qr_data = json.dumps(connection_info)
        
        qr = qrcode.QRCode(version=1, box_size=10, border=5)
        qr.add_data(qr_data)
        qr.make(fit=True)
        
        qr_image = qr.make_image(fill_color="black", back_color="white")
        qr_image = qr_image.resize((300, 300), Image.Resampling.LANCZOS)
        
        # Convert to PhotoImage for tkinter
        photo = ImageTk.PhotoImage(qr_image)
        self.qr_label.configure(image=photo)
        self.qr_label.image = photo  # Keep a reference
    
    def start_server(self):
        try:
            self.server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self.server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            
            ip = self.get_local_ip()
            port = int(self.port_var.get())
            
            self.server_socket.bind((ip, port))
            self.server_socket.listen(1)
            
            self.is_server_running = True
            self.server_thread = threading.Thread(target=self.accept_connections)
            self.server_thread.daemon = True
            self.server_thread.start()
            
            self.status_label.configure(text="Server Running", foreground="green")
            self.device_label.configure(text=f"Listening on {ip}:{port}")
            
            self.start_btn.configure(state='disabled')
            self.stop_btn.configure(state='normal')
            
            # Generate QR code
            self.generate_qr_code(ip, port)
            
        except Exception as e:
            messagebox.showerror("Error", f"Failed to start server: {e}")
    
    def stop_server(self):
        self.is_server_running = False
        
        if self.server_socket:
            self.server_socket.close()
            self.server_socket = None
        
        if self.client_socket:
            self.client_socket.close()
            self.client_socket = None
        
        self.status_label.configure(text="Not Connected", foreground="red")
        self.device_label.configure(text="")
        self.connected_device = None
        
        self.start_btn.configure(state='normal')
        self.stop_btn.configure(state='disabled')
        
        self.qr_label.configure(image='', text="Start server to generate QR code")
    
    def accept_connections(self):
        while self.is_server_running:
            try:
                client_socket, address = self.server_socket.accept()
                self.client_socket = client_socket
                
                # Receive device info
                data = client_socket.recv(1024).decode('utf-8')
                device_info = json.loads(data)
                self.connected_device = device_info.get('device_name', 'Unknown Device')
                
                self.root.after(0, self.update_connection_status)
                
                # Start message handler
                threading.Thread(target=self.handle_messages, daemon=True).start()
                break
                
            except Exception as e:
                if self.is_server_running:
                    print(f"Connection error: {e}")
                break
    
    def update_connection_status(self):
        self.status_label.configure(text="Connected", foreground="blue")
        self.device_label.configure(text=f"Connected to: {self.connected_device}")
    
    def handle_messages(self):
        while self.is_server_running and self.client_socket:
            try:
                # Receive message length first
                length_data = self.client_socket.recv(4)
                if not length_data:
                    break
                
                message_length = int.from_bytes(length_data, byteorder='big')
                
                # Receive the actual message
                message_data = b''
                while len(message_data) < message_length:
                    chunk = self.client_socket.recv(min(4096, message_length - len(message_data)))
                    if not chunk:
                        break
                    message_data += chunk
                
                if len(message_data) == message_length:
                    message = json.loads(message_data.decode('utf-8'))
                    self.process_message(message)
                
            except Exception as e:
                print(f"Message handling error: {e}")
                break
    
    def process_message(self, message):
        msg_type = message.get('type')
        
        if msg_type == 'clipboard':
            if self.clipboard_enabled.get():
                pyperclip.copy(message['data'])
                print("Clipboard updated from mobile device")
        
        elif msg_type == 'file':
            self.receive_file(message)
        
        elif msg_type == 'clipboard_request':
            self.send_clipboard()
    
    def send_message(self, message):
        if self.client_socket:
            try:
                message_data = json.dumps(message).encode('utf-8')
                length_data = len(message_data).to_bytes(4, byteorder='big')
                self.client_socket.send(length_data + message_data)
                return True
            except Exception as e:
                print(f"Failed to send message: {e}")
                return False
        return False
    
    def start_clipboard_monitor(self):
        def monitor():
            while True:
                try:
                    if self.clipboard_enabled.get() and self.client_socket:
                        current_clipboard = pyperclip.paste()
                        if current_clipboard != self.last_clipboard and current_clipboard.strip():
                            self.last_clipboard = current_clipboard
                            self.send_message({
                                'type': 'clipboard',
                                'data': current_clipboard
                            })
                except:
                    pass
                time.sleep(1)
        
        threading.Thread(target=monitor, daemon=True).start()
    
    def send_clipboard(self):
        try:
            clipboard_data = pyperclip.paste()
            if clipboard_data:
                self.send_message({
                    'type': 'clipboard',
                    'data': clipboard_data
                })
                messagebox.showinfo("Success", "Clipboard sent to mobile device")
        except Exception as e:
            messagebox.showerror("Error", f"Failed to send clipboard: {e}")
    
    def request_clipboard(self):
        self.send_message({'type': 'clipboard_request'})
    
    def send_file(self):
        file_path = filedialog.askopenfilename()
        if file_path:
            threading.Thread(target=self._send_file, args=(file_path,), daemon=True).start()
    
    def send_folder(self):
        folder_path = filedialog.askdirectory()
        if folder_path:
            threading.Thread(target=self._send_folder, args=(folder_path,), daemon=True).start()
    
    def _send_file(self, file_path):
        try:
            file_size = os.path.getsize(file_path)
            file_name = os.path.basename(file_path)
            
            self.root.after(0, lambda: self.progress_label.configure(text=f"Sending {file_name}..."))
            
            with open(file_path, 'rb') as f:
                file_data = base64.b64encode(f.read()).decode('utf-8')
            
            message = {
                'type': 'file',
                'name': file_name,
                'size': file_size,
                'data': file_data
            }
            
            if self.send_message(message):
                self.root.after(0, lambda: self.progress_label.configure(text=f"Sent {file_name}"))
            else:
                self.root.after(0, lambda: self.progress_label.configure(text="Failed to send file"))
                
        except Exception as e:
            self.root.after(0, lambda: messagebox.showerror("Error", f"Failed to send file: {e}"))
    
    def _send_folder(self, folder_path):
        # Implementation for sending entire folder (zip it first)
        import zipfile
        import tempfile
        
        try:
            folder_name = os.path.basename(folder_path)
            
            with tempfile.NamedTemporaryFile(suffix='.zip', delete=False) as tmp_file:
                with zipfile.ZipFile(tmp_file.name, 'w', zipfile.ZIP_DEFLATED) as zipf:
                    for root, dirs, files in os.walk(folder_path):
                        for file in files:
                            file_path = os.path.join(root, file)
                            arcname = os.path.relpath(file_path, folder_path)
                            zipf.write(file_path, arcname)
                
                self._send_file(tmp_file.name)
                os.unlink(tmp_file.name)
                
        except Exception as e:
            messagebox.showerror("Error", f"Failed to send folder: {e}")
    
    def receive_file(self, message):
        try:
            file_name = message['name']
            file_data = base64.b64decode(message['data'])
            
            # Save to sync folder
            file_path = os.path.join(self.config['sync_folder'], file_name)
            
            # Handle duplicate names
            counter = 1
            original_path = file_path
            while os.path.exists(file_path):
                name, ext = os.path.splitext(original_path)
                file_path = f"{name}_{counter}{ext}"
                counter += 1
            
            with open(file_path, 'wb') as f:
                f.write(file_data)
            
            self.root.after(0, lambda: messagebox.showinfo("File Received", 
                                                          f"Received: {os.path.basename(file_path)}"))
            self.root.after(0, self.refresh_file_list)
            
        except Exception as e:
            self.root.after(0, lambda: messagebox.showerror("Error", f"Failed to receive file: {e}"))
    
    def refresh_file_list(self):
        # Clear existing items
        for item in self.file_tree.get_children():
            self.file_tree.delete(item)
        
        try:
            sync_folder = self.config['sync_folder']
            if os.path.exists(sync_folder):
                for item in os.listdir(sync_folder):
                    item_path = os.path.join(sync_folder, item)
                    if os.path.isfile(item_path):
                        stat = os.stat(item_path)
                        size = f"{stat.st_size / 1024:.1f} KB"
                        modified = datetime.fromtimestamp(stat.st_mtime).strftime("%Y-%m-%d %H:%M")
                        self.file_tree.insert('', 'end', text=item, values=(size, modified))
        except Exception as e:
            print(f"Error refreshing file list: {e}")
    
    def browse_folder(self):
        folder = filedialog.askdirectory(initialdir=self.folder_var.get())
        if folder:
            self.folder_var.set(folder)
    
    def open_sync_folder(self):
        folder = self.config['sync_folder']
        if os.path.exists(folder):
            if os.name == 'nt':  # Windows
                os.startfile(folder)
            elif os.name == 'posix':  # macOS and Linux
                os.system(f'open "{folder}"' if os.uname().sysname == 'Darwin' else f'xdg-open "{folder}"')
    
    def save_settings(self):
        try:
            self.config['sync_folder'] = self.folder_var.get()
            self.config['port'] = int(self.port_var.get())
            
            # Create new sync folder if it doesn't exist
            os.makedirs(self.config['sync_folder'], exist_ok=True)
            
            self.save_config()
            messagebox.showinfo("Success", "Settings saved successfully!")
            
        except ValueError:
            messagebox.showerror("Error", "Port must be a valid number")
        except Exception as e:
            messagebox.showerror("Error", f"Failed to save settings: {e}")
    
    def run(self):
        try:
            self.root.mainloop()
        finally:
            self.stop_server()

if __name__ == "__main__":
    # Install required packages if not present
    try:
        import qrcode
        from PIL import Image, ImageTk
        import pyperclip
    except ImportError as e:
        print(f"Missing required package: {e}")
        print("Please install required packages:")
        print("pip install qrcode[pil] pillow pyperclip")
        exit(1)
    
    app = SyncDesktopApp()
    app.run()