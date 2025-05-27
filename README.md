# SyncApp: Cross-Platform File & Clipboard Sync

SyncApp enables seamless, secure synchronization of files and clipboard content between your desktop (Windows/Linux/macOS) and mobile device (Android/iOS) **without requiring an internet connection**. The desktop app (Python Tkinter) and mobile app (Flutter) communicate directly over a local hotspot, using QR codes for instant, secure pairing.

---

## 🚀 Features

- **Effortless File & Clipboard Sync:** Instantly transfer files and clipboard text between devices.
- **No Internet Required:** Works over a direct local hotspot connection.
- **Configurable Sync Folders:** Choose your sync folder on both desktop and mobile (`Downloads/sync-files` by default).
- **Simple Setup:** Scan a QR code to connect and start syncing.
- **User-Friendly Interfaces:** Intuitive UI on both desktop and mobile.
- **Secure, Local-Only Communication:** No data leaves your local network.

---

## 🖥️ Desktop Application (Python Tkinter)

- **QR Code Generation:** For secure, instant pairing.
- **Hotspot Server:** Listens for mobile connections on your local network.
- **File Transfer:** Send/receive files with progress tracking.
- **Clipboard Sync:** Automatic, bidirectional clipboard synchronization.
- **Settings:** Configure sync folder, port, and preferences.
- **File Management:** Browse and manage sync folder contents.

## 📱 Mobile Application (Flutter)

- **QR Scanner:** Scan desktop QR codes to connect.
- **File Picker:** Select and send files to desktop.
- **Clipboard Sync:** Manual and automatic clipboard synchronization.
- **Settings:** Configure sync folder and app preferences.
- **File Browser:** View received files in sync folder.

---

## 🔗 How It Works

1. **Desktop** creates a hotspot and starts the server.
2. **Mobile** connects to the hotspot.
3. **Mobile** scans the desktop's QR code to get connection details.
4. **Direct socket connection** is established.
5. **Bidirectional communication** begins for file and clipboard sync.

**Network Architecture:**

- No internet required—local hotspot only.
- Direct TCP socket communication (length-prefixed messages).
- JSON protocol for structured operations.
- QR code contains IP, port, and device info for auto-discovery.

---

# 🛠️ Setup Guide

## Desktop Application (Python Tkinter)

### Prerequisites

- Python 3.7+
- pip

### Installation

```bash
pip install tkinter qrcode[pil] pillow pyperclip
```

1. Save the provided Python code as `desktop_sync_app.py`.
2. Run the app:

```bash
python desktop_sync_app.py
```

### Key Tabs

- **Connection:** Start hotspot server, generate QR code.
- **Files:** Send/receive files, view sync folder.
- **Settings:** Configure folder, port, preferences.
- **Clipboard:** Automatic bidirectional sync.

---

## Mobile Application (Flutter)

### Prerequisites

- Flutter SDK (3.0.0+)
- Android Studio or VS Code with Flutter extensions
- Android/iOS device or emulator

### Installation

```bash
flutter create mobile_sync_app
cd mobile_sync_app
```

1. Replace `pubspec.yaml` and `lib/main.dart` with provided code.
2. Update `AndroidManifest.xml` as needed.
3. Install dependencies:

```bash
flutter pub get
```

4. Build and run:

```bash
flutter run
```

### Key Tabs

- **Connect:** Scan QR code to connect.
- **Clipboard:** Manual/automatic clipboard sync.
- **Files:** Send/view files.
- **Settings:** Configure folder and preferences.

---

# 📖 Usage

### 1. Setup Desktop Hotspot

- Enable hotspot on your desktop/laptop.
- Note the network name and password.

### 2. Connect Mobile to Hotspot

- Connect your mobile device to the desktop's hotspot.
- Ensure both devices are on the same network.

### 3. Start Desktop Server

- Open the desktop app.
- Go to "Connection" tab.
- Click "Start Hotspot Server" to generate a QR code.

### 4. Connect Mobile App

- Open the mobile app.
- Go to "Connect" tab.
- Scan the desktop's QR code.
- Connection is established automatically.

### 5. Start Syncing

- **Clipboard Sync:** Automatically sync clipboard content.
- **File Transfer:** Send files between devices.
- **Folder Sync:** All files saved to the configured sync folders.

---

# ⚙️ Configuration

## Desktop Settings

- **Sync Folder:** Default `~/Downloads/sync-files`
- **Port:** Default `8888` (customizable)
- **Auto-Accept Files:** Option to auto-accept incoming files

## Mobile Settings

- **Sync Folder:** Default `/storage/emulated/0/Download/sync-files`
- **Auto-Accept Files:** Option to auto-accept incoming files
- **Clipboard Sync:** Enable/disable automatic clipboard sync

---

# 🧩 Advanced Usage

- **Custom Sync Folders:** Set custom folders in Settings on both apps.
- **Network Configuration:** Change port if needed; app auto-detects local IP.
- **Clipboard:** Supports text only (no images/files via clipboard).

---

# 🛡️ Security Notes

- Direct, local-only connection—no external servers.
- Data transmitted in real-time over your local network.
- Only connect to trusted networks.
- Consider the sensitivity of files being transferred.

---

# 🧰 Troubleshooting

## Connection Issues

- Ensure both devices are on the same network.
- Allow the desktop app through your firewall.
- Change port if 8888 is occupied.
- Ensure mobile app has network permissions.

## File Transfer Issues

- Check storage permissions on mobile.
- Ensure sync folder exists and is writable.
- Large files may take time or fail.

## QR Code Scanning Issues

- Grant camera permissions to the mobile app.
- Ensure good lighting and proper distance.

---

# 🏗️ Building for Production

## Desktop

```bash
pip install pyinstaller
pyinstaller --onefile --windowed desktop_sync_app.py
```

## Mobile

- **Android:** `flutter build apk --release`
- **iOS:** `flutter build ios --release` (requires macOS/Xcode)

---

# 🚧 Limitations

- Both devices must be on the same network.
- Desktop: Windows/macOS/Linux; Mobile: Android/iOS.
- Very large files may timeout or cause memory issues.
- Desktop can handle only one mobile connection at a time.

---

# 🌟 Future Enhancements

- Multiple device connections
- Encrypted file transfer
- Mobile background service
- Full folder synchronization
- Image/media clipboard support
- File preview capabilities

---
