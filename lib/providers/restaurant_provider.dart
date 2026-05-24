import 'dart:async';
import 'dart:js' as js;
import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/restaurant.dart';

// ─── 1. 카테고리 관리 (기존 기능 100% 유지) ───
class CategoryNotifier extends Notifier<String> {
  @override
  String build() => '';
  void toggleCategory(String category) => state = state == category ? '' : category;
}
final categoryProvider = NotifierProvider<CategoryNotifier, String>(() => CategoryNotifier());


// ─── 2. 검색어 관리 (디바운스 타이머 기능 100% 유지) ───
class SearchQueryNotifier extends Notifier<String> {
  Timer? _timer;

  @override
  String build() => ''; 

  void updateQuery(String query) {
    if (_timer?.isActive ?? false) _timer!.cancel();
    _timer = Timer(const Duration(milliseconds: 500), () {
      state = query;
    });
  }
}
final searchQueryProvider = NotifierProvider<SearchQueryNotifier, String>(() => SearchQueryNotifier());


// ✨ 두 좌표 간 실제 거리(km)를 구하는 하버사인 수학 공식 함수
double _getDistance(double lat1, double lon1, double lat2, double lon2) {
  var p = 0.017453292519943295;
  var c = cos;
  var a = 0.5 - c((lat2 - lat1) * p)/2 + c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p))/2;
  return 12742 * asin(sqrt(a));
}


// ─── 3. 비동기 맛집 데이터 창고 (로컬 에셋 로드 및 거리순 정렬) ───
class RestaurantNotifier extends AsyncNotifier<List<Restaurant>> {
  @override
  Future<List<Restaurant>> build() async {
    
    // 앱 최초 실행 시 기준 위치 (만웅곰탕 근처 좌표) 기준 반경 3km 데이터를 불러옵니다.
    return await _loadAndCalculateDistance(37.33859, 127.92599);
  }

  Future<List<Restaurant>> _loadAndCalculateDistance(double myLat, double myLng) async {
    final String jsonString = await rootBundle.loadString('assets/restaurants.json');
    final List<dynamic> rawData = json.decode(jsonString);

    List<Restaurant> list = [];
    for (var item in rawData) {
      Restaurant res = Restaurant.fromJson(item);
      double distance = _getDistance(myLat, myLng, res.latitude, res.longitude);
      
      // 🚨 [해결 1] 기존에 있던 3km 제한(if문)을 과감히 삭제! 무조건 다 리스트에 담습니다.
      list.add(res.copyWith(distance: distance));
    }

    // 가장 가까운 순서대로 정렬
    list.sort((a, b) => a.distance.compareTo(b.distance));

    // 🗺️ [수정] 지도에 마커를 꽂을 때 '이름'과 백엔드에서 받은 '금은동 등급'도 함께 조각내어 보냅니다!
    final markerData = list.map((r) => {
      'latitude': r.latitude,
      'longitude': r.longitude,
      'name': r.name,
      'bestGrade': r.bestGrade, // ✨ "gold", "silver", "bronze" 등 백엔드 등급 데이터 추가!
    }).toList();
    
    // 자바스크립트로 전송
    js.context.callMethod('setRestaurantMarkers', [json.encode(markerData)]);

    if (list.isNotEmpty) {
      js.context.callMethod('moveMap', [list.first.latitude, list.first.longitude]);
    }

    return list;
  }

  // 🔄 내 위치가 바뀌거나 장소를 검색했을 때 좌표를 받아 새로 고쳐주는 함수
  Future<void> loadRestaurantsAt(double lat, double lng) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _loadAndCalculateDistance(lat, lng));
  }

  // ❤️ 킵(찜) 상태 변경 함수 (ID 타입을 String으로 완벽 매핑!)
  void toggleFavorite(String id) { // 🚨 int에서 String으로 변경
    state.whenData((restaurants) {
      state = AsyncValue.data([
        for (final r in restaurants)
          if (r.id == id) r.copyWith(isFavorite: !r.isFavorite) else r
      ]);
    });
  }
}
final restaurantProvider = AsyncNotifierProvider<RestaurantNotifier, List<Restaurant>>(() => RestaurantNotifier());


// ─── 4. 화면에 뿌려주는 최종 필터링 (카테고리 칩 + 타이핑 검색어 반영) ───
final filteredRestaurantsProvider = Provider<AsyncValue<List<Restaurant>>>((ref) {
  final asyncRestaurants = ref.watch(restaurantProvider);
  final category = ref.watch(categoryProvider);
  final searchQuery = ref.watch(searchQueryProvider); 

  return asyncRestaurants.whenData((restaurants) {
    return restaurants.where((r) {
      // 필터 1: 카테고리 일치 여부 (Getter 변수인 r.category 활용)
      if (category.isNotEmpty && r.category != category) return false;
      
      // 필터 2: 검색어 포함 여부
      if (searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase().replaceAll(' ', '');
        final name = r.name.toLowerCase().replaceAll(' ', '');
        if (!name.contains(query)) return false;
      }
      return true;
    }).toList();
  });
});


// ─── 5. 찜한 식당만 필터링 (바텀시트 내 킵 모드 및 기존 보관함 UI용) ───
final favoriteRestaurantsProvider = Provider<List<Restaurant>>((ref) {
  final asyncRestaurants = ref.watch(filteredRestaurantsProvider);

  return asyncRestaurants.maybeWhen(
    data: (restaurants) {
      return restaurants.where((restaurant) => restaurant.isFavorite).toList();
    },
    orElse: () => [],
  );
});