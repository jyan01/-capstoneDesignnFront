import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/restaurant.dart';

// 1. 카테고리 관리
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


// 🧠 3. 비동기 맛집 데이터 (위도/경도 좌표 + 🌟메뉴 데이터 추가!)
class RestaurantNotifier extends AsyncNotifier<List<Restaurant>> {
  @override
  Future<List<Restaurant>> build() async {
    await Future.delayed(const Duration(seconds: 2)); // 서버 통신 2초 흉내
    
    // 🌟 리스트 앞의 'const'를 제거하여 유연한 메뉴 데이터 삽입 가능!
    return [
      Restaurant(
        id: 1, name: 'AI 추천 맛집 1', category: '한식', distance: 0.3, rating: 4.9, latitude: 37.4980, longitude: 127.0280,
        menus: [MenuItem(name: '제육볶음 정식', price: 9000), MenuItem(name: '김치찌개', price: 8000), MenuItem(name: '뚝배기 불고기', price: 9500)],
      ),
      Restaurant(
        id: 2, name: '초밥의 달인', category: '일식', distance: 0.6, rating: 4.8, latitude: 37.4975, longitude: 127.0271,
        menus: [MenuItem(name: '특선 모듬 초밥', price: 18000), MenuItem(name: '연어 초밥 세트', price: 15000), MenuItem(name: '새우 튀김 우동', price: 8500)],
      ),
      Restaurant(
        id: 3, name: '불맛 짬뽕집', category: '중식', distance: 0.9, rating: 4.7, latitude: 37.4985, longitude: 127.0265,
        menus: [MenuItem(name: '차돌 짬뽕', price: 11000), MenuItem(name: '미니 탕수육', price: 14000), MenuItem(name: '옛날 간짜장', price: 8000)],
      ),
      Restaurant(
        id: 4, name: '파스타 공방', category: '양식', distance: 1.2, rating: 4.6, latitude: 37.4960, longitude: 127.0290,
        menus: [MenuItem(name: '베이컨 까르보나라', price: 13000), MenuItem(name: '알리오 올리오', price: 11000), MenuItem(name: '마르게리따 피자', price: 16000)],
      ),
      Restaurant(
        id: 5, name: '감성 카페', category: '카페', distance: 1.5, rating: 4.5, latitude: 37.4990, longitude: 127.0250,
        menus: [MenuItem(name: '아이스 아메리카노', price: 4500), MenuItem(name: '브라운 치즈 크로플', price: 6500), MenuItem(name: '시그니처 아인슈페너', price: 6000)],
      ),
      Restaurant(
        id: 6, name: '할머니 국밥', category: '한식', distance: 1.8, rating: 4.4, latitude: 37.4955, longitude: 127.0285,
        menus: [MenuItem(name: '얼큰 순대국밥', price: 9000), MenuItem(name: '모듬 수육 (중)', price: 25000), MenuItem(name: '맛보기 찰순대', price: 7000)],
      ),
      Restaurant(
        id: 7, name: '수제버거 존', category: '패스트푸드', distance: 2.1, rating: 4.3, latitude: 37.4982, longitude: 127.0300,
        menus: [MenuItem(name: '더블 치즈버거', price: 8500), MenuItem(name: '갈릭 감자튀김', price: 4000), MenuItem(name: '클래식 바닐라 쉐이크', price: 5000)],
      ),
      Restaurant(
        id: 8, name: '이자카야 텐', category: '술집', distance: 2.4, rating: 4.2, latitude: 37.4970, longitude: 127.0260,
        menus: [MenuItem(name: '숯불 꼬치 5종', price: 18000), MenuItem(name: '나가사키 짬뽕탕', price: 22000), MenuItem(name: '명란구이와 오이', price: 13000)],
      ),
      Restaurant(
        id: 9, name: '스테이크 하우스', category: '양식', distance: 2.7, rating: 4.1, latitude: 37.4995, longitude: 127.0275,
        menus: [MenuItem(name: '티본 스테이크 (500g)', price: 65000), MenuItem(name: '리코타 치즈 샐러드', price: 12000), MenuItem(name: '트러플 머쉬룸 파스타', price: 21000)],
      ),
      Restaurant(
        id: 10, name: '디저트 카페', category: '카페', distance: 3.0, rating: 4.0, latitude: 37.4965, longitude: 127.0295,
        menus: [MenuItem(name: '딸기 생크림 케이크', price: 7000), MenuItem(name: '로얄 밀크티', price: 5500), MenuItem(name: '얼그레이 마들렌', price: 3500)],
      ),
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
  final searchQuery = ref.watch(searchQueryProvider); 

  return asyncRestaurants.whenData((restaurants) {
    List<Restaurant> filtered = restaurants.where((r) {
      // 필터 1: 카테고리 일치 여부
      if (category.isNotEmpty && r.category != category) return false;
      
      // 필터 2: 검색어 포함 여부
      if (searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase().replaceAll(' ', '');
        final name = r.name.toLowerCase().replaceAll(' ', '');
        if (!name.contains(query)) return false;
      }
      return true;
    }).toList();

    return filtered;
  });
});

// 5. 찜한 식당만 필터링 (찜 목록 화면용)
final favoriteRestaurantsProvider = Provider<List<Restaurant>>((ref) {
  final asyncRestaurants = ref.watch(filteredRestaurantsProvider);

  return asyncRestaurants.maybeWhen(
    data: (restaurants) {
      return restaurants.where((restaurant) => restaurant.isFavorite).toList();
    },
    orElse: () => [],
  );
});