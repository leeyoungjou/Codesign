import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:geolocator/geolocator.dart';
import 'package:webview_flutter/webview_flutter.dart';

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
      body: SafeArea(
        child: Center(
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

  void _mockAuthentication() {
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
      body: SafeArea(
        child: Center(
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
      ),
    );
  }
}

// 3. 인증 완료 화면
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
      body: SafeArea(
        child: Center(
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
      ),
    );
  }
}

// 4. GPS 위치 확인 화면 (네이버 지도)
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
  late WebViewController _webViewController;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  void _initializeWebView(double lat, double lng) {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadHtmlString(
        _getNaverMapHtml(lat, lng),
        baseUrl: 'http://localhost',  
      );
  }

  String _getNaverMapHtml(double lat, double lng) {
    return '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
    <title>네이버 지도</title>
    <style>
        body, html { margin: 0; padding: 0; width: 100%; height: 100%; }
        #map { width: 100%; height: 100%; }
    </style>
    <script type="text/javascript" src="https://oapi.map.naver.com/openapi/v3/maps.js?ncpKeyId=lvipoxk1bz"></script>
</head>
<body>
    <div id="map"></div>
    <script>
        var mapOptions = {
            center: new naver.maps.LatLng($lat, $lng),
            zoom: 16
        };
        
        var map = new naver.maps.Map('map', mapOptions);
        
        var marker = new naver.maps.Marker({
            position: new naver.maps.LatLng($lat, $lng),
            map: map
        });
    </script>
</body>
</html>
    ''';
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _statusText = 'GPS를 켜주세요';
        _isLoading = false;
      });
      return;
    }

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

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      setState(() {
        _currentPosition = position;
        _statusText = 'GPS 위치 확인 완료!';
        _isLoading = false;
      });
      
      // GPS 위치로 지도 초기화
      _initializeWebView(position.latitude, position.longitude);
      
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
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _currentPosition != null
                  ? WebViewWidget(controller: _webViewController)
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.location_searching,
                            size: 60,
                            color: Colors.orange,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _statusText,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  if (_currentPosition != null)
                    ElevatedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('다음 단계 준비 중...')),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                        backgroundColor: Colors.blue,
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: const Text(
                        '다음',
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
                    ),
                  const SizedBox(height: 10),
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
          ],
        ),
      ),
    );
  }
}