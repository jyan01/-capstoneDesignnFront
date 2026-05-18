import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/restaurant_provider.dart';
import '../models/restaurant.dart';

// 🌟 팀원분의 변경점: 실제 데이터를 불러오기 위해 ConsumerWidget 사용
class RestaurantDetailScreen extends ConsumerWidget {
  final int restaurantId;
  // ✨ 개발자님의 변경점: 슬라이드 애니메이션을 위한 조종기와 뒤로가기 버튼 유지!
  final VoidCallback? onBack;
  final ScrollController? scrollController;

  const RestaurantDetailScreen({
    super.key,
    required this.restaurantId,
    this.onBack,
    this.scrollController,
  });

  Widget _buildTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.deepOrange[700],
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey, size: 20),
          const SizedBox(width: 10),
          Text(
            text,
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  // 🌟 팀원분의 변경점: 메뉴 한 줄을 예쁘게 그려주는 위젯
  Widget _buildMenuItem(MenuItem menu) {
    final formattedPrice = menu.price.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              menu.name,
              style: const TextStyle(fontSize: 15, color: Colors.black87),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              '..................................................',
              maxLines: 1,
              style: TextStyle(color: Colors.black26, letterSpacing: 2),
              overflow: TextOverflow.clip,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '$formattedPrice원',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.deepOrange,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 🌟 팀원분의 변경점: 실제 식당 데이터 찾기 로직
    final restaurantsAsync = ref.watch(restaurantProvider);
    final restaurant = restaurantsAsync.value?.firstWhere(
      (r) => r.id == restaurantId,
      orElse: () => const Restaurant(
        id: -1,
        name: '에러',
        category: '',
        distance: 0,
        rating: 0,
        latitude: 0,
        longitude: 0,
      ),
    );

    if (restaurant == null || restaurant.id == -1) {
      return const Scaffold(body: Center(child: Text('식당 정보를 불러올 수 없습니다.')));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        // scrollController 연결
        controller: scrollController,
        slivers: [
          SliverAppBar(
            // 뒤로가기 버튼 연결
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black),
              onPressed: () {
                // ✨ [수정] 메인 화면인지, 찜 목록인지 구분해서 뒤로가기 작동!
                if (onBack != null) {
                  // 1. 메인 화면에서 열었을 때 (onBack 함수가 전달됨)
                  onBack!(); // 바텀시트 내리기 등 원래 하던 거 실행!
                } else {
                  // 2. 찜 목록 등 다른 화면에서 열었을 때 (onBack 함수가 없음)
                  Navigator.pop(context); // 진짜 화면을 닫고 이전 화면으로 복귀!
                }
              },
            ),
            expandedHeight: 60.0,
            floating: false,
            pinned: true,
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 0,

            centerTitle: true,
            title: Container(
              margin: const EdgeInsets.only(bottom: 20),
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[300], // 연한 회색
                borderRadius: BorderRadius.circular(10), // 동글동글하게
              ),
            ),
            actions: [
              Consumer(
                // Riverpod 상태를 읽기 위해 Consumer로 감싸줍니다.
                builder: (context, ref, child) {
                  // 1. 전체 식당 목록에서 현재 식당 정보를 찾습니다.
                  // (provider 이름은 개발자님 코드에 맞게 'restaurantProvider' 등을 쓰시면 됩니다)
                  final asyncRestaurants = ref.watch(restaurantProvider);

                  return asyncRestaurants.maybeWhen(
                    data: (restaurants) {
                      // 현재 상세 페이지의 식당 아이디(_detailRestaurantId)로 해당 식당 찾기
                      final restaurant = restaurants.firstWhere(
                        (r) => r.id == restaurantId,
                      );
                      final isFav = restaurant.isFavorite; // 하트 켜짐 여부

                      return Padding(
                        padding: const EdgeInsets.only(top: 20.0, right: 20.0),
                        child: IconButton(
                          icon: Icon(
                            isFav ? Icons.favorite : Icons.favorite_border,
                            color: isFav
                                ? Colors.red
                                : Colors.grey, // 켜지면 빨간색, 꺼지면 회색
                            size: 28,
                          ),
                          onPressed: () {
                            // 2. 하트를 눌렀을 때 토글하는 함수 호출
                            // (notifier에 만들어두신 찜하기 토글 함수 이름을 넣어주세요!)
                            ref
                                .read(restaurantProvider.notifier)
                                .toggleFavorite(restaurant.id);
                          },
                        ),
                      );
                    },
                    orElse: () => const SizedBox(), // 데이터 로딩 중이거나 에러일 땐 빈칸
                  );
                },
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // 실제 이름과 별점 연동
                      Text(
                        restaurant.name,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          // ✨ 수정된 부분: 평점에 따라 금, 은, 동 트로피로 변경
                          Icon(
                            Icons
                                .emoji_events, // 트로피 아이콘 (메달 모양을 원하시면 Icons.military_tech 로 변경 가능)
                            color: restaurant.rating >= 4.5
                                ? const Color(0xFFFFD700)
                                : // 4.5 이상: 금색
                                  restaurant.rating >= 4.0
                                ? const Color(0xFFC0C0C0)
                                : // 4.0 이상: 은색
                                  const Color(0xFFCD7F32), // 그 외: 동색
                            size: 24,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            restaurant.rating.toString(),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // 🌟 팀원분의 변경점: 실제 카테고리와 거리 연동!
                  Text(
                    '서울 강남구 · ${restaurant.category} · ${restaurant.distance}km',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      _buildTag('#가성비갑'),
                      const SizedBox(width: 8),
                      _buildTag('#데이트추천'),
                      const SizedBox(width: 8),
                      _buildTag('#분위기맛집'),
                    ],
                  ), // Row

                  const SizedBox(
                    height: 20,
                  ), // ✅ 1. 두 개 겹쳐있던 여백을 지우고 20 하나로 줄였습니다!

                  const Text(
                    '매장 정보',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 15),
                  _buildInfoRow(Icons.location_on, '서울 강남구 테헤란로 123 1층'),
                  _buildInfoRow(
                    Icons.access_time,
                    '매일 11:00 - 22:00 (라스트오더 21:00)',
                  ),
                  _buildInfoRow(Icons.phone, '0507-1234-5678'),

                  const SizedBox(
                    height: 45,
                  ), // ✅ 2. 전화번호와 대표 메뉴 사이에 시원하게 빈 공간(45)을 새로 추가했습니다!
                  // 🌟 팀원분의 변경점: 대표 메뉴 리스트 그리기!
                  const Text(
                    '📋 대표 메뉴',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 15),
                  if (restaurant.menus.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.grey.shade300),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        // ✨ 수정된 부분: take(3)를 추가해서 딱 3개만 가져옵니다.
                        children: restaurant.menus
                            .take(3)
                            .map((menu) => _buildMenuItem(menu))
                            .toList(),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Text(
                          '메뉴 정보가 준비되지 않았습니다.',
                          style: TextStyle(color: Colors.black54),
                        ),
                      ),
                    ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }
}
