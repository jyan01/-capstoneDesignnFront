import 'dart:convert';
import 'package:http/http.dart' as http;

class KakaoApiService {
  // ✨ 아까 복사해둔 본인의 'REST API 키'를 여기에 넣으세요! 
  // (따옴표 안에 넣어주시면 됩니다.)
  static const String _restApiKey = 'a5824d8b04066d3653ac41abe4278f68';

  // 랜드마크(키워드)를 검색해서 위도, 경도 좌표를 가져오는 함수
  static Future<Map<String, dynamic>?> searchPlace(String keyword) async {
    print('🔍 "$keyword" 검색 요청 중...');
    
    // 카카오 키워드 검색 API 주소
    final url = Uri.parse('https://dapi.kakao.com/v2/local/search/keyword.json?query=$keyword');

    try {
      final response = await http.get(
        url,
        headers: {'Authorization': 'KakaoAK $_restApiKey'}, // 카카오에게 나라고 증명하기
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // 검색 결과가 1개라도 있다면?
        if (data['documents'].isNotEmpty) {
          // 가장 찰떡같이 매칭된 첫 번째 결과를 가져옵니다.
          final firstResult = data['documents'][0];
          
          final double lat = double.parse(firstResult['y']); // y가 위도(Latitude)
          final double lng = double.parse(firstResult['x']); // x가 경도(Longitude)
          final String placeName = firstResult['place_name'];
          
          print('✅ 검색 성공! 이름: $placeName, 위도: $lat, 경도: $lng');
          
          // 위도, 경도, 그리고 이름까지 세트로 묶어서 반환합니다.
          return {'lat': lat, 'lng': lng, 'name': placeName};
        } else {
          print('❌ "$keyword"에 대한 검색 결과가 없습니다.');
          return null;
        }
      } else {
        print('❌ API 통신 에러: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ 검색 중 에러 발생: $e');
      return null;
    }
  }
}