import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart'; // Tambahkan fl_chart di pubspec.yaml kamu

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
  
  // Variabel Global RPM untuk Dashboard
  int currentRpm = 0;
  StreamSubscription? _rpmSubscription;

  void _onDeviceConnected(BluetoothDevice device) {
    _connectionSubscription?.cancel();
    _connectionSubscription = device.connectionState.listen((state) {
      if (mounted) {
        setState(() {
          _connectedDevice = device;
          _isConnected = state == BluetoothConnectionState.connected;
        });
        if (_isConnected) _startRpmListener(device);
      }
    });
  }

  // Listener untuk menangkap data RPM secara global
  void _startRpmListener(BluetoothDevice device) async {
    List<BluetoothService> services = await device.discoverServices();
    for (var s in services) {
      for (var c in s.characteristics) {
        if (c.uuid.toString() == "beb5483e-36e1-4688-b7f5-ea07361b26a8") {
          await c.setNotifyValue(true);
          _rpmSubscription = c.onValueReceived.listen((value) {
            String data = utf8.decode(value);
            if (data.startsWith("DAT_RPM|")) {
              if (mounted) {
                setState(() {
                  currentRpm = int.tryParse(data.split('|')[1]) ?? 0;
                });
              }
            }
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _connectionSubscription?.cancel();
    _rpmSubscription?.cancel();
    super.dispose();
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
              _menuCard("QUICKSHIFTER", Icons.bolt, true, () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => QsDetailScreen(device: _connectedDevice)));
              }),
              _menuCard("LIVE RPM", Icons.analytics, true, () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => LiveRpmScreen(device: _connectedDevice)));
              }),
              _menuCard("LIMITER", Icons.speed, false, null),
              _menuCard("TIMING KUDA", Icons.timer, false, null),
              _menuCard("BACKFIRE", Icons.local_fire_department, false, null),
              _menuCard("TABEL PENGAPIAN", Icons.grid_on, false, null),
            ],
          ),
        ),
      ],
    );
  }

  Widget _menuCard(String title, IconData icon, bool active, VoidCallback? onTap) {
    return InkWell(
      onTap: active ? onTap : null,
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
            if (title == "LIVE RPM" && _isConnected) 
              Text("$currentRpm", style: const TextStyle(color: Colors.cyanAccent, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  // --- BUILDER LAINNYA (BLE & SETTINGS) TETAP SAMA ---
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

// --- FITUR BARU: LIVE RPM SCREEN ---
class LiveRpmScreen extends StatefulWidget {
  final BluetoothDevice? device;
  const LiveRpmScreen({super.key, this.device});

  @override
  State<LiveRpmScreen> createState() => _LiveRpmScreenState();
}

class _LiveRpmScreenState extends State<LiveRpmScreen> {
  List<FlSpot> rpmPoints = [];
  double xValue = 0;
  int currentRpm = 0;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _connectToRpmStream();
  }

  void _connectToRpmStream() async {
    if (widget.device == null) return;
    List<BluetoothService> services = await widget.device!.discoverServices();
    for (var s in services) {
      for (var c in s.characteristics) {
        if (c.uuid.toString() == "beb5483e-36e1-4688-b7f5-ea07361b26a8") {
          _sub = c.onValueReceived.listen((value) {
            String raw = utf8.decode(value);
            if (raw.startsWith("DAT_RPM|")) {
              int val = int.tryParse(raw.split('|')[1]) ?? 0;
              _updateGraph(val.toDouble());
            }
          });
        }
      }
    }
  }

  void _updateGraph(double val) {
    setState(() {
      currentRpm = val.toInt();
      rpmPoints.add(FlSpot(xValue, val));
      xValue += 1;
      // Batasi 50 titik (Data 10 Detik) agar tidak lemot
      if (rpmPoints.length > 50) {
        rpmPoints.removeAt(0);
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("LIVE TELEMETRY", style: GoogleFonts.orbitron(fontSize: 14))),
      body: Column(
        children: [
          const SizedBox(height: 20),
          // KOTAK GRAFIK
          Container(
            height: 300,
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white10),
            ),
            child: LineChart(
              LineChartData(
                minY: 0, maxY: 15000,
                minX: rpmPoints.isNotEmpty ? rpmPoints.first.x : 0,
                maxX: rpmPoints.isNotEmpty ? rpmPoints.last.x : 10,
                gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (value) => FlLine(color: Colors.white10, strokeWidth: 1)),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: rpmPoints,
                    isCurved: true,
                    color: Colors.cyanAccent,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: true, color: Colors.cyanAccent.withOpacity(0.1)),
                  ),
                ],
              ),
            ),
          ),
          // DIGITAL RPM
          Text("CURRENT ENGINE SPEED", style: GoogleFonts.inter(color: Colors.grey, letterSpacing: 1)),
          const SizedBox(height: 10),
          Text(
            "$currentRpm",
            style: GoogleFonts.orbitron(fontSize: 80, fontWeight: FontWeight.bold, color: Colors.cyanAccent),
          ),
          Text("RPM", style: GoogleFonts.orbitron(fontSize: 20, color: Colors.cyanAccent.withOpacity(0.5))),
        ],
      ),
    );
  }
}

// --- SCREEN QUICKSHIFTER (KODE SEBELUMNYA TETAP ADA) ---
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
    List<BluetoothService> services = await widget.device!.discoverServices();
    for (var s in services) {
      if (s.uuid.toString() == serviceUuid) {
        for (var c in s.characteristics) {
          if (c.uuid.toString() == charUuid) {
            _targetChar = c;
            await c.setNotifyValue(true);
            _notifySub = c.onValueReceived.listen((value) {
              String data = utf8.decode(value);
              if (data.startsWith("ACK_QS")) {
                List<String> parts = data.split('|');
                setState(() {
                  _isOn = parts[1].split(':')[1] == '1';
                  _cutTime = double.parse(parts[2].split(':')[1]);
                  _valTime = double.parse(parts[3].split(':')[1]);
                });
              }
            });
            await c.write(utf8.encode("GET_QS")); 
          }
        }
      }
    }
  }

  void _sendData() async {
    if (_targetChar == null) return;
    await _targetChar!.write(utf8.encode("QSSET|E:${_isOn?1:0}|C:${_cutTime.toInt()}|V:${_valTime.toInt()}"));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("SAVE SUCCESS")));
  }

  @override
  void dispose() {
    _notifySub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("QS CONFIG")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(20)),
              child: SwitchListTile(
                title: const Text("POWER STATUS"),
                value: _isOn,
                activeColor: Colors.cyanAccent,
                onChanged: (v) => setState(() => _isOn = v),
              ),
            ),
            const SizedBox(height: 20),
            _buildSliderCard("IGNITION CUT", _cutTime, 30, 200, (v) => setState(() => _cutTime = v)),
            const SizedBox(height: 20),
            _buildSliderCard("SENSOR DELAY", _valTime, 0, 50, (v) => setState(() => _valTime = v)),
            const SizedBox(height: 50),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, minimumSize: const Size(double.infinity, 60)),
              onPressed: _sendData,
              child: const Text("SAVE", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliderCard(String title, double val, double min, double max, Function(double) onChanged) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [Text(title), Text("${val.toInt()} ms", style: const TextStyle(color: Colors.cyanAccent))],
          ),
          Slider(value: val, min: min, max: max, activeColor: Colors.cyanAccent, onChanged: onChanged),
        ],
      ),
    );
  }
}

