import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';

void main() {
  runApp(SyncMobileApp());
}

class SyncMobileApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mobile Sync App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: SyncHomePage(),
    );
  }
}

class SyncHomePage extends StatefulWidget {
  @override
  _SyncHomePageState createState() => _SyncHomePageState();
}

class _SyncHomePageState extends State<SyncHomePage> with TickerProviderStateMixin {
  // Connection variables
  Socket? _socket;
  bool _isConnected = false;
  String _connectionStatus = "Not Connected";
  String _connectedDevice = "";
  
  // UI controllers
  late TabController _tabController;
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? qrController;
  
  // Settings
  String _syncFolder = "";
  bool _autoAcceptFiles = false;
  bool _clipboardSync = true;
  
  // File transfer
  double _transferProgress = 0.0;
  String _transferStatus = "";
  List<FileInfo> _syncFiles = [];
  
  // Clipboard monitoring
  Timer? _clipboardTimer;
  String _lastClipboard = "";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadSettings();
    _requestPermissions();
    _startClipboardMonitoring();
  }

  @override
  void dispose() {
    _tabController.dispose();
    qrController?.dispose();
    _socket?.close();
    _clipboardTimer?.cancel();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.camera,
      Permission.storage,
    ].request();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _syncFolder = prefs.getString('sync_folder') ?? '/storage/emulated/0/Download/sync-files';
      _autoAcceptFiles = prefs.getBool('auto_accept_files') ?? false;
      _clipboardSync = prefs.getBool('clipboard_sync') ?? true;
    });
    
    // Create sync folder if it doesn't exist
    final directory = Directory(_syncFolder);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    
    await _refreshFileList();
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sync_folder', _syncFolder);
    await prefs.setBool('auto_accept_files', _autoAcceptFiles);
    await prefs.setBool('clipboard_sync', _clipboardSync);
  }

  void _startClipboardMonitoring() {
    _clipboardTimer = Timer.periodic(Duration(seconds: 1), (timer) async {
      if (_clipboardSync && _isConnected) {
        try {
          ClipboardData? data = await Clipboard.getData('text/plain');
          String currentClipboard = data?.text ?? '';
          
          if (currentClipboard.isNotEmpty && currentClipboard != _lastClipboard) {
            _lastClipboard = currentClipboard;
            _sendMessage({
              'type': 'clipboard',
              'data': currentClipboard,
            });
          }
        } catch (e) {
          print('Clipboard monitoring error: $e');
        }
      }
    });
  }

  void _onQRViewCreated(QRViewController controller) {
    setState(() {
      qrController = controller;
    });
    
    controller.scannedDataStream.listen((scanData) async {
      if (scanData.code != null) {
        await _connectToDesktop(scanData.code!);
        controller.pauseCamera();
      }
    });
  }

  Future<void> _connectToDesktop(String qrData) async {
    try {
      final connectionInfo = json.decode(qrData);
      final ip = connectionInfo['ip'];
      final port = connectionInfo['port'];
      final deviceName = connectionInfo['device_name'] ?? 'Desktop';
      
      _socket = await Socket.connect(ip, port);
      
      // Send device info
      final deviceInfo = {
        'device_name': 'Mobile Device',
        'platform': Platform.operatingSystem,
      };
      
      _socket!.write(json.encode(deviceInfo));
      
      setState(() {
        _isConnected = true;
        _connectionStatus = "Connected";
        _connectedDevice = deviceName;
      });
      
      // Listen for messages
      _socket!.listen(
        _handleIncomingData,
        onError: (error) {
          print('Socket error: $error');
          _disconnect();
        },
        onDone: () {
          print('Socket closed');
          _disconnect();
        },
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connected to $deviceName')),
      );
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connection failed: $e')),
      );
    }
  }

  void _handleIncomingData(Uint8List data) {
    try {
      // Handle length-prefixed messages
      if (data.length < 4) return;
      
      final messageLength = ByteData.sublistView(data, 0, 4).getUint32(0, Endian.big);
      
      if (data.length >= 4 + messageLength) {
        final messageData = data.sublist(4, 4 + messageLength);
        final message = json.decode(utf8.decode(messageData));
        _processMessage(message);
      }
    } catch (e) {
      print('Error handling incoming data: $e');
    }
  }

  void _processMessage(Map<String, dynamic> message) {
    final type = message['type'];
    
    switch (type) {
      case 'clipboard':
        if (_clipboardSync) {
          Clipboard.setData(ClipboardData(text: message['data']));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Clipboard updated from desktop')),
          );
        }
        break;
        
      case 'file':
        _receiveFile(message);
        break;
        
      case 'clipboard_request':
        _sendClipboard();
        break;
    }
  }

  Future<void> _sendMessage(Map<String, dynamic> message) async {
    if (_socket != null && _isConnected) {
      try {
        final messageData = utf8.encode(json.encode(message));
        final lengthData = ByteData(4);
        lengthData.setUint32(0, messageData.length, Endian.big);
        
        _socket!.add(lengthData.buffer.asUint8List());
        _socket!.add(messageData);
      } catch (e) {
        print('Error sending message: $e');
      }
    }
  }

  void _disconnect() {
    setState(() {
      _isConnected = false;
      _connectionStatus = "Not Connected";
      _connectedDevice = "";
    });
    
    _socket?.close();
    _socket = null;
  }

  Future<void> _sendClipboard() async {
    try {
      ClipboardData? data = await Clipboard.getData('text/plain');
      if (data?.text != null) {
        await _sendMessage({
          'type': 'clipboard',
          'data': data!.text,
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Clipboard sent to desktop')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send clipboard: $e')),
      );
    }
  }

  Future<void> _requestClipboard() async {
    await _sendMessage({'type': 'clipboard_request'});
  }

  Future<void> _sendFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();
      
      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final fileName = result.files.single.name;
        final fileSize = await file.length();
        
        setState(() {
          _transferStatus = "Sending $fileName...";
          _transferProgress = 0.0;
        });
        
        final fileBytes = await file.readAsBytes();
        final fileData = base64Encode(fileBytes);
        
        final message = {
          'type': 'file',
          'name': fileName,
          'size': fileSize,
          'data': fileData,
        };
        
        await _sendMessage(message);
        
        setState(() {
          _transferStatus = "Sent $fileName";
          _transferProgress = 1.0;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('File sent successfully')),
        );
        
      }
    } catch (e) {
      setState(() {
        _transferStatus = "Failed to send file";
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send file: $e')),
      );
    }
  }

  Future<void> _receiveFile(Map<String, dynamic> message) async {
    try {
      final fileName = message['name'];
      final fileData = base64Decode(message['data']);
      
      // Save to sync folder
      String filePath = '$_syncFolder/$fileName';
      
      // Handle duplicate names
      int counter = 1;
      String originalPath = filePath;
      while (await File(filePath).exists()) {
        final lastDot = originalPath.lastIndexOf('.');
        if (lastDot != -1) {
          final name = originalPath.substring(0, lastDot);
          final ext = originalPath.substring(lastDot);
          filePath = '${name}_$counter$ext';
        } else {
          filePath = '${originalPath}_$counter';
        }
        counter++;
      }
      
      final file = File(filePath);
      await file.writeAsBytes(fileData);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Received: ${file.path.split('/').last}')),
      );
      
      await _refreshFileList();
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to receive file: $e')),
      );
    }
  }

  Future<void> _refreshFileList() async {
    try {
      final directory = Directory(_syncFolder);
      if (await directory.exists()) {
        final files = await directory.list().toList();
        
        setState(() {
          _syncFiles = files
              .where((file) => file is File)
              .map((file) => FileInfo.fromFile(file as File))
              .toList();
        });
      }
    } catch (e) {
      print('Error refreshing file list: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Mobile Sync App'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(icon: Icon(Icons.qr_code_scanner), text: 'Connect'),
            Tab(icon: Icon(Icons.content_copy), text: 'Clipboard'),
            Tab(icon: Icon(Icons.folder), text: 'Files'),
            Tab(icon: Icon(Icons.settings), text: 'Settings'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildConnectionTab(),
          _buildClipboardTab(),
          _buildFilesTab(),
          _buildSettingsTab(),
        ],
      ),
    );
  }

  Widget _buildConnectionTab() {
    return Column(
      children: [
        // Status Card
        Container(
          margin: EdgeInsets.all(16),
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    'Connection Status',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  SizedBox(height: 8),
                  Text(
                    _connectionStatus,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _isConnected ? Colors.green : Colors.red,
                    ),
                  ),
                  if (_connectedDevice.isNotEmpty)
                    Text('Connected to: $_connectedDevice'),
                  SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: _isConnected ? null : () => qrController?.resumeCamera(),
                        child: Text('Scan QR'),
                      ),
                      ElevatedButton(
                        onPressed: _isConnected ? _disconnect : null,
                        child: Text('Disconnect'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        
        // QR Scanner
        Expanded(
          child: Container(
            margin: EdgeInsets.all(16),
            child: Card(
              child: QRView(
                key: qrKey,
                onQRViewCreated: _onQRViewCreated,
                overlay: QrScannerOverlayShape(
                  borderColor: Colors.blue,
                  borderRadius: 10,
                  borderLength: 30,
                  borderWidth: 10,
                  cutOutSize: 300,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildClipboardTab() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Clipboard Sync',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  SizedBox(height: 16),
                  SwitchListTile(
                    title: Text('Auto Sync Clipboard'),
                    subtitle: Text('Automatically sync clipboard between devices'),
                    value: _clipboardSync,
                    onChanged: (value) {
                      setState(() {
                        _clipboardSync = value;
                      });
                      _saveSettings();
                    },
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isConnected ? _sendClipboard : null,
                          icon: Icon(Icons.upload),
                          label: Text('Send Clipboard'),
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isConnected ? _requestClipboard : null,
                          icon: Icon(Icons.download),
                          label: Text('Get Clipboard'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilesTab() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          // File Transfer Controls
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    'File Transfer',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _isConnected ? _sendFile : null,
                    icon: Icon(Icons.upload_file),
                    label: Text('Send File'),
                  ),
                  if (_transferStatus.isNotEmpty) ...[
                    SizedBox(height: 8),
                    LinearProgressIndicator(value: _transferProgress),
                    SizedBox(height: 4),
                    Text(_transferStatus),
                  ],
                ],
              ),
            ),
          ),
          
          SizedBox(height: 16),
          
          // File List
          Expanded(
            child: Card(
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Sync Folder Files',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        IconButton(
                          onPressed: _refreshFileList,
                          icon: Icon(Icons.refresh),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _syncFiles.length,
                      itemBuilder: (context, index) {
                        final file = _syncFiles[index];
                        return ListTile(
                          leading: Icon(Icons.insert_drive_file),
                          title: Text(file.name),
                          subtitle: Text('${file.sizeString} • ${file.modifiedString}'),
                          onTap: () {
                            // Could add file preview/open functionality here
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTab() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: ListView(
        children: [
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sync Folder',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    initialValue: _syncFolder,
                    decoration: InputDecoration(
                      labelText: 'Folder Path',
                      border: OutlineInputBorder(),
                      suffixIcon: IconButton(
                        onPressed: () async {
                          String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
                          if (selectedDirectory != null) {
                            setState(() {
                              _syncFolder = selectedDirectory;
                            });
                            _saveSettings();
                          }
                        },
                        icon: Icon(Icons.folder_open),
                      ),
                    ),
                    onChanged: (value) {
                      _syncFolder = value;
                      _saveSettings();
                    },
                  ),
                ],
              ),
            ),
          ),
          
          SizedBox(height: 16),
          
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'File Transfer Settings',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  SwitchListTile(
                    title: Text('Auto Accept Files'),
                    subtitle: Text('Automatically accept incoming files'),
                    value: _autoAcceptFiles,
                    onChanged: (value) {
                      setState(() {
                        _autoAcceptFiles = value;
                      });
                      _saveSettings();
                    },
                  ),
                ],
              ),
            ),
          ),
          
          SizedBox(height: 16),
          
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    'App Information',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  SizedBox(height: 16),
                  ListTile(
                    leading: Icon(Icons.info),
                    title: Text('Version'),
                    subtitle: Text('1.0.0'),
                  ),
                  ListTile(
                    leading: Icon(Icons.folder),
                    title: Text('Open Sync Folder'),
                    onTap: () {
                      // Could implement opening file manager here
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Sync folder: $_syncFolder')),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FileInfo {
  final String name;
  final String path;
  final int size;
  final DateTime modified;

  FileInfo({
    required this.name,
    required this.path,
    required this.size,
    required this.modified,
  });

  factory FileInfo.fromFile(File file) {
    final stat = file.statSync();
    return FileInfo(
      name: file.path.split('/').last,
      path: file.path,
      size: stat.size,
      modified: stat.modified,
    );
  }

  String get sizeString {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String get modifiedString {
    return '${modified.day}/${modified.month}/${modified.year} ${modified.hour}:${modified.minute.toString().padLeft(2, '0')}';
  }
}