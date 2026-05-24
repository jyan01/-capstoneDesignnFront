// 1. 메뉴 클래스 (가격 타입 String으로 수정 및 description 추가)
class MenuItem {
  final String name;
  final String price; // ✨ int에서 String으로 변경 ("11,000원" 대응)
  final String? description;

  const MenuItem({
    required this.name,
    required this.price,
    this.description,
  });
}

// 2. 영업시간용 서브 클래스들 추가
class WeeklyHour {
  final String date;
  final String hours;
  const WeeklyHour({required this.date, required this.hours});

  factory WeeklyHour.fromJson(Map<String, dynamic> json) {
    return WeeklyHour(
      date: json['date'] ?? '',
      hours: json['hours'] ?? '',
    );
  }
}

class RestaurantHours {
  final List<WeeklyHour> weekly;
  final List<String> lastOrders;
  const RestaurantHours({this.weekly = const [], this.lastOrders = const []});

  factory RestaurantHours.fromJson(Map<String, dynamic> json) {
    return RestaurantHours(
      weekly: json['weekly'] != null
          ? (json['weekly'] as List).map((e) => WeeklyHour.fromJson(e)).toList()
          : const [],
      lastOrders: json['last_orders'] != null ? List<String>.from(json['last_orders']) : const [],
    );
  }
}

// 3. 식당 클래스 본체
class Restaurant {
  final String id; // ✨ int에서 String으로 변경 (rid 매핑)
  final String name;
  final String roadAddress; // ✨ 추가 (도로명)
  final String jibunAddress; // ✨ 추가 (지번)
  final String phone; // ✨ 추가 (전화번호)
  final RestaurantHours? hours; // ✨ 추가 (영업시간 객체)
  final List<MenuItem> menus;
  final String fetchedAt; // ✨ 추가
  final double latitude;
  final double longitude;
  final String locationWkt; // ✨ 추가
  final String bestGrade; // ✨ 추가 ("bronze" 등)
  final List<String> categories; // ✨ String에서 List<String>으로 변경!
  final List<String> mealTypes; // ✨ 추가
  final List<String> recommendationTags; // ✨ 추가

  // 💡 기존 UI가 계속 정상 작동되도록 유지하는 로컬 필드 (JSON에 없으므로 기본값 처리)
  final double distance;
  final double rating;
  final bool isFavorite;

  // 😎 [기존 UI 호환 팁] 기존 코드에서 'restaurant.category'를 단일 글자로 쓰고 있다면
  // 리스트의 첫 번째 항목을 쏙 빼서 넘겨주는 가짜 변수를 만들어 에러를 방지합니다.
  String get category => categories.isNotEmpty ? categories.first : '음식점';

  const Restaurant({
    required this.id,
    required this.name,
    required this.roadAddress,
    required this.jibunAddress,
    required this.phone,
    this.hours,
    required this.menus,
    required this.fetchedAt,
    required this.latitude,
    required this.longitude,
    required this.locationWkt,
    required this.bestGrade,
    required this.categories,
    required this.mealTypes,
    required this.recommendationTags,
    this.distance = 0.0, // json에 없으므로 디폴트값 주입
    this.rating = 4.5,   // json에 없으므로 디폴트값 주입
    this.isFavorite = false,
  });

  Restaurant copyWith({
    bool? isFavorite,
    List<MenuItem>? menus,
    double? distance, // 위치 바뀔 때 거리 갱신용으로 추가하면 좋습니다.
  }) {
    return Restaurant(
      id: id,
      name: name,
      roadAddress: roadAddress,
      jibunAddress: jibunAddress,
      phone: phone,
      hours: hours,
      menus: menus ?? this.menus,
      fetchedAt: fetchedAt,
      latitude: latitude,
      longitude: longitude,
      locationWkt: locationWkt,
      bestGrade: bestGrade,
      categories: categories,
      mealTypes: mealTypes,
      recommendationTags: recommendationTags,
      distance: distance ?? this.distance,
      rating: rating,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  // 🚀 진짜 백엔드 JSON을 한 땀 한 땀 안전하게 번역하는 함수
  factory Restaurant.fromJson(Map<String, dynamic> json) {
    return Restaurant(
      id: json['rid'] ?? '', // ✨ rid 받아오기
      name: json['name'] ?? '',
      roadAddress: json['road_address'] ?? '',
      jibunAddress: json['jibun_address'] ?? '',
      phone: json['phone'] ?? '',
      hours: json['hours'] != null ? RestaurantHours.fromJson(json['hours']) : null,
      menus: json['menus'] != null
          ? (json['menus'] as List).map((m) => MenuItem(
              name: m['name'] ?? '',
              price: m['price'] ?? '0원', // ✨ 가격 문자열 처리
              description: m['description'],
            )).toList()
          : const [],
      fetchedAt: json['fetched_at'] ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0, // ✨ null이나 int 대응 안전장치
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      locationWkt: json['location_wkt'] ?? '',
      bestGrade: json['best_grade'] ?? '',
      categories: json['categories'] != null ? List<String>.from(json['categories']) : const [],
      mealTypes: json['meal_types'] != null ? List<String>.from(json['meal_types']) : const [],
      recommendationTags: json['recommendation_tags'] != null ? List<String>.from(json['recommendation_tags']) : const [],
      distance: 0.0, // JSON에 없으므로 기본값 할당 (나중에 거리 계산 로직으로 채움)
      rating: 4.5,   // JSON에 없으므로 기본값 할당
      isFavorite: false,
    );
  }
}