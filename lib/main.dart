import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NFC + GPS 인증 앱',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const StartPage(),
    );
  }
}

// 1. 시작 화면
class StartPage extends StatelessWidget {
  const StartPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NFC 인증'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.nfc, size: 120, color: Colors.blue),
            const SizedBox(height: 40),
            const Text(
              'NFC 인증 시스템',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 60),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const NFCAuthPage()),
                );
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
                backgroundColor: Colors.blue,
              ),
              child: const Text(
                'NFC 인증 시작',
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 2. NFC 인증 화면
class NFCAuthPage extends StatefulWidget {
  const NFCAuthPage({super.key});

  @override
  State<NFCAuthPage> createState() => _NFCAuthPageState();
}

class _NFCAuthPageState extends State<NFCAuthPage> {
  String _statusText = 'NFC 태그를 가까이 대세요';

  // 임시 인증 확인 버튼 (NFC 없을 때)
  void _mockAuthentication() {
    // 인증 완료 화면으로 이동 (1초 후 자동으로 GPS 화면으로)
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const AuthSuccessPage(userName: '테스트 사용자'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NFC 인증 중'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.nfc,
                size: 150,
                color: Colors.grey,
              ),
              const SizedBox(height: 40),
              Text(
                _statusText,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20),
              ),
              const SizedBox(height: 60),
              
              // 임시 확인 버튼
              ElevatedButton(
                onPressed: _mockAuthentication,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  backgroundColor: Colors.green,
                ),
                child: const Text(
                  '확인 (임시)',
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '※ NFC 없을 때 테스트용',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 3. 인증 완료 화면 (1초만 표시)
class AuthSuccessPage extends StatefulWidget {
  final String userName;

  const AuthSuccessPage({super.key, required this.userName});

  @override
  State<AuthSuccessPage> createState() => _AuthSuccessPageState();
}

class _AuthSuccessPageState extends State<AuthSuccessPage> {
  @override
  void initState() {
    super.initState();
    // 1초 후 GPS 화면으로 자동 이동
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => GPSCheckPage(userName: widget.userName),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.check_circle,
              size: 150,
              color: Colors.white,
            ),
            const SizedBox(height: 40),
            const Text(
              '사용자 인증이\n확인됐습니다!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              widget.userName,
              style: const TextStyle(
                fontSize: 24,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 4. GPS 위치 확인 화면
class GPSCheckPage extends StatefulWidget {
  final String userName;

  const GPSCheckPage({super.key, required this.userName});

  @override
  State<GPSCheckPage> createState() => _GPSCheckPageState();
}

class _GPSCheckPageState extends State<GPSCheckPage> {
  String _statusText = 'GPS 위치 확인 중...';
  Position? _currentPosition;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  // GPS 위치 가져오기
  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // GPS 서비스 활성화 확인
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _statusText = 'GPS를 켜주세요';
        _isLoading = false;
      });
      return;
    }

    // 위치 권한 확인
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          _statusText = 'GPS 권한이 필요합니다';
          _isLoading = false;
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _statusText = 'GPS 권한이 영구적으로 거부되었습니다\n설정에서 권한을 허용해주세요';
        _isLoading = false;
      });
      return;
    }

    // 현재 위치 가져오기
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _currentPosition = position;
        _statusText = 'GPS 위치 확인 완료!';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _statusText = 'GPS 오류: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GPS 위치 확인'),
        backgroundColor: Colors.blue,
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isLoading ? Icons.location_searching : Icons.location_on,
                size: 120,
                color: _isLoading ? Colors.orange : Colors.green,
              ),
              const SizedBox(height: 40),
              Text(
                _statusText,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 40),
              
              // GPS 정보 표시
              if (_currentPosition != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.blue),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        '현재 위치',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('위도:', style: TextStyle(fontSize: 16)),
                          Text(
                            _currentPosition!.latitude.toStringAsFixed(6),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('경도:', style: TextStyle(fontSize: 16)),
                          Text(
                            _currentPosition!.longitude.toStringAsFixed(6),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('정확도:', style: TextStyle(fontSize: 16)),
                          Text(
                            '±${_currentPosition!.accuracy.toStringAsFixed(1)}m',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              
              const SizedBox(height: 60),
              
              // 다음 단계 버튼
              if (_currentPosition != null)
                ElevatedButton(
                  onPressed: () {
                    // 여기에 다음 단계 추가 (분양지 정보 등)
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('다음 단계 준비 중...')),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                    backgroundColor: Colors.blue,
                  ),
                  child: const Text(
                    '다음',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              
              const SizedBox(height: 20),
              
              // 처음으로 버튼
              TextButton(
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const StartPage()),
                    (route) => false,
                  );
                },
                child: const Text('처음으로'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
