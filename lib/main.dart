import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart'; // For defaultTargetPlatform
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'services/twilio_voice_service.dart';

void main() {
  runApp(const TwilioApp());
}

class TwilioApp extends StatelessWidget {
  const TwilioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Twilio App-to-App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFFF22F46), // Twilio Red
        scaffoldBackgroundColor: const Color(0xFF0D122B),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFF22F46),
          secondary: Color(0xFF008CFF),
        ),
        useMaterial3: true,
      ),
      home: const RegistrationScreen(),
    );
  }
}

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final TextEditingController _identityController = TextEditingController(text: 'agent_001');
  final TextEditingController _backendController = TextEditingController(text: 'http://localhost:3000');
  String _status = 'Idle';
  bool _isLoading = false;

  Future<void> _register() async {
    setState(() {
      _isLoading = true;
      _status = 'Registering...';
    });
    try {
      print("Step: Requesting permission...");
      await TwilioVoiceService().requestPermission();
      print("Step: Permission granted or handled.");

      final String platform = defaultTargetPlatform == TargetPlatform.android ? 'android' : 'ios';
      
      print("Fetching token from: ${_backendController.text}");
      final response = await http.get(Uri.parse(
          '${_backendController.text}/token?identity=${_identityController.text}&platform=$platform'))
          .timeout(const Duration(seconds: 15));
      print("Response received: ${response.statusCode}");
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final token = data['token'];
        final identity = data['identity'];
        
        await TwilioVoiceService().registerToken(token);
        
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => HomeScreen(
                identity: identity,
                backendUrl: _backendController.text,
              ),
            ),
          );
        }
      } else {
        setState(() => _status = 'Failed: ${response.statusCode}');
      }
    } catch (e) {
      setState(() => _status = 'Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1B244A), Color(0xFF0D122B)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'twilio',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFF22F46),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Voice Registration',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, color: Colors.white70),
                  ),
                  const SizedBox(height: 60),
                  _buildTextField(_backendController, 'Backend URL', Icons.link),
                  const SizedBox(height: 16),
                  _buildTextField(_identityController, 'Your Identity', Icons.person),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _register,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF22F46),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 8,
                    ),
                    child: _isLoading 
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('GET STARTED', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  ),
                  const SizedBox(height: 24),
                  Text(_status, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.white54),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        labelStyle: const TextStyle(color: Colors.white54),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final String identity;
  final String backendUrl;
  const HomeScreen({super.key, required this.identity, required this.backendUrl});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TwilioVoiceService _voiceService = TwilioVoiceService();
  final TextEditingController _toController = TextEditingController(text: 'client:agent_002');

  String _status = 'Idle';
  String _caller = '';
  bool _isInCall = false;
  bool _hasIncomingCall = false;
  bool _isMuted = false;
  bool _isSpeakerOn = false;

  Timer? _callTimer;
  int _callDurationSeconds = 0;

  @override
  void initState() {
    super.initState();
    _status = 'Logged in as ${widget.identity}';
    _voiceService.callEvents.listen((event) {
      if (!mounted) return;
      setState(() {
        if (event.startsWith('incoming_call|')) {
          _status = 'Incoming Call';
          _caller = event.split('|')[1];
          _hasIncomingCall = true;
          _isInCall = false;
          _stopTimer();
        } else if (event == 'cancelled') {
          _status = 'Call Cancelled';
          _hasIncomingCall = false;
          _isInCall = false;
          _stopTimer();
        } else {
          _status = event;
          if (event == 'connected' || event == 'ringing') {
            _isInCall = true;
            _hasIncomingCall = false;
            if (event == 'connected') _startTimer();
          } else if (event == 'disconnected' || event.startsWith('error')) {
            _isInCall = false;
            _hasIncomingCall = false;
            _isMuted = false;
            _isSpeakerOn = false;
            _stopTimer();
          }
        }
      });
    });
  }

  void _startTimer() {
    _callTimer?.cancel();
    _callDurationSeconds = 0;
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => _callDurationSeconds++);
    });
  }

  void _stopTimer() {
    _callTimer?.cancel();
    _callTimer = null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1B244A), Color(0xFF0D122B)],
          ),
        ),
        child: SafeArea(
          child: _isInCall || _hasIncomingCall 
            ? _buildFullScreenCallUI() 
            : _buildDashboardUI(),
        ),
      ),
    );
  }

  Widget _buildDashboardUI() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Welcome back,', style: TextStyle(color: Colors.white54, fontSize: 16)),
                  Text(widget.identity, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.white54),
                onPressed: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const RegistrationScreen()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
          _buildStatusCard(),
          const SizedBox(height: 32),
          const Text('Make a Call', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(
            controller: _toController,
            decoration: InputDecoration(
              hintText: 'client:id or number',
              prefixIcon: const Icon(Icons.phone, color: Colors.white54),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
          ),
          const Spacer(),
          Center(
            child: GestureDetector(
              onTap: () => _voiceService.makeCall(_toController.text),
              child: Container(
                height: 90,
                width: 90,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [Color(0xFF2ecc71), Color(0xFF27ae60)]),
                  boxShadow: [BoxShadow(color: Colors.greenAccent, blurRadius: 20, spreadRadius: 2)],
                ),
                child: const Icon(Icons.call, size: 40, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Container(
            width: 12, height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isInCall ? Colors.green : Colors.blue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(_status.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1))),
        ],
      ),
    );
  }

  Widget _buildFullScreenCallUI() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(),
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.05)),
          child: Icon(_hasIncomingCall ? Icons.call_received : Icons.person, size: 80, color: Colors.white70),
        ),
        const SizedBox(height: 32),
        Text(_hasIncomingCall ? _caller : _toController.text, style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Text(_isInCall ? 'INCALL' : 'RINGING...', style: const TextStyle(fontSize: 14, color: Colors.blueAccent, letterSpacing: 2)),
        if (_isInCall && _status == 'connected') ...[
          const SizedBox(height: 8),
          Text(_formatDuration(_callDurationSeconds), style: const TextStyle(fontSize: 20, fontFamily: 'Courier', color: Colors.white54)),
        ],
        const Spacer(),
        if (_hasIncomingCall)
          _buildIncomingCallControls()
        else
          Padding(padding: const EdgeInsets.only(bottom: 60), child: _buildActiveCallControls()),
      ],
    );
  }

  Widget _buildIncomingCallControls() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 60),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildFabButton(Icons.call_end, Colors.redAccent, () {
            _voiceService.rejectCall();
            setState(() => _hasIncomingCall = false);
          }, isHeavy: true),
          _buildFabButton(Icons.call, Colors.greenAccent, () => _voiceService.answerCall(), isHeavy: true),
        ],
      ),
    );
  }

  Widget _buildActiveCallControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildFabButton(_isMuted ? Icons.mic_off : Icons.mic, _isMuted ? Colors.redAccent.withOpacity(0.5) : Colors.white24, () {
          setState(() {
            _isMuted = !_isMuted;
            _voiceService.toggleMute(_isMuted);
          });
        }),
        const SizedBox(width: 40),
        _buildFabButton(Icons.call_end, Colors.redAccent, () => _voiceService.disconnect(), isHeavy: true),
        const SizedBox(width: 40),
        _buildFabButton(_isSpeakerOn ? Icons.volume_up : Icons.volume_down, _isSpeakerOn ? Colors.blueAccent.withOpacity(0.5) : Colors.white24, () {
          setState(() {
            _isSpeakerOn = !_isSpeakerOn;
            _voiceService.toggleSpeaker(_isSpeakerOn);
          });
        }),
      ],
    );
  }

  Widget _buildFabButton(IconData icon, Color color, VoidCallback onTap, {bool isHeavy = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(isHeavy ? 20 : 16),
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        child: Icon(icon, color: Colors.white, size: isHeavy ? 32 : 24),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds / 60).floor();
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}
