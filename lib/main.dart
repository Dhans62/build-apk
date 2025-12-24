import 'dart:convert';
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
        scaffoldBackgroundColor: const Color(0xFF121212), // Hitam Soft
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
  BluetoothDevice? connectedDevice;
  bool isConnected = false;

  final List<Map<String, dynamic>> features = [
    {'title': 'QUICKSHIFTER', 'icon': Icons.bolt, 'active': true},
    {'title': 'LIVE DATA', 'icon': Icons.analytics, 'active': false},
    {'title': 'TIMING KUDA', 'icon': Icons.timer, 'active': false},
    {'title': 'LAUNCH CONTROL', 'icon': Icons.rocket_launch, 'active': false},
    {'title': 'LIMITER', 'icon': Icons.speed, 'active': false},
    {'title': 'DIAGNOSTIC', 'icon': Icons.build, 'active': false},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text("DS PROJEK", style: GoogleFonts.orbitron(letterSpacing: 2, fontWeight: FontWeight.bold)),
        actions: [
          Icon(isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled, 
               color: isConnected ? Colors.cyanAccent : Colors.redAccent),
          const SizedBox(width: 20),
        ],
      ),
      body: _buildPage(),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildPage() {
    if (_selectedIndex == 0) return _buildBlePage();
    if (_selectedIndex == 1) return _buildDashboard();
    return const Center(child: Text("Settings Coming Soon"));
  }

  Widget _buildDashboard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("MAIN FEATURES", style: GoogleFonts.inter(color: Colors.grey, letterSpacing: 1.2)),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, crossAxisSpacing: 15, mainAxisSpacing: 15, childAspectRatio: 1.1,
            ),
            itemCount: features.length,
            itemBuilder: (context, index) {
              return _buildMenuCard(features[index]);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard(Map<String, dynamic> data) {
    bool active = data['active'];
    return GestureDetector(
      onTap: () {
        if (active) {
          Navigator.push(context, MaterialPageRoute(builder: (context) => QsDetailScreen(device: connectedDevice)));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${data['title']} Coming Soon!")));
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? Colors.cyanAccent.withOpacity(0.3) : Colors.white10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(data['icon'], size: 40, color: active ? Colors.cyanAccent : Colors.grey),
            const SizedBox(height: 10),
            Text(data['title'], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            if (!active) const Text("COMING SOON", style: TextStyle(fontSize: 8, color: Colors.orange)),
          ],
        ),
      ),
    );
  }

  Widget _buildBlePage() {
    return StreamBuilder<List<ScanResult>>(
      stream: FlutterBluePlus.scanResults,
      initialData: const [],
      builder: (c, snapshot) => Column(
        children: [
          ElevatedButton(onPressed: () => FlutterBluePlus.startScan(timeout: const Duration(seconds: 4)), child: const Text("Manual Scan")),
          Expanded(
            child: ListView(
              children: snapshot.data!.map((r) => ListTile(
                title: Text(r.device.platformName.isEmpty ? "Unknown ECU" : r.device.platformName),
                subtitle: Text(r.device.remoteId.toString()),
                trailing: ElevatedButton(
                  onPressed: () async {
                    await r.device.connect();
                    setState(() { connectedDevice = r.device; isConnected = true; });
                  }, 
                  child: const Text("Connect")
                ),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      margin: const EdgeInsets.all(20), height: 70,
      decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(30)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          IconButton(icon: const Icon(Icons.bluetooth), onPressed: () => setState(() => _selectedIndex = 0)),
          IconButton(icon: const Icon(Icons.grid_view_rounded), onPressed: () => setState(() => _selectedIndex = 1)),
          IconButton(icon: const Icon(Icons.settings), onPressed: () => setState(() => _selectedIndex = 2)),
        ],
      ),
    );
  }
}

// HALAMAN DETAIL QUICKSHIFTER
class QsDetailScreen extends StatefulWidget {
  final BluetoothDevice? device;
  const QsDetailScreen({super.key, this.device});
  @override
  State<QsDetailScreen> createState() => _QsDetailScreenState();
}

class _QsDetailScreenState extends State<QsDetailScreen> {
  double cutOffValue = 75;
  String mode = "Standard";
  bool isOn = true;

  void sendData() async {
    if (widget.device == null) return;
    List<BluetoothService> services = await widget.device!.discoverServices();
    for (var service in services) {
      for (var characteristic in service.characteristics) {
        if (characteristic.properties.write) {
          String payload = "QS:${isOn ? 1 : 0},MODE:$mode,VAL:${cutOffValue.toInt()}";
          await characteristic.write(utf8.encode(payload));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("QS CONFIG")),
      body: Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Power Status", style: TextStyle(fontSize: 18)),
                Switch(value: isOn, activeColor: Colors.cyanAccent, onChanged: (v) => setState(() => isOn = v)),
              ],
            ),
            const SizedBox(height: 30),
            // Mode Selector
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: ['Racing', 'Standard', 'Custom'].map((m) {
                return ChoiceChip(
                  label: Text(m), selected: mode == m,
                  onSelected: (s) => setState(() {
                    mode = m;
                    if (m == 'Racing') cutOffValue = 40;
                    if (m == 'Standard') cutOffValue = 75;
                  }),
                );
              }).toList(),
            ),
            const SizedBox(height: 50),
            Text("${cutOffValue.toInt()} ms", style: GoogleFonts.orbitron(fontSize: 50, color: Colors.cyanAccent)),
            Slider(
              value: cutOffValue, min: 30, max: 150, divisions: 120,
              activeColor: Colors.cyanAccent,
              onChanged: mode == 'Custom' ? (v) => setState(() => cutOffValue = v) : null,
            ),
            const Spacer(),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, minimumSize: const Size(double.infinity, 60)),
              onPressed: sendData,
              child: const Text("SAVE TO ECU", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
