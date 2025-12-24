import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:google_fonts/google_fonts.dart';

void main() => runApp(const DsProjekApp());

class DsProjekApp extends StatelessWidget {
  const DsProjekApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: Colors.cyanAccent,
      ),
      home: const MainMenu(),
    );
  }
}

class MainMenu extends StatefulWidget {
  const MainMenu({super.key});
  @override
  State<MainMenu> createState() => _MainMenuState();
}

class _MainMenuState extends State<MainMenu> {
  int _selectedIndex = 1;
  BluetoothDevice? _connectedDevice;
  bool _isConnected = false;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;

  // UUID dari Kode ESP32 kamu
  final String serviceUuid = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";

  void _onDeviceConnected(BluetoothDevice device) {
    _connectionSubscription?.cancel();
    _connectionSubscription = device.connectionState.listen((state) {
      setState(() {
        _connectedDevice = device;
        _isConnected = state == BluetoothConnectionState.connected;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text("DS PROJEK", style: GoogleFonts.orbitron(letterSpacing: 2, fontWeight: FontWeight.bold)),
        actions: [
          Padding(
            padding: const EdgeInsets.all(15),
            child: Icon(_isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                color: _isConnected ? Colors.cyanAccent : Colors.redAccent),
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBody() {
    if (_selectedIndex == 0) return _buildBlePage();
    if (_selectedIndex == 1) return _buildDashboard();
    return _buildSettingsPage();
  }

  Widget _buildDashboard() {
    return Column(
      children: [
        // Indikator Status Koneksi
        Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _isConnected ? Colors.cyanAccent.withOpacity(0.1) : Colors.white10,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            _isConnected 
              ? "Terhubung ke: ${_connectedDevice?.platformName ?? _connectedDevice?.remoteId}"
              : "Status: Disconnected",
            textAlign: TextAlign.center,
            style: TextStyle(color: _isConnected ? Colors.cyanAccent : Colors.grey, fontSize: 12),
          ),
        ),
        Expanded(
          child: GridView.count(
            crossAxisCount: 2,
            padding: const EdgeInsets.all(20),
            mainAxisSpacing: 15,
            crossAxisSpacing: 15,
            children: [
              _menuItem("QUICKSHIFTER", Icons.bolt, true),
              _menuItem("LIVE DATA", Icons.analytics, false),
              _menuItem("TIMING KUDA", Icons.timer, false),
              _menuItem("LIMITER", Icons.speed, false),
            ],
          ),
        ),
      ],
    );
  }

  Widget _menuItem(String title, IconData icon, bool active) {
    return GestureDetector(
      onTap: () {
        if (active) {
          Navigator.push(context, MaterialPageRoute(builder: (context) => QsDetailScreen(device: _connectedDevice)));
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? Colors.cyanAccent.withOpacity(0.3) : Colors.transparent),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: active ? Colors.cyanAccent : Colors.grey),
            const SizedBox(height: 10),
            Text(title, style: TextStyle(fontSize: 12, color: active ? Colors.white : Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildBlePage() {
    return Column(
      children: [
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: () => FlutterBluePlus.startScan(timeout: const Duration(seconds: 4)),
          child: const Text("Manual Scan"),
        ),
        Expanded(
          child: StreamBuilder<List<ScanResult>>(
            stream: FlutterBluePlus.scanResults,
            builder: (c, snapshot) => ListView(
              children: (snapshot.data ?? []).map((r) => ListTile(
                title: Text(r.device.platformName.isEmpty ? "Unknown ECU" : r.device.platformName),
                subtitle: Text(r.device.remoteId.toString()),
                onTap: () async {
                  await r.device.connect();
                  _onDeviceConnected(r.device);
                  setState(() => _selectedIndex = 1);
                },
              )).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsPage() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text("FIRMWARE UPDATE (OTA)", style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        ListTile(
          tileColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          leading: const Icon(Icons.system_update, color: Colors.orangeAccent),
          title: const Text("Check Update"),
          subtitle: const Text("Current Version: v5.0"),
          onTap: () {
            // Logika OTA akan diimplementasikan di sini
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("OTA Feature Coming Soon")));
          },
        ),
      ],
    );
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: _selectedIndex,
      onTap: (i) => setState(() => _selectedIndex = i),
      backgroundColor: const Color(0xFF1E1E1E),
      selectedItemColor: Colors.cyanAccent,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.bluetooth), label: "BLE"),
        BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
        BottomNavigationBarItem(icon: Icon(Icons.settings), label: "Setting"),
      ],
    );
  }
}

// --- HALAMAN DETAIL QUICKSHIFTER ---
class QsDetailScreen extends StatefulWidget {
  final BluetoothDevice? device;
  const QsDetailScreen({super.key, this.device});
  @override
  State<QsDetailScreen> createState() => _QsDetailScreenState();
}

class _QsDetailScreenState extends State<QsDetailScreen> {
  double cutTime = 75;
  double valTime = 5;
  bool isOn = true;
  String mode = "Standard";

  final String charUuid = "beb5483e-36e1-4688-b7f5-ea07361b26a8";

  void sendToEcu() async {
    if (widget.device == null) return;
    try {
      List<BluetoothService> services = await widget.device!.discoverServices();
      for (var s in services) {
        for (var c in s.characteristics) {
          if (c.uuid.toString() == charUuid) {
            // Mengirim 3 parameter dengan delay agar tidak tabrakan
            await c.write(utf8.encode("QSE${isOn ? 1 : 0}"));
            await Future.delayed(const Duration(milliseconds: 150));
            await c.write(utf8.encode("QSC${cutTime.toInt()}"));
            await Future.delayed(const Duration(milliseconds: 150));
            await c.write(utf8.encode("QSV${valTime.toInt()}"));
            
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Setting Tersimpan")));
          }
        }
      }
    } catch (e) {
      print("Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("QS CONFIG")),
      body: ListView(
        padding: const EdgeInsets.all(25),
        children: [
          SwitchListTile(
            title: const Text("Sistem Quickshifter"),
            value: isOn,
            activeColor: Colors.cyanAccent,
            onChanged: (v) => setState(() => isOn = v),
          ),
          const Divider(),
          const SizedBox(height: 20),
          _sliderBlock("Cut-off Time (ms)", cutTime, 30, 150, (v) {
            setState(() { mode = "Custom"; cutTime = v; });
          }),
          const SizedBox(height: 30),
          _sliderBlock("Sensor Delay / Validation (ms)", valTime, 0, 50, (v) {
            setState(() { valTime = v; });
          }),
          const SizedBox(height: 40),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.cyanAccent,
              minimumSize: const Size(double.infinity, 55),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
            ),
            onPressed: sendToEcu,
            child: const Text("SIMPAN KE ECU", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _sliderBlock(String title, double val, double min, double max, Function(double) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(color: Colors.grey)),
            Text("${val.toInt()} ms", style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        Slider(
          value: val, min: min, max: max,
          activeColor: Colors.cyanAccent,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
