import 'dart:convert';
import 'dart:async';
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
      home: const CallScreen(),
    );
  }
}

class CallScreen extends StatefulWidget {
  const CallScreen({super.key});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final TwilioVoiceService _voiceService = TwilioVoiceService();
  final TextEditingController _identityController = TextEditingController(text: 'agent_001');
  final TextEditingController _toController = TextEditingController(text: 'client:agent_002');
  final TextEditingController _backendController = TextEditingController(text: 'http://localhost:3000');

  String _status = 'Idle';
  String _caller = '';
  bool _isRegistered = false;
  bool _isInCall = false;
  bool _hasIncomingCall = false;
  bool _isMuted = false;
  bool _isSpeakerOn = false;

  Timer? _callTimer;
  int _callDurationSeconds = 0;

  @override
  void initState() {
    super.initState();
    _voiceService.callEvents.listen((event) {
      debugPrint("Call Event: $event");
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
      setState(() {
        _callDurationSeconds++;
      });
    });
  }

  void _stopTimer() {
    _callTimer?.cancel();
    _callTimer = null;
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds / 60).floor();
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      _voiceService.toggleMute(_isMuted);
    });
  }

  void _toggleSpeaker() {
    setState(() {
      _isSpeakerOn = !_isSpeakerOn;
      _voiceService.toggleSpeaker(_isSpeakerOn);
    });
  }

  Future<void> _register() async {
    try {
      final response = await http.get(Uri.parse(
          '${_backendController.text}/token?identity=${_identityController.text}'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final token = data['token'];
        await _voiceService.registerToken(token);
        setState(() {
          _isRegistered = true;
          _status = 'Registered as ${_identityController.text}';
        });
      } else {
        setState(() => _status = 'Failed to get token: ${response.statusCode}');
      }
    } catch (e) {
      setState(() => _status = 'Error: $e');
    }
  }

  void _makeCall() {
    _voiceService.makeCall(_toController.text);
  }

  void _disconnect() {
    _voiceService.disconnect();
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
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 40),
          const Center(
            child: Text(
              'twilio',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 48,
                fontWeight: FontWeight.w900,
                color: Color(0xFFF22F46),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'App-to-App Voice',
              style: TextStyle(
                fontSize: 18,
                color: Colors.white70,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 60),
          _buildStatusCard(),
          const SizedBox(height: 32),
          if (!_isRegistered)
            _buildRegistrationPanel()
          else
            _buildCallPanel(),
          const SizedBox(height: 40),
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
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.05),
          ),
          child: Icon(
            _hasIncomingCall ? Icons.call_received : Icons.person,
            size: 80,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 32),
        Text(
          _hasIncomingCall ? _caller : _toController.text,
          style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Text(
          _isInCall ? 'INCALL' : 'RINGING...',
          style: const TextStyle(fontSize: 14, color: Colors.blueAccent, letterSpacing: 2),
        ),
        if (_isInCall && _status == 'connected') ...[
          const SizedBox(height: 8),
          Text(
            _formatDuration(_callDurationSeconds),
            style: const TextStyle(fontSize: 20, fontFamily: 'Courier', color: Colors.white54),
          ),
        ],
        const Spacer(),
        if (_hasIncomingCall)
          _buildIncomingCallControls()
        else if (_isInCall)
          Padding(
            padding: const EdgeInsets.only(bottom: 60),
            child: _buildActiveCallControls(),
          ),
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
          _buildFabButton(Icons.call, Colors.greenAccent, () {
            _voiceService.answerCall();
          }, isHeavy: true),
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
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isInCall ? Colors.green : (_isRegistered ? Colors.blue : Colors.grey),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _status.toUpperCase(),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegistrationPanel() {
    return Column(
      children: [
        _buildTextField(_backendController, 'Backend URL', Icons.link),
        const SizedBox(height: 16),
        _buildTextField(_identityController, 'Your Identity', Icons.person),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _register,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF22F46),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: const Center(child: Text('REGISTER', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
        ),
      ],
    );
  }

  Widget _buildCallPanel() {
    return Column(
      children: [
        _buildTextField(_toController, 'Dial Recipient (client:id or number)', Icons.phone),
        const SizedBox(height: 32),
        if (!_isInCall)
          GestureDetector(
            onTap: _makeCall,
            child: Container(
              height: 80,
              width: 80,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [Color(0xFF2ecc71), Color(0xFF27ae60)]),
                boxShadow: [BoxShadow(color: Colors.greenAccent, blurRadius: 15, spreadRadius: 1)],
              ),
              child: const Icon(Icons.call, size: 36, color: Colors.white),
            ),
          ),
      ],
    );
  }

  Widget _buildActiveCallControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildFabButton(
          _isMuted ? Icons.mic_off : Icons.mic,
          _isMuted ? Colors.redAccent.withOpacity(0.5) : Colors.white24,
          _toggleMute,
        ),
        const SizedBox(width: 40),
        _buildFabButton(Icons.call_end, Colors.redAccent, _disconnect, isHeavy: true),
        const SizedBox(width: 40),
        _buildFabButton(
          _isSpeakerOn ? Icons.volume_up : Icons.volume_down,
          _isSpeakerOn ? Colors.blueAccent.withOpacity(0.5) : Colors.white24,
          _toggleSpeaker,
        ),
      ],
    );
  }

  Widget _buildFabButton(IconData icon, Color color, VoidCallback onTap, {bool isHeavy = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(isHeavy ? 20 : 16),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
        ),
        child: Icon(icon, color: Colors.white, size: isHeavy ? 32 : 24),
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
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        labelStyle: const TextStyle(color: Colors.white54),
      ),
    );
  }
}
