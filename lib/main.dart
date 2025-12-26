import 'dart:convert';
import 'dart:async';
import 'dart:math';
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
        scaffoldBackgroundColor: const Color(0xFF0F0F0F),
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

  void _onDeviceConnected(BluetoothDevice device) {
    _connectionSubscription?.cancel();
    _connectionSubscription = device.connectionState.listen((state) {
      if (mounted) {
        setState(() {
          _connectedDevice = device;
          _isConnected = state == BluetoothConnectionState.connected;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text("DS PROJEK", style: GoogleFonts.orbitron(letterSpacing: 3, fontWeight: FontWeight.bold, fontSize: 22)),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildBlePage(),
          _buildDashboard(),
          _buildSettingsPage(),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildDashboard() {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(50),
            border: Border.all(color: _isConnected ? Colors.cyanAccent.withOpacity(0.5) : Colors.white10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.circle, size: 10, color: _isConnected ? Colors.cyanAccent : Colors.red),
              const SizedBox(width: 10),
              Text(
                _isConnected ? "ONLINE: ${_connectedDevice?.platformName}" : "OFFLINE / DISCONNECTED",
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: _isConnected ? Colors.white : Colors.grey),
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.count(
            crossAxisCount: 2,
            padding: const EdgeInsets.all(20),
            mainAxisSpacing: 15,
            crossAxisSpacing: 15,
            children: [
              _menuCard("QUICKSHIFTER", Icons.bolt, true),
              _menuCard("LIMITER", Icons.speed, false),
              _menuCard("TIMING KUDA", Icons.timer, false),
              _menuCard("BACKFIRE", Icons.local_fire_department, false),
              _menuCard("LIVE DATA ECU", Icons.analytics, false),
              _menuCard("TABEL PENGAPIAN", Icons.grid_on, false),
            ],
          ),
        ),
      ],
    );
  }

  Widget _menuCard(String title, IconData icon, bool active) {
    return InkWell(
      onTap: () {
        if (active) {
          Navigator.push(context, MaterialPageRoute(builder: (context) => QsDetailScreen(device: _connectedDevice)));
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: active ? Colors.white10 : Colors.transparent),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: active ? Colors.cyanAccent.withOpacity(0.1) : Colors.white12, shape: BoxShape.circle),
              child: Icon(icon, size: 32, color: active ? Colors.cyanAccent : Colors.grey),
            ),
            const SizedBox(height: 12),
            Text(title, textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: active ? Colors.white : Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildBlePage() {
    return Column(
      children: [
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: () => FlutterBluePlus.startScan(timeout: const Duration(seconds: 4)),
          icon: const Icon(Icons.search),
          label: const Text("SCAN DEVICE"),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black),
        ),
        Expanded(
          child: StreamBuilder<List<ScanResult>>(
            stream: FlutterBluePlus.scanResults,
            builder: (c, snapshot) => ListView(
              padding: const EdgeInsets.all(20),
              children: (snapshot.data ?? []).map((r) => Card(
                color: const Color(0xFF1A1A1A),
                child: ListTile(
                  title: Text(r.device.platformName.isEmpty ? "Unknown Device" : r.device.platformName),
                  subtitle: Text(r.device.remoteId.toString()),
                  trailing: const Icon(Icons.link, color: Colors.cyanAccent),
                  onTap: () async {
                    await r.device.connect();
                    _onDeviceConnected(r.device);
                    setState(() => _selectedIndex = 1);
                  },
                ),
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
        Text("PENGATURAN", style: GoogleFonts.orbitron(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        _settingsTile("Update Firmware (OTA)", Icons.cloud_download, Colors.orangeAccent, () {}),
        _settingsTile("Panduan Penggunaan", Icons.help_outline, Colors.blueAccent, () {}),
        _settingsTile("Tentang DS PROJEK", Icons.info_outline, Colors.grey, () {}),
      ],
    );
  }

  Widget _settingsTile(String title, IconData icon, Color color, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: color),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      padding: const EdgeInsets.only(bottom: 20, left: 20, right: 20, top: 10),
      decoration: const BoxDecoration(color: Color(0xFF0F0F0F)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (i) => setState(() => _selectedIndex = i),
          backgroundColor: const Color(0xFF1A1A1A),
          selectedItemColor: Colors.cyanAccent,
          unselectedItemColor: Colors.grey,
          showSelectedLabels: false,
          showUnselectedLabels: false,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.bluetooth), label: "BLE"),
            BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: "HOME"),
            BottomNavigationBarItem(icon: Icon(Icons.settings), label: "SETTING"),
          ],
        ),
      ),
    );
  }
}

class QsDetailScreen extends StatefulWidget {
  final BluetoothDevice? device;
  const QsDetailScreen({super.key, this.device});
  @override
  State<QsDetailScreen> createState() => _QsDetailScreenState();
}

class _QsDetailScreenState extends State<QsDetailScreen> {
  double _cutTime = 75;
  double _valTime = 5;
  bool _isOn = true;
  BluetoothCharacteristic? _targetChar;
  StreamSubscription? _notifySub;

  final String serviceUuid = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  final String charUuid = "beb5483e-36e1-4688-b7f5-ea07361b26a8";

  @override
  void initState() {
    super.initState();
    _initBleSync();
  }

  void _initBleSync() async {
    if (widget.device == null) return;
    try {
      List<BluetoothService> services = await widget.device!.discoverServices();
      for (var s in services) {
        if (s.uuid.toString().toLowerCase() == serviceUuid) {
          for (var c in s.characteristics) {
            if (c.uuid.toString().toLowerCase() == charUuid) {
              _targetChar = c;
              await c.setNotifyValue(true);
              _notifySub = c.onValueReceived.listen((value) {
                _parseEcuData(utf8.decode(value));
              });
              await Future.delayed(const Duration(milliseconds: 500));
              await c.write(utf8.encode("GET_QS")); 
            }
          }
        }
      }
    } catch(e) { print(e); }
  }

  void _parseEcuData(String data) {
    if (data.startsWith("ACK_QS")) {
      List<String> parts = data.split('|');
      setState(() {
        _isOn = parts[1].split(':')[1] == '1';
        _cutTime = double.parse(parts[2].split(':')[1]);
        _valTime = double.parse(parts[3].split(':')[1]);
      });
    }
  }

  void _sendData() async {
    if (_targetChar == null) return;
    try {
      // ATOMIC UPDATE: Mengirim satu string tunggal agar aman di Preferences ESP32
      String payload = "QSSET|E:${_isOn ? 1 : 0}|C:${_cutTime.toInt()}|V:${_valTime.toInt()}";
      await _targetChar!.write(utf8.encode(payload));
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: Colors.cyanAccent, content: Text("SAVE SUCCESS", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)))
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Gagal menyimpan ke ECU")));
    }
  }

  @override
  void dispose() {
    _notifySub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, size: 20), onPressed: () => Navigator.pop(context)),
        title: Text("QUICKSHIFTER CONFIG", style: GoogleFonts.orbitron(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1)),
        actions: [
           IconButton(onPressed: () {}, icon: const Icon(Icons.bluetooth_connected, color: Colors.cyanAccent, size: 20)),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            const SizedBox(height: 10),
            // POWER STATUS CARD
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(15)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("POWER STATUS", style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
                  Row(
                    children: [
                      Text(_isOn ? "ON" : "OFF", style: GoogleFonts.inter(color: _isOn ? Colors.cyanAccent : Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
                      const SizedBox(width: 10),
                      Transform.scale(
                        scale: 0.8,
                        child: Switch(
                          value: _isOn,
                          activeColor: Colors.cyanAccent,
                          onChanged: (v) => setState(() => _isOn = v),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
            const SizedBox(height: 20),
            // PRESET BUTTONS
            Row(
              children: [
                _presetBtn("RACING", "40ms", _cutTime == 40, () => setState(() => _cutTime = 40)),
                const SizedBox(width: 10),
                _presetBtn("STANDARD", "75ms", _cutTime == 75, () => setState(() => _cutTime = 75)),
                const SizedBox(width: 10),
                _presetBtn("CUSTOM", "", _cutTime != 40 && _cutTime != 75, () {}),
              ],
            ),
            const SizedBox(height: 30),
            // GAUGE CUSTOM IMITATION
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 220, height: 220,
                  child: CircularProgressIndicator(
                    value: _cutTime / 200,
                    strokeWidth: 8,
                    backgroundColor: Colors.white10,
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.cyanAccent),
                  ),
                ),
                Column(
                  children: [
                    Text("${_cutTime.toInt()}", style: GoogleFonts.orbitron(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white)),
                    Text("ms", style: GoogleFonts.inter(fontSize: 16, color: Colors.grey)),
                  ],
                ),
                Positioned(
                  bottom: 30,
                  child: Text("CUSTOM", style: GoogleFonts.inter(fontSize: 10, color: Colors.grey, letterSpacing: 2)),
                ),
                // Slider invisible over gauge or below it
              ],
            ),
            Slider(
              value: _cutTime, min: 30, max: 200,
              activeColor: Colors.cyanAccent,
              onChanged: (v) => setState(() => _cutTime = v),
            ),
            const SizedBox(height: 30),
            // IGNITION DELAY SLIDER
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(15)),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("IGNITION DELAY (ms)", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white70)),
                      Text("${_valTime.toInt()} ms", style: GoogleFonts.orbitron(fontSize: 12, color: Colors.white)),
                    ],
                  ),
                  Slider(
                    value: _valTime, min: 0, max: 50,
                    activeColor: Colors.cyanAccent,
                    onChanged: (v) => setState(() => _valTime = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            // SAVE BUTTON
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyanAccent,
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _sendData,
              child: Text("SAVE", style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14)),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _presetBtn(String label, String ms, bool active, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? Colors.cyanAccent : const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: active ? Colors.black : Colors.white)),
              if (ms.isNotEmpty) Text(ms, style: GoogleFonts.inter(fontSize: 9, color: active ? Colors.black54 : Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}
