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
        scaffoldBackgroundColor: const Color(0xFF121212), // Hitam Soft sesuai permintaan
        primaryColor: Colors.cyanAccent,
        colorScheme: const ColorScheme.dark(primary: Colors.cyanAccent),
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
  int _selectedIndex = 1; // Default di Home
  BluetoothDevice? connectedDevice;
  bool isConnected = false;

  // Struktur Fitur sesuai coretan gambar
  final List<Map<String, dynamic>> features = [
    {'title': 'QUICKSHIFTER', 'icon': Icons.bolt_rounded, 'active': true},
    {'title': 'LIVE DATA', 'icon': Icons.analytics_outlined, 'active': false},
    {'title': 'TIMING KUDA', 'icon': Icons.timer_outlined, 'active': false},
    {'title': 'LAUNCH CONTROL', 'icon': Icons.rocket_launch_rounded, 'active': false},
    {'title': 'LIMITER', 'icon': Icons.speed_rounded, 'active': false},
    {'title': 'DIAGNOSTIC', 'icon': Icons.build_circle_outlined, 'active': false},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text("DS PROJEK", 
          style: GoogleFonts.orbitron(letterSpacing: 2, fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
        actions: [
          // Status Koneksi BLE di Pojok Kanan Atas
          Container(
            margin: const EdgeInsets.only(right: 15),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isConnected ? Colors.cyanAccent.withOpacity(0.1) : Colors.redAccent.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
              color: isConnected ? Colors.cyanAccent : Colors.redAccent,
              size: 20,
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildBlePage(),      // Index 0: BLE Connection
          _buildDashboard(),    // Index 1: Home
          _buildSettingsPage(), // Index 2: Settings
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // HALAMAN UTAMA (DASHBOARD 2 KOLOM)
  Widget _buildDashboard() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("TUNING MENU", 
            style: GoogleFonts.inter(color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, 
              crossAxisSpacing: 15, 
              mainAxisSpacing: 15, 
              childAspectRatio: 1.0,
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
          Navigator.push(context, MaterialPageRoute(
            builder: (context) => QsDetailScreen(device: connectedDevice)));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("${data['title']} is Coming Soon!", 
            style: const TextStyle(color: Colors.white)), backgroundColor: Colors.black87));
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E), // Grey Soft
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: active ? Colors.cyanAccent.withOpacity(0.2) : Colors.white10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(data['icon'], size: 45, color: active ? Colors.cyanAccent : Colors.grey.withOpacity(0.3)),
            const SizedBox(height: 12),
            Text(data['title'], 
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, 
              color: active ? Colors.white : Colors.grey)),
            if (!active) 
              Container(
                margin: const EdgeInsets.only(top: 5),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(5)),
                child: const Text("SOON", style: TextStyle(fontSize: 8, color: Colors.orange)),
              ),
          ],
        ),
      ),
    );
  }

  // HALAMAN BLE (MANUAL SCAN)
  Widget _buildBlePage() {
    return Column(
      children: [
        const SizedBox(height: 20),
        ElevatedButton.icon(
          icon: const Icon(Icons.search),
          label: const Text("SCAN FOR ECU"),
          onPressed: () => FlutterBluePlus.startScan(timeout: const Duration(seconds: 5)),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black),
        ),
        Expanded(
          child: StreamBuilder<List<ScanResult>>(
            stream: FlutterBluePlus.scanResults,
            builder: (c, snapshot) {
              final results = snapshot.data ?? [];
              return ListView.builder(
                itemCount: results.length,
                itemBuilder: (context, i) {
                  final dev = results[i].device;
                  return ListTile(
                    title: Text(dev.platformName.isEmpty ? "Unknown Device" : dev.platformName),
                    subtitle: Text(dev.remoteId.toString()),
                    trailing: TextButton(
                      child: const Text("CONNECT"),
                      onPressed: () async {
                        await dev.connect();
                        setState(() { connectedDevice = dev; isConnected = true; _selectedIndex = 1; });
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsPage() => const Center(child: Text("App Settings Coming Soon"));

  // BOTTOM NAVIGATION (STYLE CUSTOM)
  Widget _buildBottomNav() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 25),
      height: 70,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(35),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(Icons.bluetooth, 0, "BLE"),
          _navItem(Icons.grid_view_rounded, 1, "HOME"),
          _navItem(Icons.settings, 2, "SETTING"),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, int index, String label) {
    bool isSel = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: isSel ? Colors.cyanAccent : Colors.grey, size: 26),
          Text(label, style: TextStyle(color: isSel ? Colors.cyanAccent : Colors.grey, fontSize: 10)),
        ],
      ),
    );
  }
}

// ==========================================
// HALAMAN DETAIL QUICKSHIFTER
// ==========================================
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

  // FUNGSI SINKRONISASI DATA KE ESP32 (SESUAI LOGIKA PARSING KAMU)
  void sendConfigToEcu() async {
    if (widget.device == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ECU Not Connected!")));
      return;
    }

    try {
      List<BluetoothService> services = await widget.device!.discoverServices();
      for (var service in services) {
        // UUID Service ESP32 kamu
        if (service.uuid.toString() == "4fafc201-1fb5-459e-8fcc-c5c9c331914b") {
          for (var char in service.characteristics) {
            // UUID Characteristic ESP32 kamu
            if (char.uuid.toString() == "beb5483e-36e1-4688-b7f5-ea07361b26a8") {
              
              // 1. Kirim Status Power (QSE1 / QSE0)
              await char.write(utf8.encode("QSE${isOn ? 1 : 0}"));
              await Future.delayed(const Duration(milliseconds: 150));

              // 2. Kirim Nilai Cut Time (QSC75 / QSC40)
              await char.write(utf8.encode("QSC${cutOffValue.toInt()}"));

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Successfully Saved to ECU!"), backgroundColor: Colors.cyan),
              );
            }
          }
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("QS CONFIGURATION"), backgroundColor: Colors.transparent),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
        child: Column(
          children: [
            // ON OFF SWITCH
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(20)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Quickshifter System", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Switch(
                    value: isOn, 
                    activeColor: Colors.cyanAccent, 
                    onChanged: (v) => setState(() => isOn = v)
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // MODE SELECTOR
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: ['Racing', 'Standard', 'Custom'].map((m) {
                bool isSelected = mode == m;
                return ChoiceChip(
                  label: Text(m),
                  selected: isSelected,
                  onSelected: (s) => setState(() {
                    mode = m;
                    if (m == 'Racing') cutOffValue = 40;
                    if (m == 'Standard') cutOffValue = 75;
                  }),
                );
              }).toList(),
            ),

            const SizedBox(height: 60),

            // DISPLAY ANGKA BULAT
            Text("${cutOffValue.toInt()}", 
              style: GoogleFonts.orbitron(fontSize: 90, fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
            const Text("MILLISECONDS", style: TextStyle(letterSpacing: 4, color: Colors.grey)),

            const SizedBox(height: 40),

            // SLIDER (HANYA AKTIF JIKA CUSTOM)
            Slider(
              value: cutOffValue,
              min: 30, max: 150,
              divisions: 120,
              activeColor: Colors.cyanAccent,
              onChanged: mode == 'Custom' ? (v) => setState(() => cutOffValue = v) : null,
            ),
            Text(mode == 'Custom' ? "Slide to adjust value" : "Mode $mode is locked", 
              style: const TextStyle(fontSize: 10, color: Colors.grey)),

            const Spacer(),

            // TOMBOL SAVE
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyanAccent,
                minimumSize: const Size(double.infinity, 60),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              onPressed: sendConfigToEcu,
              child: const Text("SAVE TO ECU", 
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
