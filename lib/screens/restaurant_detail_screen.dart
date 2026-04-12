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
      child: Text(text, style: TextStyle(color: Colors.deepOrange[700], fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildAiReviewText(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(text, style: const TextStyle(fontSize: 14, height: 1.4, color: Colors.black87)),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey, size: 20),
          const SizedBox(width: 10),
          Text(text, style: const TextStyle(fontSize: 14, color: Colors.black87)),
        ],
      ),
    );
  }

  // 🌟 팀원분의 변경점: 메뉴 한 줄을 예쁘게 그려주는 위젯
  Widget _buildMenuItem(MenuItem menu) {
    final formattedPrice = menu.price.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');

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
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.deepOrange),
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
      orElse: () => const Restaurant(id: -1, name: '에러', category: '', distance: 0, rating: 0, latitude: 0, longitude: 0)
    );

    if (restaurant == null || restaurant.id == -1) {
      return const Scaffold(body: Center(child: Text('식당 정보를 불러올 수 없습니다.')));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        // ✨ 개발자님의 변경점: 조종기(scrollController) 연결!
        controller: scrollController, 
        slivers: [
          SliverAppBar(
            // ✨ 개발자님의 변경점: 뒤로가기 버튼(onBack) 연결!
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black),
              onPressed: onBack,
            ),
            expandedHeight: 250.0,
            floating: false,
            pinned: true,
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: Colors.orange[100],
                    child: const Icon(Icons.restaurant, size: 80, color: Colors.deepOrange),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Colors.black.withOpacity(0.1), Colors.transparent],
                      ),
                    ),
                  ),
                  // ✨ 개발자님의 변경점: 예쁜 바텀시트 손잡이 유지!
                  Positioned(
                    top: 15, left: 0, right: 0,
                    child: Center(
                      child: Container(
                        width: 40, height: 5,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.2), 
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
                      // 🌟 팀원분의 변경점: 실제 이름과 별점 연동!
                      Text(restaurant.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 24),
                          const SizedBox(width: 4),
                          Text(restaurant.rating.toString(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // 🌟 팀원분의 변경점: 실제 카테고리와 거리 연동!
                  Text('서울 강남구 · ${restaurant.category} · ${restaurant.distance}km', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      _buildTag('#가성비갑'),
                      const SizedBox(width: 8),
                      _buildTag('#데이트추천'),
                      const SizedBox(width: 8),
                      _buildTag('#분위기맛집'),
                    ],
                  ),
                  
                  const SizedBox(height: 30),

                  // 🌟 팀원분의 변경점: 대표 메뉴 리스트 그리기!
                  const Text('📋 대표 메뉴', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  if (restaurant.menus.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.grey.shade300),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))
                        ]
                      ),
                      child: Column(
                        children: restaurant.menus.map((menu) => _buildMenuItem(menu)).toList(),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
                      child: const Center(child: Text('메뉴 정보가 준비되지 않았습니다.', style: TextStyle(color: Colors.black54))),
                    ),

                  const SizedBox(height: 30),
                  
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F4FA),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.auto_awesome, color: Colors.blueAccent),
                            SizedBox(width: 8),
                            Text('AI 리뷰 3줄 요약', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueAccent)),
                          ],
                        ),
                        const SizedBox(height: 15),
                        _buildAiReviewText('✨ "가격 대비 양이 정말 많고 맛있어요!"'),
                        _buildAiReviewText('✨ "인테리어가 깔끔해서 사진 찍기 좋습니다."'),
                        _buildAiReviewText('✨ "저녁 시간에는 웨이팅이 길 수 있으니 예약 추천해요."'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  const Text('매장 정보', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  _buildInfoRow(Icons.location_on, '서울 강남구 테헤란로 123 1층'),
                  _buildInfoRow(Icons.access_time, '매일 11:00 - 22:00 (라스트오더 21:00)'),
                  _buildInfoRow(Icons.phone, '0507-1234-5678'),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}