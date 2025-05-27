# **SyncApp: Cross-Platform File & Clipboard Sync**

SyncApp enables seamless synchronization of files and clipboard content between your desktop (Windows/Linux) and mobile device without requiring an internet connection. The desktop app (Python Tkinter) and mobile app (Flutter) communicate directly over a local hotspot, using QR codes for secure, instant pairing.

- Effortlessly transfer files and clipboard text between devices
- No Wi-Fi or internet required—works over a direct hotspot connection
- User-selectable sync folder on both desktop and mobile (default: `Downloads/sync-files`)
- Simple setup: scan a QR code to connect and start syncing
- Intuitive, user-friendly interfaces on both platforms
- Secure, local-only communication for privacy

---

## **Desktop Application (Python Tkinter)**

- **QR Code Generation**: Creates QR codes for mobile devices to scan
- **Hotspot Server**: Listens for mobile connections on the local network
- **File Transfer**: Send/receive files with progress tracking
- **Clipboard Sync**: Automatic bidirectional clipboard synchronization
- **Settings**: Configurable sync folder, port, and preferences
- **File Management**: Browse and manage sync folder contents

## **Mobile Application (Flutter)**

- **QR Scanner**: Scan desktop QR codes to establish connection
- **File Picker**: Select and send files to desktop
- **Clipboard Sync**: Manual and automatic clipboard synchronization
- **Settings**: Configure sync folder and app preferences
- **File Browser**: View received files in sync folder

## **Key Features**

### **Connection Process**

1. Desktop creates hotspot and starts server
2. Mobile connects to hotspot network
3. Mobile scans QR code to get connection details
4. Direct socket connection established
5. Bidirectional communication begins

### **Sync Capabilities**

- **Clipboard**: Real-time text synchronization
- **Files**: Send any file type between devices
- **Folders**: Organized storage in configurable sync directories
- **Progress Tracking**: Visual feedback for file transfers

### **Network Architecture**

- **No Internet Required**: Works entirely over local hotspot
- **Direct Socket Communication**: TCP connection with length-prefixed messages
- **JSON Protocol**: Structured message format for different operations
- **Auto-discovery**: QR code contains IP, port, and device info

## **Installation Requirements**

**Desktop (Python):**

```bash
pip install qrcode[pil] pillow pyperclip
```

**Mobile (Flutter):**

```yaml
dependencies:
  qr_code_scanner: ^1.0.1
  file_picker: ^5.5.0
  shared_preferences: ^2.2.2
  permission_handler: ^11.0.1
```

The solution provides a seamless way to sync files and clipboard content between desktop and mobile devices without requiring internet connectivity, using only a local hotspot connection. The apps handle connection management, file transfers, and real-time clipboard synchronization with a user-friendly interface on both platforms.
