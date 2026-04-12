// 🌟 1. 데이터의 틀을 잡아주는 클래스 완벽 진화!
class MenuItem {
  final String name;  // 메뉴 이름 (예: 연어 초밥)
  final int price;    // 가격 (예: 15000)
  
  // ✨ [해결 포인트] 여기에 const가 있어야 provider에서 에러가 안 납니다!
  const MenuItem({
    required this.name,
    required this.price,
  });
}
  
class Restaurant {
  final int id;
  final String name;
  final String category;
  final double distance;
  final double rating;
  final double latitude;  // 📍 위도
  final double longitude; // 📍 경도
  final bool isFavorite;
  final List<MenuItem> menus; // 🌟 메뉴 리스트 선언!
  
  const Restaurant({
    required this.id,
    required this.name,
    required this.category,
    required this.distance,
    required this.rating,
    required this.latitude,
    required this.longitude,
    this.isFavorite = false,
    this.menus = const [], // 🌟 기본값은 빈 리스트로 설정
  });
  
  // 하트(찜) 상태 변경을 위한 복사본 생성 함수
  Restaurant copyWith({
    bool? isFavorite, 
    List<MenuItem>? menus, // 🌟 메뉴도 복사할 수 있게 추가
  }) {
    return Restaurant(
      id: id,
      name: name,
      category: category,
      distance: distance,
      rating: rating,
      latitude: latitude,
      longitude: longitude,
      isFavorite: isFavorite ?? this.isFavorite,
      menus: menus ?? this.menus, // 🌟 기존 메뉴 유지 또는 덮어쓰기
    );
  }
  
  // 🚀 나중에 백엔드(API)에서 줄 JSON 데이터를 플러터 언어로 번역해주는 함수!
  factory Restaurant.fromJson(Map<String, dynamic> json) {
    return Restaurant(
      id: json['id'],
      name: json['name'],
      category: json['category'],
      distance: json['distance'].toDouble(),
      rating: json['rating'].toDouble(),
      latitude: json['latitude'].toDouble(),
      longitude: json['longitude'].toDouble(),
      // 🌟 JSON에서 메뉴 데이터도 번역해서 가져오기
      menus: json['menus'] != null 
          ? (json['menus'] as List).map((m) => MenuItem(name: m['name'], price: m['price'])).toList() 
          : const [],
    );
  }
}