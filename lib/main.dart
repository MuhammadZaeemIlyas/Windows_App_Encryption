import 'dart:async';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:ffi/ffi.dart'; // Required for handling pointers
import 'package:win32/win32.dart'; // For Windows API calls
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:window_manager/window_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  WindowOptions windowOptions = WindowOptions(
    size: Size(250, 150),

//    alwaysOnTop: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: true,
    titleBarStyle: TitleBarStyle.hidden,
    windowButtonVisibility: false,
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
    await windowManager.hasShadow();
  });
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.dark(),
      debugShowCheckedModeBanner: false,
      home: PasswordScreen(),
    );
  }
}

class PasswordScreen extends StatefulWidget {
  @override
  _PasswordScreenState createState() => _PasswordScreenState();
}

class _PasswordScreenState extends State<PasswordScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final String _storedPassword = 'abuasdx';
  bool _isWhatsAppBlocked = false;
  bool _isPasswordEntered = false;
  late ReceivePort _receivePort;

  @override
  void initState() {
    super.initState();
    _startBackgroundMonitoring();
  }

  @override
  void dispose() {
    _receivePort.close();
    _focusNode.dispose();
    // Close the receive port when the widget is disposed
    super.dispose();
  }

  // Start background monitoring using an isolate
  void _startBackgroundMonitoring() {
    _receivePort = ReceivePort();
    Isolate.spawn(_monitorWhatsApp, _receivePort.sendPort);
    _receivePort.listen((message) {
      if (message == "check") {
        _checkWhatsAppStatus();
      }
    });
  }

  // Monitor WhatsApp process in an isolate
  static void _monitorWhatsApp(SendPort sendPort) {
    Timer.periodic(Duration(seconds: 3), (timer) {
      sendPort.send("check");
    });
  }

  // Check if WhatsApp.exe is running
  void _checkWhatsAppStatus() async {
    bool isWhatsAppRunning = await _isWhatsAppRunning();
    if (isWhatsAppRunning) {
      if (!_isWhatsAppBlocked && !_isPasswordEntered) {
        _blockWhatsApp();
        _showPasswordPrompt();
      }
    } else {
      // Reset all states if WhatsApp is not running
      setState(() {
        _isWhatsAppBlocked = false; // Reset blocked state
        _isPasswordEntered = false; // Reset password state
      });
      _passwordController.clear();
      print('WhatsApp has been terminated. States reset.'); // Debug log
    }
  }

  // Check if WhatsApp.exe is running
  Future<bool> _isWhatsAppRunning() async {
    try {
      ProcessResult result = await Process.run('tasklist', []);
      return result.stdout.toString().contains('WhatsApp.exe');
    } catch (e) {
      print('Error checking WhatsApp process: $e');
      return false;
    }
  }

  void _bringAppToFront() {
    final hwnd = GetForegroundWindow();
    SetForegroundWindow(hwnd);
    ShowWindow(hwnd, SW_RESTORE);
    print('App window brought to front.');
  }

  // Show password prompt before opening WhatsApp
  void _showPasswordPrompt() {
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          // title: Text(
          //   "Enter password",
          //   style: TextStyle(fontSize: 11),
          // ),
          content: TextField(
            controller: _passwordController,
            obscureText: true,
            autofocus: true,
            onSubmitted: (submit) {
              _verifyPassword();
            },
            decoration: InputDecoration(
                label: Text(
                  "Enter password",
                  style: TextStyle(fontSize: 12),
                ),
                hintText: 'Password',
                hintStyle: TextStyle(fontSize: 12),
                alignLabelWithHint: true),
          ),
        );
      },
    );
  }

  // Verify the entered password
  void _verifyPassword() {
    String enteredPassword = _passwordController.text.trim();

    if (enteredPassword == _storedPassword) {
      Navigator.of(context).pop(); // Close the dialog
      _resumeWhatsApp();
      setState(() {
        _isWhatsAppBlocked = false;
        _isPasswordEntered = true;
      });
      print('Access granted.'); // Debug log for access granted
    } else {
      print('Incorrect password'); // Debug log for incorrect password
      // Optionally show an error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Incorrect password! Try again.')),
      );
    }
  }

  // Block WhatsApp by hiding its window
  void _blockWhatsApp() {
    final hwnd = FindWindow(ffi.nullptr,
        'WhatsApp'.toNativeUtf16()); // Use title instead of class name
    if (hwnd != 0) {
      ShowWindow(hwnd, SW_HIDE);
      _isWhatsAppBlocked = true; // Hide the WhatsApp window
      print('WhatsApp is blocked.'); // Debug log for blocking
    } else {
      print('WhatsApp window not found.');
    }
  }

  void _resumeWhatsApp() {
    // Find the WhatsApp window
    final hwnd = FindWindow(ffi.nullptr, 'WhatsApp'.toNativeUtf16());
    if (hwnd != 0) {
      ShowWindow(hwnd, SW_RESTORE); // Restore the WhatsApp window
      print('WhatsApp window restored.'); // Debug log
    } else {
      print('WhatsApp window not found for restoration.'); // Debug log
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        onPanStart: (details) {
          windowManager.startDragging();
        },
        onDoubleTap: () {
          //  windowManager.close();
        },
        onLongPress: () {
          //windowManager.maximize();
        },
        child: Scaffold());
  }
}
