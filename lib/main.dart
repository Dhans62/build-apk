import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

void main() => runApp(const QsProApp());

class QsProApp extends StatelessWidget {
  const QsProApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF050505),
        textTheme: GoogleFonts.orbitronTextTheme(ThemeData.dark().textTheme),
      ),
      home: const RacingDashboard(),
    );
  }
}

class RacingDashboard extends StatefulWidget {
  const RacingDashboard({super.key});
  @override
  State<RacingDashboard> createState() => _RacingDashboardState();
}

class _RacingDashboardState extends State<RacingDashboard> {
  double cutOffTime = 65;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("QS PRO TUNER", style: TextStyle(letterSpacing: 2, color: Colors.redAccent)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          const SizedBox(height: 30),
          // Monitor Visual
          Center(
            child: Container(
              width: 250, height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.redAccent.withOpacity(0.5), width: 2),
                boxShadow: [BoxShadow(color: Colors.redAccent.withOpacity(0.2), blurRadius: 20, spreadRadius: 5)],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("CUT-OFF TIME", style: TextStyle(fontSize: 14, color: Colors.grey)),
                  Text("${cutOffTime.toInt()}", style: const TextStyle(fontSize: 80, fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
                  const Text("MILLISECONDS", style: TextStyle(fontSize: 12, color: Colors.cyanAccent)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 50),
          // Slider Kontrol
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [Text("30ms"), Text("150ms")],
                ),
                Slider(
                  value: cutOffTime, min: 30, max: 150,
                  activeColor: Colors.redAccent,
                  inactiveColor: Colors.white10,
                  onChanged: (v) => setState(() => cutOffTime = v),
                ),
                const Text("ADJUST SENSITIVITY", style: TextStyle(color: Colors.grey, fontSize: 10)),
              ],
            ),
          ),
          const Spacer(),
          // Tombol Kirim
          Padding(
            padding: const EdgeInsets.all(30),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                minimumSize: const Size(double.infinity, 60),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              onPressed: () {
                // Notifikasi Logika Bluetooth
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Sending $cutOffTime ms to ECU...")),
                );
              },
              child: const Text("SEND TO ECU", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}
