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
      debugShowCheckedModeBanner: false,
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
                  style: TextStyle(fontSize: 18, color: Colors.white70),
                ),
                const SizedBox(height: 80),
                // 대여하기 버튼
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const MapPage(isAuthenticated: false),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 60,
                      vertical: 20,
                    ),
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
                        builder: (context) => const NFCAuthPage(
                          isCleanupMode: true,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 60,
                      vertical: 20,
                    ),
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
                const SizedBox(height: 15),
                // 대여하기란? 텍스트 버튼
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RentalGuidePage(),
                      ),
                    );
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '대여하기란?',
                        style: TextStyle(
                          fontSize: 17,
                          color: Colors.white.withOpacity(0.85),
                          decoration: TextDecoration.underline,
                          decorationColor: Colors.white.withOpacity(0.85),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                // 정리하기란? 텍스트 버튼 - 가이드 페이지로 이동
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CleanupGuidePage(),
                      ),
                    );
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '정리하기란?',
                        style: TextStyle(
                          fontSize: 17,
                          color: Colors.white.withOpacity(0.85),
                          decoration: TextDecoration.underline,
                          decorationColor: Colors.white.withOpacity(0.85),
                        ),
                      ),
                    ],
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
  final bool isCleanupMode; // 추가

  const MapPage({
    super.key,
    required this.isAuthenticated,
    this.isCleanupMode = false, // 추가
  });

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  Position? _currentPosition;
  bool _isLoading = true;
  late WebViewController _webViewController;
  double _currentSpeed = 0.0;
  Timer? _speedTimer;
  Timer? _rideTimer;
  int _rideSeconds = 0;
  String _currentZone = 'normal'; // normal, restricted, extra_cost, not_folded
  bool _showDebugButtons = true; // 🔧 false로 변경하면 테스트 버튼 숨김

  // 요금 계산
  int get _baseFare => 1000;
  int get _perMinuteFare => 200;
  int get _totalFare => _baseFare + ((_rideSeconds ~/ 60) * _perMinuteFare);
  int get _rideMinutes => _rideSeconds ~/ 60;
  int get _earnedPoints => (_totalFare * 0.01).floor();

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    if (widget.isAuthenticated && !widget.isCleanupMode) {
      _startSpeedTracking();
      _startRideTimer();
    }
  }

  @override
  void dispose() {
    _speedTimer?.cancel();
    _rideTimer?.cancel();
    super.dispose();
  }

  void _startRideTimer() {
    _rideTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _rideSeconds++;
      });
    });
  }

  String _formatRideTime() {
    int minutes = _rideSeconds ~/ 60;
    int seconds = _rideSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
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
      ..loadHtmlString(_getNaverMapHtml(lat, lng), baseUrl: 'http://localhost');
  }

  // 구역 폴리곤 업데이트 (자동 폴리곤 생성 제거)
  void _updateZonePolygon() {
    // 자동으로 생성되는 폴리곤을 표시하지 않음
    // 경희대 주변 직접 생성한 폴리곤만 유지
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: color.withOpacity(0.5),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String _getNaverMapHtml(double lat, double lng) {
    // 테스트용: 지도 중심을 경희대 국제캠퍼스로 고정
    double fixedLat = 37.2410;
    double fixedLng = 127.0805;
    
    // 킥보드 마커는 킥보드 찾기 화면에서만 표시
    String scooterMarkersScript = '';
    if (!widget.isAuthenticated && !widget.isCleanupMode) {
      scooterMarkersScript = '''
        // 킥보드 위치 데이터 (경희대 국제캠퍼스 주변)
        var scooterLocations = [
            { lat: 37.251093, lng: 127.075578 },
            { lat: 37.253434, lng: 127.075776 },
            { lat: 37.251237, lng: 127.079475 },
            { lat: 37.249111, lng: 127.072528 },
            { lat: 37.242877, lng: 127.075054 },
            { lat: 37.239085, lng: 127.077653 },
            { lat: 37.237735, lng: 127.078898 },
            { lat: 37.245578, lng: 127.073773 },
            { lat: 37.244271, lng: 127.072997 },
            { lat: 37.237562, lng: 127.070760 },
        ];
        
        // 킥보드 마커 생성
        scooterLocations.forEach(function(scooter) {
            var markerContent = 
              '<div style="' +
              'background: white;' +
              'border: 3px solid #2196F3;' +
              'border-radius: 50%;' +
              'width: 45px;' +
              'height: 45px;' +
              'display: flex;' +
              'align-items: center;' +
              'justify-content: center;' +
              'box-shadow: 0 2px 8px rgba(0,0,0,0.25);' +
              '">' +
              '<span class="material-icons" style="color: #2196F3; font-size: 28px;">electric_scooter</span>' +
              '</div>';
            
            var marker = new naver.maps.Marker({
                position: new naver.maps.LatLng(scooter.lat, scooter.lng),
                map: map,
                icon: {
                    content: markerContent,
                    anchor: new naver.maps.Point(22.5, 22.5)
                }
            });
        });
      ''';
    }
    
    return '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
    <title>네이버 지도</title>
    <link href="https://fonts.googleapis.com/icon?family=Material+Icons" rel="stylesheet">
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
            center: new naver.maps.LatLng($fixedLat, $fixedLng),
            zoom: 15
        };
        
        var map = new naver.maps.Map('map', mapOptions);
        
        $scooterMarkersScript
        
        // === 경희대 국제캠퍼스 주변 구역 데이터 ===
        
        // 반납 불가 구역 (빨간색) - 경희대 국제캠퍼스 부지만
        var restrictedZone1 = new naver.maps.Polygon({
            map: map,
            paths: [
                new naver.maps.LatLng(37.242830, 127.076456),
                new naver.maps.LatLng(37.246192, 127.075972),
                new naver.maps.LatLng(37.247380, 127.078319),
                new naver.maps.LatLng(37.247908, 127.080935),
                new naver.maps.LatLng(37.239478, 127.089177),
                new naver.maps.LatLng(37.236177, 127.084367),
            ],
            fillColor: '#F44336',
            fillOpacity: 0.35,
            strokeColor: '#F44336',
            strokeOpacity: 0.7,
            strokeWeight: 2
        });
        
        // 정상 구역 1 (파란색) - 영통역 아이파크 주변 상업지구
        var normalZone1 = new naver.maps.Polygon({
            map: map,
            paths: [
                new naver.maps.LatLng(37.251400, 127.071292),
                new naver.maps.LatLng(37.255787, 127.075540),
                new naver.maps.LatLng(37.253137, 127.080057),
                new naver.maps.LatLng(37.250395, 127.080771),
                new naver.maps.LatLng(37.248688, 127.079330),
                new naver.maps.LatLng(37.248749, 127.075732)
            ],
            fillColor: '#4285F4',
            fillOpacity: 0.3,
            strokeColor: '#4285F4',
            strokeOpacity: 0.6,
            strokeWeight: 2
        });
        
        
        // 정상 구역 3 (파란색) - 서천중학교 앞 상가
        var normalZone3 = new naver.maps.Polygon({
            map: map,
            paths: [
                new naver.maps.LatLng(37.243289, 127.073910),
                new naver.maps.LatLng(37.241525, 127.070860),
                new naver.maps.LatLng(37.240474, 127.071725),
                new naver.maps.LatLng(37.240124, 127.074912),
                new naver.maps.LatLng(37.243313, 127.075837)
            ],
            fillColor: '#4285F4',
            fillOpacity: 0.3,
            strokeColor: '#4285F4',
            strokeOpacity: 0.6,
            strokeWeight: 2
        });

                // 정상 구역 4 (파란색) - 서천중학교 앞 상가
        var normalZone4 = new naver.maps.Polygon({
            map: map,
            paths: [
                new naver.maps.LatLng(37.239882, 127.075003),
                new naver.maps.LatLng(37.238276, 127.076565),
                new naver.maps.LatLng(37.236403, 127.076672),
                new naver.maps.LatLng(37.236126, 127.078993),
                new naver.maps.LatLng(37.238687, 127.079160),
                new naver.maps.LatLng(37.240184, 127.077688),
                new naver.maps.LatLng(37.239931, 127.077021),
                new naver.maps.LatLng(37.240704, 127.075579)
            ],
            fillColor: '#4285F4',
            fillOpacity: 0.3,
            strokeColor: '#4285F4',
            strokeOpacity: 0.6,
            strokeWeight: 2
        });
        
        // 추가 비용 구역 1 (얇은 회색) - 서천마을 음용예가아파트
        var extraCostZone1 = new naver.maps.Polygon({
            map: map,
            paths: [
                new naver.maps.LatLng(37.234664, 127.068281),
                new naver.maps.LatLng(37.239061, 127.068357),
                new naver.maps.LatLng(37.240100, 127.070815),
                new naver.maps.LatLng(37.239834, 127.074517),
                new naver.maps.LatLng(37.234652, 127.070147),
            ],
            fillColor: '#616161',
            fillOpacity: 0.45,
            strokeColor: '#616161',
            strokeOpacity: 0.7,
            strokeWeight: 2
        });
        
        // 추가 비용 구역 2 (얇은 회색) - 휴먼시아 아파트
        var extraCostZone2 = new naver.maps.Polygon({
            map: map,
            paths: [
                new naver.maps.LatLng(37.243518, 127.075321),
                new naver.maps.LatLng(37.243373, 127.074077),
                new naver.maps.LatLng(37.245137, 127.068736),
                new naver.maps.LatLng(37.246272, 127.069510),
                new naver.maps.LatLng(37.247238, 127.075579)
            ],
            fillColor: '#9E9E9E',
            fillOpacity: 0.4,
            strokeColor: '#9E9E9E',
            strokeOpacity: 0.7,
            strokeWeight: 2
        });
        
        // 추가 비용 구역 3 (짙은 회색) - 영통뜨란채 아파트
        var extraCostZone3 = new naver.maps.Polygon({
            map: map,
            paths: [
                new naver.maps.LatLng(37.246767, 127.067355),
                new naver.maps.LatLng(37.251067, 127.071376),
                new naver.maps.LatLng(37.248603, 127.075594),
                new naver.maps.LatLng(37.247818, 127.075564),
            ],
            fillColor: '#9E9E9E',
            fillOpacity: 0.4,
            strokeColor: '#9E9E9E',
            strokeOpacity: 0.7,
            strokeWeight: 2
        });

        var extraCostZone4 = new naver.maps.Polygon({
            map: map,
            paths: [
                new naver.maps.LatLng(37.255897, 127.075922),
                new naver.maps.LatLng(37.253409, 127.079928),
                new naver.maps.LatLng(37.254496, 127.080535),
                new naver.maps.LatLng(37.256839, 127.079837),
                new naver.maps.LatLng(37.259049, 127.080231),
                new naver.maps.LatLng(37.259798, 127.079533),
            ],
            fillColor: '#616161',
            fillOpacity: 0.45,
            strokeColor: '#616161',
            strokeOpacity: 0.7,
            strokeWeight: 2
        });
        
        var currentPolygon = null;
        
        // 폴리곤 업데이트 함수
        function updatePolygon(paths, color, opacity) {
            if (currentPolygon) {
                currentPolygon.setMap(null);
            }
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('GPS를 켜주세요')));
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
          content: const Text(
            '이 지역은 추가 비용이 발생하는 지역입니다.\n그래도 반납하시겠습니까?\n\n추가 비용: 2,000원',
          ),
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
                    builder: (context) => PaymentMethodPage(
                      extraCost: 2000,
                      rideMinutes: _rideMinutes,
                      totalFare: _totalFare,
                      earnedPoints: _earnedPoints,
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
          builder: (context) => PaymentMethodPage(
            extraCost: 0,
            rideMinutes: _rideMinutes,
            totalFare: _totalFare,
            earnedPoints: _earnedPoints,
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
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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

  Widget _buildZoneOption(
    String title,
    String description,
    Color color,
    IconData icon,
    String zoneType,
  ) {
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
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            if (isSelected) Icon(Icons.check_circle, color: color, size: 24),
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
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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

  Widget _buildSpeedOption(
    String title,
    String speedText,
    Color color,
    double speed,
  ) {
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
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            if (isSelected) Icon(Icons.check_circle, color: color, size: 24),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isAuthenticated
            ? (widget.isCleanupMode ? '정리 중' : '주행 중')
            : '킥보드 찾기'),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
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
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // 범례 패널 (항상 표시) + 구역 표시 (인증 후에만)
            Positioned(
              top: 20,
              left: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 범례 (항상 표시)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLegendItem(Colors.blue, '정상 구역'),
                        const SizedBox(height: 8),
                        _buildLegendItem(Colors.grey, '추가 비용'),
                        const SizedBox(height: 8),
                        _buildLegendItem(Colors.red, '반납 불가'),
                      ],
                    ),
                  ),
                  // 현재 구역 표시 (인증 후에만)
                  if (widget.isAuthenticated) ...[
                    const SizedBox(height: 10),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _showDebugButtons ? _showZoneSelector : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 12,
                        ),
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
                  ],
                ],
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
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (widget.isCleanupMode) // 정리하기 모드
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                // 정리 완료
                                Navigator.pushAndRemoveUntil(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const CleanupSuccessPage(),
                                  ),
                                  (route) => false,
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 18,
                                ),
                                backgroundColor: Colors.green,
                                minimumSize: const Size(0, 56),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                '정리완료',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                // 정리 중단 확인 팝업
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('정리 중단'),
                                    content: const Text(
                                      '정리를 중단하시겠습니까?\n중단 시 포인트가 지급되지 않습니다.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('계속하기'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () {
                                          Navigator.pop(context);
                                          Navigator.pushAndRemoveUntil(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  const CleanupCancelPage(),
                                            ),
                                            (route) => false,
                                          );
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red,
                                        ),
                                        child: const Text('중단하기'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 18,
                                ),
                                backgroundColor: Colors.orange,
                                minimumSize: const Size(0, 56),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                '정리중단',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    else // 일반 대여하기 모드
                      Column(
                        children: [
                          // 탑승 시간 및 요금 표시
                          Container(
                            padding: const EdgeInsets.all(16),
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 5,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Column(
                                  children: [
                                    const Text(
                                      '탑승 시간',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatRideTime(),
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  width: 1,
                                  height: 40,
                                  color: Colors.grey.shade300,
                                ),
                                Column(
                                  children: [
                                    const Text(
                                      '예상 요금',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_totalFare.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}원',
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
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
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
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
  final int rideMinutes;
  final int totalFare;
  final int earnedPoints;

  const PaymentMethodPage({
    super.key,
    this.extraCost = 0,
    this.rideMinutes = 0,
    this.totalFare = 1000,
    this.earnedPoints = 10,
  });

  @override
  State<PaymentMethodPage> createState() => _PaymentMethodPageState();
}

class _PaymentMethodPageState extends State<PaymentMethodPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('결제 수단'), backgroundColor: Colors.blue),
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
                                colors: [
                                  Colors.blue.shade700,
                                  Colors.blue.shade900,
                                ],
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
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
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
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
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
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '현재 적립 포인트 : 9000P',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.white.withOpacity(
                                              0.9,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '운전 면허 등록 여부 : Y',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.white.withOpacity(
                                              0.9,
                                            ),
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
                          aspectRatio: 1.586, // 신한카드와 동일한 비율
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
                                    Icon(
                                      Icons.add_circle_outline,
                                      color: Colors.grey.shade600,
                                      size: 40,
                                    ),
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
                        rideMinutes: widget.rideMinutes,
                        totalFare: widget.totalFare,
                        earnedPoints: widget.earnedPoints,
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
  final int rideMinutes;
  final int totalFare;
  final int earnedPoints;

  const PaymentAmountPage({
    super.key,
    this.extraCost = 0,
    this.rideMinutes = 0,
    this.totalFare = 1000,
    this.earnedPoints = 10,
  });

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
    final int basePrice = widget.totalFare;
    final int pointsToUse = int.tryParse(_pointsController.text) ?? 0;
    final int subtotal = basePrice + widget.extraCost;
    final int totalPrice = subtotal - pointsToUse;

    return Scaffold(
      appBar: AppBar(title: const Text('금액 결제'), backgroundColor: Colors.blue),
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
                          // 이용 시간
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                '이용 시간',
                                style: TextStyle(fontSize: 15),
                              ),
                              Text(
                                '${widget.rideMinutes}분',
                                style: const TextStyle(fontSize: 15),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // 기본 요금
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                '이용 요금 (기본 1,000 + 분당 200)',
                                style: TextStyle(fontSize: 15),
                              ),
                              Text(
                                '${basePrice.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}원',
                                style: const TextStyle(fontSize: 15),
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
                                  style: TextStyle(fontSize: 15),
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
                                      textAlignVertical:
                                          TextAlignVertical.bottom,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        letterSpacing: 0,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: '0',
                                        hintStyle: const TextStyle(
                                          fontSize: 15,
                                          letterSpacing: 3, // hint도 동일하게
                                        ),
                                        contentPadding: const EdgeInsets.only(
                                          left: 12,
                                          right: 0,
                                          top: 8,
                                          bottom: 3,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
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
                  final int finalEarnedPoints = (totalPrice * 0.01).floor();
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ReturnSuccessPage(
                        totalPrice: totalPrice,
                        rideMinutes: widget.rideMinutes,
                        earnedPoints: finalEarnedPoints,
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
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
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
  final bool isCleanupMode; // 추가

  const NFCAuthPage({super.key, this.isCleanupMode = false});

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
            builder: (context) => AuthSuccessPage(
              userName: '홍길동',
              isCleanupMode: widget.isCleanupMode, // 추가
            ),
          ),
        );
      }
    });
  }

  // ... build는 동일

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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 15,
                      ),
                      backgroundColor: Colors.green,
                    ),
                    child: const Text(
                      '인증하기',
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  )
                else
                  const CircularProgressIndicator(),
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
  final bool isCleanupMode; // 추가

  const AuthSuccessPage({
    super.key,
    required this.userName,
    this.isCleanupMode = false, // 추가
  });

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
            builder: (context) => MapPage(
              isAuthenticated: true,
              isCleanupMode: widget.isCleanupMode, // 추가
            ),
          ),
        );
      }
    });
  }

  // ... build는 동일

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, size: 150, color: Colors.white),
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
                style: const TextStyle(fontSize: 24, color: Colors.white70),
              ),
              const SizedBox(height: 40),
              const Text(
                '안전 운행하세요!',
                style: TextStyle(fontSize: 18, color: Colors.white70),
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
  final int rideMinutes;
  final int earnedPoints;

  const ReturnSuccessPage({
    super.key,
    required this.totalPrice,
    this.rideMinutes = 0,
    this.earnedPoints = 0,
  });

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
                style: TextStyle(fontSize: 18, color: Colors.white70),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '이용 시간',
                          style: TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                        Text(
                          '${widget.rideMinutes}분',
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
                          '이용 요금',
                          style: TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                        Text(
                          '${widget.totalPrice.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}원',
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
                          '+${widget.earnedPoints}P',
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

// 정리 완료 화면
class CleanupSuccessPage extends StatefulWidget {
  const CleanupSuccessPage({super.key});

  @override
  State<CleanupSuccessPage> createState() => _CleanupSuccessPageState();
}

class _CleanupSuccessPageState extends State<CleanupSuccessPage> {
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
    return Scaffold(
      backgroundColor: Colors.green,
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
                '정리 완료!',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
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
                child: const Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '적립 포인트',
                          style: TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                        Text(
                          '500원',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '포인트 총합',
                          style: TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                        Text(
                          '9500원',
                          style: TextStyle(
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

// 정리 중단 화면
class CleanupCancelPage extends StatefulWidget {
  const CleanupCancelPage({super.key});

  @override
  State<CleanupCancelPage> createState() => _CleanupCancelPageState();
}

class _CleanupCancelPageState extends State<CleanupCancelPage> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
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
    return Scaffold(
      backgroundColor: Colors.orange,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cancel_outlined, size: 150, color: Colors.white),
              const SizedBox(height: 40),
              const Text(
                '정리중단!',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '포인트가 지급되지 않습니다',
                style: TextStyle(fontSize: 18, color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 정리하기 가이드 페이지
// 대여하기 가이드 페이지
class RentalGuidePage extends StatelessWidget {
  const RentalGuidePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('대여하기 가이드'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 대여하기란? 섹션
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade400, Colors.blue.shade600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.electric_scooter,
                      size: 50,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '대여하기란?',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '원하는 곳에서 킥보드를 대여하고\n목적지까지 편리하게 이동하세요!\n이용 요금은 반납 시 자동 결제됩니다.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.white,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.attach_money,
                            color: Colors.blue.shade600,
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '기본 1,000원 + 분당 200원',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              // 이용 방법 타이틀
              const Text(
                '이용 방법',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              // STEP 1
              _buildStepCard(
                stepNumber: 1,
                icon: Icons.qr_code_scanner,
                iconColor: Colors.blue,
                title: 'NFC 인증',
                subtitle: '대여하기 버튼을 누른 후',
                description: '킥보드의 NFC 태그에 휴대폰을 가까이 대세요.',
              ),
              // 연결선
              _buildConnector(),
              // STEP 2
              _buildStepCard(
                stepNumber: 2,
                icon: Icons.directions_bike,
                iconColor: Colors.orange,
                title: '주행하기',
                subtitle: '인증이 완료되면',
                description: '킥보드를 타고 목적지까지 이동하세요.',
              ),
              // 연결선
              _buildConnector(),
              // STEP 3
              _buildStepCard(
                stepNumber: 3,
                icon: Icons.location_on,
                iconColor: Colors.green,
                title: '반납하기',
                subtitle: '정상 구역에 도착하면',
                description: '반납하기 버튼을 눌러 결제를 완료하세요.',
              ),
              const SizedBox(height: 30),
              // 요금 안내
              // 구역 안내
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '🗺️ 구역 안내',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildZoneRow(Colors.blue, '정상 구역', '추가 비용 없이 반납 가능'),
                    const SizedBox(height: 8),
                    _buildZoneRow(Colors.grey, '추가 비용 구역', '반납 시 추가 요금 발생'),
                    const SizedBox(height: 8),
                    _buildZoneRow(Colors.red, '반납 불가 구역', '해당 구역에서 반납 불가'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // 요금 안내
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '💰 요금 안내',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildFeeRow('기본 요금', '1,000원'),
                    _buildFeeRow('분당 요금', '200원'),
                    _buildFeeRow('추가 비용 1단계 구역', '+1,000원'),
                    _buildFeeRow('추가 비용 2단계 구역', '+2,000원'),
                    const Divider(height: 20),
                    _buildFeeRow('포인트 적립', '결제 금액의 1%', isHighlight: true),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // 하단 버튼
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    '확인',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepCard({
    required int stepNumber,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: iconColor, size: 28),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: iconColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'STEP $stepNumber',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnector() {
    return Container(
      margin: const EdgeInsets.only(left: 38),
      height: 24,
      child: VerticalDivider(
        color: Colors.grey.shade300,
        thickness: 2,
        width: 2,
      ),
    );
  }

  Widget _buildFeeRow(String label, String value, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: isHighlight ? Colors.blue.shade700 : Colors.grey.shade700,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isHighlight ? Colors.blue.shade700 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZoneRow(Color color, String title, String description) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color.withOpacity(0.5),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// 정리하기 가이드 페이지
class CleanupGuidePage extends StatelessWidget {
  const CleanupGuidePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('정리하기 가이드'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 정리하기란? 섹션
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.shade400, Colors.green.shade600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.electric_scooter,
                      size: 50,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '정리하기란?',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '길거리에 방치된 킥보드를 발견하셨나요?\n직접 반납 구역으로 정리해주시면\n포인트를 드려요!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.white,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.monetization_on,
                            color: Colors.green.shade600,
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '정리 시 포인트 적립!',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              // 이용 방법 타이틀
              const Text(
                '이용 방법',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              // STEP 1
              _buildStepCard(
                stepNumber: 1,
                icon: Icons.search,
                iconColor: Colors.blue,
                title: '킥보드 발견',
                subtitle: '방치된 킥보드를 발견하면',
                description: '정리하기 버튼을 눌러주세요.',
              ),
              // 연결선
              _buildConnector(),
              // STEP 2
              _buildStepCard(
                stepNumber: 2,
                icon: Icons.nfc,
                iconColor: Colors.orange,
                title: 'NFC 인증',
                subtitle: 'NFC 인증 후',
                description: '킥보드를 접어서 손잡이를 잡고 이동합니다.',
              ),
              // 연결선
              _buildConnector(),
              // STEP 3
              _buildStepCard(
                stepNumber: 3,
                icon: Icons.location_on,
                iconColor: Colors.green,
                title: '정리 완료',
                subtitle: '반납 구역에 도착하면',
                description: '정리 완료 시 포인트가 지급됩니다.',
              ),
              const SizedBox(height: 30),
              // 하단 버튼
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    '확인',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepCard({
    required int stepNumber,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 스텝 아이콘
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: iconColor, size: 28),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // 내용
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: iconColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'STEP $stepNumber',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.arrow_forward,
                      size: 16,
                      color: iconColor,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        description,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnector() {
    return Container(
      margin: const EdgeInsets.only(left: 47),
      height: 24,
      child: VerticalDivider(
        color: Colors.grey.shade300,
        thickness: 2,
        width: 2,
      ),
    );
  }
}