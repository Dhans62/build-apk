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
              _menuCard("LIVE DATA ECU", Icons.analytics, true), // AKTIF
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
          if (title == "QUICKSHIFTER") {
            Navigator.push(context, MaterialPageRoute(builder: (context) => QsDetailScreen(device: _connectedDevice)));
          } else if (title == "LIVE DATA ECU") {
            Navigator.push(context, MaterialPageRoute(builder: (context) => RpmDisplayScreen(device: _connectedDevice)));
          }
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

// -------------------------------------------------------------------
// HALAMAN LIVE RPM DENGAN GRAFIK REAL-TIME
// -------------------------------------------------------------------
class RpmDisplayScreen extends StatefulWidget {
  final BluetoothDevice? device;
  const RpmDisplayScreen({super.key, this.device});

  @override
  State<RpmDisplayScreen> createState() => _RpmDisplayScreenState();
}

class _RpmDisplayScreenState extends State<RpmDisplayScreen> {
  int _currentRpm = 0;
  List<int> _rpmHistory = [];
  StreamSubscription? _notifySub;
  final String serviceUuid = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  final String charUuid = "beb5483e-36e1-4688-b7f5-ea07361b26a8";

  @override
  void initState() {
    super.initState();
    // Inisialisasi history agar grafik tidak melompat di awal
    _rpmHistory = List.filled(40, 0); 
    _startListening();
  }

  void _startListening() async {
    if (widget.device == null) return;
    try {
      List<BluetoothService> services = await widget.device!.discoverServices();
      for (var s in services) {
        if (s.uuid.toString().toLowerCase() == serviceUuid) {
          for (var c in s.characteristics) {
            if (c.uuid.toString().toLowerCase() == charUuid) {
              await c.setNotifyValue(true);
              _notifySub = c.onValueReceived.listen((value) {
                String data = utf8.decode(value);
                // Kita tangkap pesan DAT_RPM| dari ESP32
                if (data.startsWith("DAT_RPM|")) {
                  try {
                    int val = int.parse(data.split('|')[1]);
                    if (mounted) {
                      setState(() {
                        _currentRpm = val;
                        _rpmHistory.add(val);
                        if (_rpmHistory.length > 40) _rpmHistory.removeAt(0);
                      });
                    }
                  } catch (e) { /* ignore parse error */ }
                }
              });
            }
          }
        }
      }
    } catch (e) { print("Error BLE: $e"); }
  }

  @override
  void dispose() {
    _notifySub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios), onPressed: () => Navigator.pop(context)),
        title: Text("LIVE ECU DATA", style: GoogleFonts.orbitron(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            const SizedBox(height: 10),
            // GRAFIK RPM
            Container(
              height: 220,
              width: double.infinity,
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white10),
              ),
              child: CustomPaint(
                painter: RpmLinePainter(_rpmHistory),
              ),
            ),
            const SizedBox(height: 30),
            // DISPLAY DIGITAL
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(color: Colors.cyanAccent.withOpacity(0.05), blurRadius: 20, spreadRadius: 1)
                ]
              ),
              child: Column(
                children: [
                  Text("ENGINE REVOLUTION", style: GoogleFonts.inter(color: Colors.grey, fontSize: 11, letterSpacing: 3)),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text("$_currentRpm", style: GoogleFonts.orbitron(fontSize: 60, fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
                      const SizedBox(width: 10),
                      Text("RPM", style: GoogleFonts.orbitron(fontSize: 18, color: Colors.white24)),
                    ],
                  ),
                ],
              ),
            ),
            const Spacer(),
            Text("SCALED: 0 - 15.000 RPM", style: GoogleFonts.inter(color: Colors.white10, fontSize: 10, letterSpacing: 1)),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

// PAINTER UNTUK MENGGAMBAR GARIS GRAFIK TANPA LIBRARY
class RpmLinePainter extends CustomPainter {
  final List<int> points;
  RpmLinePainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final paint = Paint()
      ..color = Colors.cyanAccent
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    double gap = size.width / (points.length - 1);
    double maxRpm = 15000; // Skala maksimal sesuai permintaan

    for (int i = 0; i < points.length; i++) {
      double x = i * gap;
      // Normalisasi nilai RPM ke tinggi canvas (Inverted Y)
      double val = points[i].toDouble().clamp(0, maxRpm);
      double y = size.height - (val / maxRpm * size.height);
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    // Gambar Garis Grid Horizontal Tipis
    final gridPaint = Paint()..color = Colors.white.withOpacity(0.05)..strokeWidth = 1;
    for(int i=1; i<=3; i++) {
      double yGrid = size.height / 4 * i;
      canvas.drawLine(Offset(0, yGrid), Offset(size.width, yGrid), gridPaint);
    }

    canvas.drawPath(path, paint);

    // Tambahkan Efek Area Glow di bawah garis
    final areaPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    
    final areaPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.cyanAccent.withOpacity(0.2), Colors.transparent],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    
    canvas.drawPath(areaPath, areaPaint);
  }

  @override
  bool shouldRepaint(RpmLinePainter oldDelegate) => true;
}

// -------------------------------------------------------------------
// HALAMAN QUICKSHIFTER (TETAP SAMA)
// -------------------------------------------------------------------
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
              await Future.delayed(const Duration(milliseconds: 500));
              await c.write(utf8.encode("GET_QS")); 
            }
          }
        }
      }
    } catch(e) { print(e); }
  }

  void _sendData() async {
    if (_targetChar == null) return;
    try {
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
        title: Text("QS CONFIG", style: GoogleFonts.orbitron(fontSize: 14, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(15)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("POWER STATUS", style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
                  Switch(
                    value: _isOn,
                    activeColor: Colors.cyanAccent,
                    onChanged: (v) => setState(() => _isOn = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                _presetBtn("RACING", "40ms", _cutTime == 40, () => setState(() => _cutTime = 40)),
                const SizedBox(width: 10),
                _presetBtn("STANDARD", "75ms", _cutTime == 75, () => setState(() => _cutTime = 75)),
              ],
            ),
            const SizedBox(height: 30),
            Text("${_cutTime.toInt()} ms", style: GoogleFonts.orbitron(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white)),
            Slider(
              value: _cutTime, min: 30, max: 200,
              activeColor: Colors.cyanAccent,
              onChanged: (v) => setState(() => _cutTime = v),
            ),
            const SizedBox(height: 30),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(15)),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("IGNITION DELAY", style: GoogleFonts.inter(fontSize: 12, color: Colors.white70)),
                      Text("${_valTime.toInt()} ms", style: GoogleFonts.orbitron(fontSize: 12, color: Colors.white)),
                  
