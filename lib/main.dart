import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:geolocator/geolocator.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:async';
import 'dart:math' as math;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '킥보드 대여 앱',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

// 1. 홈 화면 (수정됨)
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.blue.shade400, Colors.blue.shade700],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.electric_scooter,
                  size: 120,
                  color: Colors.white,
                ),
                const SizedBox(height: 30),
                const Text(
                  '킥보드 대여',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  '빠르고 편리한 이동',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 80),
                // 대여하기 버튼
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MapPage(isAuthenticated: false),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 20),
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.blue.shade700,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text(
                    '대여하기',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 20),
                // 정리하기 버튼 (새로 추가)
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const NFCAuthPage(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 20),
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.green.shade700,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text(
                    '정리하기',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// 2. 지도 화면
class MapPage extends StatefulWidget {
  final bool isAuthenticated;

  const MapPage({super.key, required this.isAuthenticated});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  Position? _currentPosition;
  bool _isLoading = true;
  late WebViewController _webViewController;
  double _currentSpeed = 0.0;
  Timer? _speedTimer;
  String _currentZone = 'normal'; // normal, restricted, extra_cost, not_folded
  bool _showDebugButtons = true; // 🔧 false로 변경하면 테스트 버튼 숨김

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    if (widget.isAuthenticated) {
      _startSpeedTracking();
    }
  }

  @override
  void dispose() {
    _speedTimer?.cancel();
    super.dispose();
  }

  void _startSpeedTracking() {
    _speedTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentSpeed = position.speed * 3.6; // m/s to km/h
        _currentZone = _checkZone(position.latitude, position.longitude);
      });
      // 구역이 변경되면 폴리곤 업데이트
      _updateZonePolygon();
    });
  }

  // 구역 체크 (프로토타입용 mock 로직)
  String _checkZone(double lat, double lng) {
    double hash = (lat * 1000 + lng * 1000) % 10;
    
    if (hash < 2) {
      return 'restricted'; // 빨간 구역 (반납 불가)
    } else if (hash < 4) {
      return 'extra_cost'; // 회색 구역 (추가 비용)
    } else if (hash < 6) {
      return 'not_folded'; // 킥보드 접히지 않음 (반납 불가)
    } else {
      return 'normal'; // 파란 구역 (정상)
    }
  }

  void _initializeWebView(double lat, double lng) {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadHtmlString(
        _getNaverMapHtml(lat, lng),
        baseUrl: 'http://localhost',
      );
  }

  // 구역 폴리곤 업데이트
  void _updateZonePolygon() {
    if (_currentPosition == null) return;
    
    String polygonColor = '';
    String polygonOpacity = '0.3';
    
    if (_currentZone == 'normal') {
      polygonColor = '#4285F4'; // 파란색
    } else if (_currentZone == 'extra_cost') {
      polygonColor = '#757575'; // 회색
    } else {
      // restricted, not_folded는 폴리곤 표시 안함
      _webViewController.runJavaScript('removePolygon();');
      return;
    }
    
    // 현재 위치 주변에 다각형 폴리곤 생성 (예시)
    double lat = _currentPosition!.latitude;
    double lng = _currentPosition!.longitude;
    
    // 불규칙한 다각형 좌표 생성
    String polygonCoords = '''
      [
        new naver.maps.LatLng(${lat + 0.002}, ${lng - 0.003}),
        new naver.maps.LatLng(${lat + 0.003}, ${lng + 0.001}),
        new naver.maps.LatLng(${lat + 0.002}, ${lng + 0.004}),
        new naver.maps.LatLng(${lat - 0.001}, ${lng + 0.003}),
        new naver.maps.LatLng(${lat - 0.002}, ${lng + 0.001}),
        new naver.maps.LatLng(${lat - 0.001}, ${lng - 0.002})
      ]
    ''';
    
    _webViewController.runJavaScript('''
      updatePolygon($polygonCoords, '$polygonColor', $polygonOpacity);
    ''');
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
            map: map,
            icon: {
                content: '<div style="background: #4285F4; width: 20px; height: 20px; border-radius: 50%; border: 3px solid white; box-shadow: 0 2px 6px rgba(0,0,0,0.3);"></div>',
                anchor: new naver.maps.Point(10, 10)
            }
        });
        
        var currentPolygon = null;
        
        // 폴리곤 업데이트 함수
        function updatePolygon(paths, color, opacity) {
            // 기존 폴리곤 제거
            if (currentPolygon) {
                currentPolygon.setMap(null);
            }
            
            // 새 폴리곤 생성
            currentPolygon = new naver.maps.Polygon({
                map: map,
                paths: paths,
                fillColor: color,
                fillOpacity: opacity,
                strokeColor: color,
                strokeOpacity: 0.6,
                strokeWeight: 2
            });
        }
        
        // 폴리곤 제거 함수
        function removePolygon() {
            if (currentPolygon) {
                currentPolygon.setMap(null);
                currentPolygon = null;
            }
        }
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
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('GPS를 켜주세요')),
        );
      }
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          _isLoading = false;
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
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
        _isLoading = false;
      });

      _initializeWebView(position.latitude, position.longitude);
      
      // 초기 폴리곤 표시
      Future.delayed(const Duration(milliseconds: 1000), () {
        _updateZonePolygon();
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _handleReturn() {
    if (_currentZone == 'restricted') {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.error, color: Colors.red),
              SizedBox(width: 10),
              Text('반납 불가'),
            ],
          ),
          content: const Text('이 지역은 반납이 불가능한 지역입니다.\n다른 지역으로 이동해주세요.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('확인'),
            ),
          ],
        ),
      );
    } else if (_currentZone == 'not_folded') {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.orange),
              SizedBox(width: 10),
              Text('반납 불가'),
            ],
          ),
          content: const Text('킥보드가 접히지 않아 반납이 불가능합니다.\n킥보드를 접은 후 다시 시도해주세요.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('확인'),
            ),
          ],
        ),
      );
    } else if (_currentZone == 'extra_cost') {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning, color: Colors.orange),
              SizedBox(width: 10),
              Text('추가 비용 안내'),
            ],
          ),
          content: const Text('이 지역은 추가 비용이 발생하는 지역입니다.\n그래도 반납하시겠습니까?\n\n추가 비용: 2,000원'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PaymentMethodPage(
                      extraCost: 2000,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('반납하기'),
            ),
          ],
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const PaymentMethodPage(
            extraCost: 0,
          ),
        ),
      );
    }
  }

  void _showZoneSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text(
              '🔧 테스트용 구역 선택',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            _buildZoneOption(
              '정상 구역',
              '반납 가능한 지역입니다',
              Colors.blue,
              Icons.check_circle,
              'normal',
            ),
            const SizedBox(height: 10),
            _buildZoneOption(
              '추가 비용 구역',
              '반납 시 2,000원 추가됩니다',
              Colors.grey.shade700,
              Icons.attach_money,
              'extra_cost',
            ),
            const SizedBox(height: 10),
            _buildZoneOption(
              '반납 불가 구역',
              '이 지역에서는 반납할 수 없습니다',
              Colors.red,
              Icons.block,
              'restricted',
            ),
            const SizedBox(height: 10),
            _buildZoneOption(
              '킥보드 접히지 않음',
              '킥보드가 접히지 않아 반납 불가',
              Colors.orange,
              Icons.warning_amber,
              'not_folded',
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildZoneOption(String title, String description, Color color, IconData icon, String zoneType) {
    bool isSelected = _currentZone == zoneType;
    
    return InkWell(
      onTap: () {
        setState(() {
          _currentZone = zoneType;
        });
        _updateZonePolygon(); // 구역 변경 시 폴리곤 업데이트
        Navigator.pop(context);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? color : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: color, size: 24),
          ],
        ),
      ),
    );
  }

  void _showSpeedSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text(
              '🔧 테스트용 속도 선택',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            _buildSpeedOption('정지', '0 km/h', Colors.blueGrey, 0.0),
            const SizedBox(height: 10),
            _buildSpeedOption('느린 속도', '15 km/h', Colors.green, 15.0),
            const SizedBox(height: 10),
            _buildSpeedOption('보통 속도', '25 km/h', Colors.orange, 25.0),
            const SizedBox(height: 10),
            _buildSpeedOption('빠른 속도', '35 km/h', Colors.red, 35.0),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSpeedOption(String title, String speedText, Color color, double speed) {
    bool isSelected = (_currentSpeed - speed).abs() < 0.1;
    
    return InkWell(
      onTap: () {
        setState(() {
          _currentSpeed = speed;
        });
        Navigator.pop(context);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.speed, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? color : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    speedText,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: color, size: 24),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isAuthenticated ? '주행 중' : '킥보드 찾기'),
        backgroundColor: Colors.blue,
        automaticallyImplyLeading: !widget.isAuthenticated,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            // 지도
            _currentPosition != null
                ? WebViewWidget(controller: _webViewController)
                : const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 20),
                        Text('위치 정보를 가져오는 중...'),
                      ],
                    ),
                  ),
            
            // 속도 표시 (인증 후에만)
            if (widget.isAuthenticated)
              Positioned(
                top: 20,
                right: 20,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _showDebugButtons ? _showSpeedSelector : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: _showDebugButtons
                          ? [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${_currentSpeed.toStringAsFixed(1)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const Text(
                          'km/h',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            
            // 구역 표시 (인증 후에만)
            if (widget.isAuthenticated)
              Positioned(
                top: 20,
                left: 20,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _showDebugButtons ? _showZoneSelector : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                    decoration: BoxDecoration(
                      color: _currentZone == 'restricted'
                          ? Colors.red
                          : _currentZone == 'extra_cost'
                              ? Colors.grey.shade700
                              : _currentZone == 'not_folded'
                                  ? Colors.orange
                                  : Colors.blue,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: _showDebugButtons
                          ? [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _currentZone == 'restricted'
                              ? Icons.block
                              : _currentZone == 'extra_cost'
                                  ? Icons.attach_money
                                  : _currentZone == 'not_folded'
                                      ? Icons.warning_amber
                                      : Icons.check_circle,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _currentZone == 'restricted'
                              ? '반납 불가'
                              : _currentZone == 'extra_cost'
                                  ? '추가 비용'
                                  : _currentZone == 'not_folded'
                                      ? '접히지 않음'
                                      : '정상 구역',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            
            // 하단 버튼
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!widget.isAuthenticated)
                      ElevatedButton(
                        onPressed: _currentPosition != null
                            ? () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const NFCAuthPage(),
                                  ),
                                );
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          backgroundColor: Colors.blue,
                          minimumSize: const Size(double.infinity, 56),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.nfc, color: Colors.white),
                            SizedBox(width: 10),
                            Text(
                              'NFC 태그 인증',
                              style: TextStyle(fontSize: 18, color: Colors.white),
                            ),
                          ],
                        ),
                      )
                    else
                      ElevatedButton(
                        onPressed: _handleReturn,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          backgroundColor: Colors.red,
                          minimumSize: const Size(double.infinity, 56),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.logout, color: Colors.white),
                            SizedBox(width: 10),
                            Text(
                              '반납하기',
                              style: TextStyle(fontSize: 18, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// 결제 수단 화면
class PaymentMethodPage extends StatefulWidget {
  final int extraCost;

  const PaymentMethodPage({super.key, this.extraCost = 0});

  @override
  State<PaymentMethodPage> createState() => _PaymentMethodPageState();
}

class _PaymentMethodPageState extends State<PaymentMethodPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('결제 수단'),
        backgroundColor: Colors.blue,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 등록된 카드
                    const Text(
                      '등록된 카드',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 15),

                    // 신한카드
                    Center(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 400),
                        child: AspectRatio(
                          aspectRatio: 1.586, // 실제 신용카드 비율
                          child: Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.blue.shade700, Colors.blue.shade900],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.withOpacity(0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      '신한카드',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.3),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Text(
                                        '주카드',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const Icon(
                                  Icons.credit_card,
                                  color: Colors.white,
                                  size: 60,
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text(
                                      '**** **** **** 1234',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.white,
                                        letterSpacing: 2,
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '현재 적립 포인트 : 9000P',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.white.withOpacity(0.9),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '운전 면허 등록 여부 : Y',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.white.withOpacity(0.9),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    // 카드 추가 버튼
Center(
  child: Container(
    constraints: const BoxConstraints(maxWidth: 400),
    child: AspectRatio(
      aspectRatio: 1.586,  // 신한카드와 동일한 비율
      child: InkWell(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('카드 추가 기능은 준비 중입니다'),
              duration: Duration(seconds: 2),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.grey.shade300,
              width: 2,
              style: BorderStyle.solid,
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_circle_outline, color: Colors.grey.shade600, size: 40),
                const SizedBox(height: 10),
                Text(
                  '카드 추가하기',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
),
                  ],
                ),
              ),
            ),
            // 하단 버튼
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () {
                  // 금액 결제 화면으로 이동
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PaymentAmountPage(
                        extraCost: widget.extraCost,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  backgroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  '계속',
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 금액 결제 화면 (신규)
class PaymentAmountPage extends StatefulWidget {
  final int extraCost;

  const PaymentAmountPage({super.key, this.extraCost = 0});

  @override
  State<PaymentAmountPage> createState() => _PaymentAmountPageState();
}

class _PaymentAmountPageState extends State<PaymentAmountPage> {
  final TextEditingController _pointsController = TextEditingController();
  final int _currentPoints = 9000;

  @override
  void dispose() {
    _pointsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const int basePrice = 2300;
    final int pointsToUse = int.tryParse(_pointsController.text) ?? 0;
    final int subtotal = basePrice + widget.extraCost;
    final int totalPrice = subtotal - pointsToUse;

    return Scaffold(
      appBar: AppBar(
        title: const Text('금액 결제'),
        backgroundColor: Colors.blue,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 현재 포인트 표시
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '내 포인트',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${_currentPoints.toString()}P',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    // 요금 상세
                    const Text(
                      '요금 상세',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 15),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          // 기본 요금
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                '기본 요금',
                                style: TextStyle(fontSize: 15),
                              ),
                              Text(
                                '${basePrice.toString()}원',
                                style: const TextStyle(
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                          if (widget.extraCost > 0) ...[
                            const SizedBox(height: 8),
                            // 추가 비용
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  '추가 비용',
                                  style: TextStyle(
                                    fontSize: 15,
                                  ),
                                ),
                                Text(
                                  '+${widget.extraCost.toString()}원',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: Colors.orange,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 8),
                          // 포인트 사용 입력
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Text(
                                '포인트 사용',
                                style: TextStyle(fontSize: 15),
                              ),
                              Row(
                                children: [
                                  SizedBox(
                                    width: 70,
                                    height: 30,
                                    child: TextField(
                                      controller: _pointsController,
                                      keyboardType: TextInputType.number,
                                      textAlign: TextAlign.right,
                                      textAlignVertical: TextAlignVertical.bottom,
                                      style: const TextStyle(fontSize: 15, letterSpacing: 0),
                                      decoration: InputDecoration(
                                        hintText: '0',
                                        hintStyle: const TextStyle(
                                          fontSize: 15,
                                          letterSpacing: 3,  // hint도 동일하게
                                        ),
                                        contentPadding: const EdgeInsets.only(
                                          left: 12,
                                          right: 0,  
                                          top: 8,
                                          bottom: 3,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        isDense: true,
                                      ),
                                      onChanged: (value) {
                                        setState(() {});
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 3),
                                  const Text(
                                    '원',
                                    style: TextStyle(fontSize: 15),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 15),
                          const Divider(),
                          const SizedBox(height: 15),
                          // 총 결제 금액
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                '총 결제 금액',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${totalPrice.toString()}원',
                                style: const TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // 결제 버튼
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () {
                  // 포인트 검증
                  if (pointsToUse > _currentPoints) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('보유 포인트가 부족합니다'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                    return;
                  }
                  
                  if (totalPrice < 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('포인트 사용 금액을 확인해주세요'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                    return;
                  }

                  // 반납 완료 화면으로 이동
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ReturnSuccessPage(
                        totalPrice: subtotal,
                      ),
                    ),
                    (route) => false,
                  );
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  backgroundColor: Colors.blue,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  '결제하기',
                  style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 3. NFC 인증 화면
class NFCAuthPage extends StatefulWidget {
  const NFCAuthPage({super.key});

  @override
  State<NFCAuthPage> createState() => _NFCAuthPageState();
}

class _NFCAuthPageState extends State<NFCAuthPage> {
  String _statusText = 'NFC 태그를 가까이 대세요';
  bool _isScanning = false;

  void _mockAuthentication() {
    setState(() {
      _isScanning = true;
      _statusText = '인증 중...';
    });

    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const AuthSuccessPage(userName: '홍길동'),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NFC 인증'),
        backgroundColor: Colors.blue,
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(30.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.nfc,
                  size: 150,
                  color: _isScanning ? Colors.blue : Colors.grey,
                ),
                const SizedBox(height: 40),
                Text(
                  _statusText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 20),
                ),
                const SizedBox(height: 60),
                if (!_isScanning)
                  ElevatedButton(
                    onPressed: _mockAuthentication,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                      backgroundColor: Colors.green,
                    ),
                    child: const Text(
                      '인증하기 (테스트용)',
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  )
                else
                  const CircularProgressIndicator(),
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

// 4. 인증 완료 화면
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
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const MapPage(isAuthenticated: true),
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
                '인증 완료!',
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
              const SizedBox(height: 40),
              const Text(
                '안전 운행하세요!',
                style: TextStyle(
                  fontSize: 18,
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

// 5. 반납 완료 화면
class ReturnSuccessPage extends StatefulWidget {
  final int totalPrice;

  const ReturnSuccessPage({super.key, required this.totalPrice});

  @override
  State<ReturnSuccessPage> createState() => _ReturnSuccessPageState();
}

class _ReturnSuccessPageState extends State<ReturnSuccessPage> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
          (route) => false,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // 적립 포인트 계산 (기본 요금의 1%, 추가 비용 제외)
    const int basePrice = 2300;
    final int rewardPoints = (basePrice * 0.01).round();
    
    return Scaffold(
      backgroundColor: Colors.blue,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.check_circle_outline,
                size: 150,
                color: Colors.white,
              ),
              const SizedBox(height: 40),
              const Text(
                '반납 완료!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '이용해주셔서 감사합니다',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 60),
              Container(
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.symmetric(horizontal: 40),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '이용 시간',
                          style: TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                        Text(
                          '23분',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '이용 요금',
                          style: TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                        Text(
                          '${widget.totalPrice.toString()}원',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '적립 포인트',
                          style: TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                        Text(
                          '${rewardPoints.toString()}원',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}