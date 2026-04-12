// 1. 데이터의 틀을 잡아주는 클래스
class Restaurant {
  final int id;
  final String name;
  final String category;
  final double distance;
  final double rating;
  final double latitude; 
  final double longitude;
  final bool isFavorite;

  const Restaurant({
    required this.id,
    required this.name,
    required this.category,
    required this.distance,
    required this.rating,
    required this.latitude,
    required this.longitude,
    this.isFavorite = false,
  });

  // 찜 상태 변경을 위한 복사본 생성 함수
  Restaurant copyWith({bool? isFavorite}) {
    return Restaurant(
      id: id,
      name: name,
      category: category,
      distance: distance,
      rating: rating,
      latitude: latitude,
      longitude: longitude,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  // 나중에 백엔드(API)에서 줄 JSON 데이터를 플러터 언어로 번역해주는 함수
  factory Restaurant.fromJson(Map<String, dynamic> json) {
    return Restaurant(
      id: json['id'],
      name: json['name'],
      category: json['category'],
      distance: json['distance'].toDouble(),
      rating: json['rating'].toDouble(),
      latitude: json['latitude'].toDouble(),
      longitude: json['longitude'].toDouble(),
    );
  }
}