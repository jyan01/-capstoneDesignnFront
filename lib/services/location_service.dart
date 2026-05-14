import 'package:geolocator/geolocator.dart';

class LocationService {
  // 현재 위치를 가져오는 핵심 함수
  static Future<Position?> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // 1. 기기(브라우저)의 위치 서비스가 켜져 있는지 확인
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print('위치 서비스가 꺼져 있습니다.');
      return null;
    }

    // 2. 위치 권한 상태 확인
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print('위치 권한이 거부되었습니다.');
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      print('위치 권한이 영구적으로 거부되었습니다.');
      return null;
    }

    // 3. 권한이 모두 있다면 현재 위치 반환
    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    
    return position;
  }
}