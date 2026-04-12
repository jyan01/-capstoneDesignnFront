import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/restaurant.dart';

// 1. 카테고리
class CategoryNotifier extends Notifier<String> {
  @override
  String build() => '';
  void toggleCategory(String category) => state = state == category ? '' : category;
}
final categoryProvider = NotifierProvider<CategoryNotifier, String>(() => CategoryNotifier());

// 2. 검색어 관리
class SearchQueryNotifier extends Notifier<String> {
  Timer? _timer; // 타이머 시계

  @override
  String build() => ''; // 초기 검색어는 빈칸

  // 타자를 칠 때마다 이 함수가 실행
  void updateQuery(String query) {
    // 1. 타자를 또 치면, 아까 맞춰둔 타이머 취소
    if (_timer?.isActive ?? false) _timer!.cancel();
    
    // 2. 다시 0.5초(500밀리초) 타이머를 맞춤
    // 사용자가 0.5초 동안 타자를 안 치고 가만히 있으면, 그때 비로소 상태를 검색어로 바꿈
    _timer = Timer(const Duration(milliseconds: 500), () {
      state = query;
    });
  }
}

final searchQueryProvider = NotifierProvider<SearchQueryNotifier, String>(() => SearchQueryNotifier());


// 3. 비동기 맛집 데이터
class RestaurantNotifier extends AsyncNotifier<List<Restaurant>> {
  @override
  Future<List<Restaurant>> build() async {
    await Future.delayed(const Duration(seconds: 2)); // 서버 통신 2초 흉내
    
    // 강남역 근처를 기준으로 가짜 좌표를 모두 추가
    return const[
      Restaurant(id: 1, name: 'AI 추천 맛집 1', category: '한식', distance: 0.3, rating: 4.9, latitude: 37.4980, longitude: 127.0280),
      Restaurant(id: 2, name: '초밥의 달인', category: '일식', distance: 0.6, rating: 4.8, latitude: 37.4975, longitude: 127.0271),
      Restaurant(id: 3, name: '불맛 짬뽕집', category: '중식', distance: 0.9, rating: 4.7, latitude: 37.4985, longitude: 127.0265),
      Restaurant(id: 4, name: '파스타 공방', category: '양식', distance: 1.2, rating: 4.6, latitude: 37.4960, longitude: 127.0290),
      Restaurant(id: 5, name: '감성 카페', category: '카페', distance: 1.5, rating: 4.5, latitude: 37.4990, longitude: 127.0250),
      Restaurant(id: 6, name: '할머니 국밥', category: '한식', distance: 1.8, rating: 4.4, latitude: 37.4955, longitude: 127.0285),
      Restaurant(id: 7, name: '수제버거 존', category: '패스트푸드', distance: 2.1, rating: 4.3, latitude: 37.4982, longitude: 127.0300),
      Restaurant(id: 8, name: '이자카야 텐', category: '술집', distance: 2.4, rating: 4.2, latitude: 37.4970, longitude: 127.0260),
      Restaurant(id: 9, name: '스테이크 하우스', category: '양식', distance: 2.7, rating: 4.1, latitude: 37.4995, longitude: 127.0275),
      Restaurant(id: 10, name: '디저트 카페', category: '카페', distance: 3.0, rating: 4.0, latitude: 37.4965, longitude: 127.0295),
    ];
  }

  void toggleFavorite(int id) {
    state.whenData((restaurants) {
      state = AsyncValue.data([
        for (final restaurant in restaurants)
          if (restaurant.id == id) restaurant.copyWith(isFavorite: !restaurant.isFavorite)
          else restaurant
      ]);
    });
  }
}

final restaurantProvider = AsyncNotifierProvider<RestaurantNotifier, List<Restaurant>>(() => RestaurantNotifier());

// 4. 화면에 뿌려주는 최종 필터링(카테고리 + 검색어 + 하트 정렬)
final filteredRestaurantsProvider = Provider<AsyncValue<List<Restaurant>>>((ref) {
  final asyncRestaurants = ref.watch(restaurantProvider);
  final category = ref.watch(categoryProvider);
  final searchQuery = ref.watch(searchQueryProvider); // 검색어 상태를 실시간으로 확인

  return asyncRestaurants.whenData((restaurants) {
    List<Restaurant> filtered = restaurants.where((r) {
      // 필터 1: 카테고리 일치 여부
      if (category.isNotEmpty && r.category != category) return false;
      
      // 필터 2: 검색어 포함 여부 (띄어쓰기 무시, 대소문자 무시)
      if (searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase().replaceAll(' ', '');
        final name = r.name.toLowerCase().replaceAll(' ', '');
        if (!name.contains(query)) return false;
      }
      return true;
    }).toList();

    // 필터 3: 하트 정렬
    filtered.sort((a, b) {
      if (a.isFavorite && !b.isFavorite) return -1;
      if (!a.isFavorite && b.isFavorite) return 1;
      return a.id.compareTo(b.id);
    });

    return filtered;
  });
});