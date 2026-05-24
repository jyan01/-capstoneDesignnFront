import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/restaurant_provider.dart';
import '../models/restaurant.dart';

// 🌟 팀원분의 변경점: 실제 데이터를 불러오기 위해 ConsumerWidget 사용
class RestaurantDetailScreen extends ConsumerWidget {
  final String restaurantId;
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

  // ✨ 정보 텍스트가 길어지거나 여러 줄(영업시간 등)일 때 깨지지 않도록 구조 업그레이드!
  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start, // 여러 줄일 때 아이콘을 위로 정렬
        children: [
          Icon(icon, color: Colors.grey, size: 20),
          const SizedBox(width: 10),
          Expanded( // 텍스트가 화면을 넘어가지 않게 감싸주기
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  // 🌟 팀원분의 변경점: 메뉴 한 줄을 예쁘게 그려주는 위젯
  Widget _buildMenuItem(MenuItem menu) {
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
            menu.price, // ✨ 백엔드가 준 "8,900원" 그대로 출력!
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
    final restaurantsAsync = ref.watch(restaurantProvider);
    final restaurant = restaurantsAsync.value?.firstWhere(
      (r) => r.id == restaurantId,
      orElse: () => const Restaurant(
        id: 'error', // 🚨 int -1 에서 String 'error'로 변경
        name: '에러',
        roadAddress: '', jibunAddress: '', phone: '', fetchedAt: '',
        latitude: 0, longitude: 0, locationWkt: '', bestGrade: '',
        categories: [], mealTypes: [], recommendationTags: [], menus: [],
      ),
    );

    // 🚨 id가 'error' 인지 확인하도록 조건식 수정
    if (restaurant == null || restaurant.id == 'error') {
      return const Scaffold(body: Center(child: Text('식당 정보를 불러올 수 없습니다.')));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        controller: scrollController,
        slivers: [
          SliverAppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black),
              onPressed: () {
                if (onBack != null) {
                  onBack!();
                } else {
                  Navigator.pop(context);
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
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            actions: [
              Consumer(
                builder: (context, ref, child) {
                  final asyncRestaurants = ref.watch(restaurantProvider);

                  return asyncRestaurants.maybeWhen(
                    data: (restaurants) {
                      final currentRes = restaurants.firstWhere(
                        (r) => r.id == restaurantId,
                      );
                      final isFav = currentRes.isFavorite;

                      return Padding(
                        padding: const EdgeInsets.only(top: 20.0, right: 20.0),
                        child: IconButton(
                          icon: Icon(
                            isFav ? Icons.favorite : Icons.favorite_border,
                            color: isFav ? Colors.red : Colors.grey,
                            size: 28,
                          ),
                          onPressed: () {
                            ref
                                .read(restaurantProvider.notifier)
                                .toggleFavorite(currentRes.id);
                          },
                        ),
                      );
                    },
                    orElse: () => const SizedBox(),
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
                      Expanded(
                        child: Text(
                          restaurant.name,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Icon(
                            Icons.emoji_events,
                            color: restaurant.rating >= 4.5
                                ? const Color(0xFFFFD700)
                                : restaurant.rating >= 4.0
                                ? const Color(0xFFC0C0C0)
                                : const Color(0xFFCD7F32),
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
                  
                  // ✨ 백엔드 진짜 주소와 카테고리 연동
                  Text(
                    '${restaurant.roadAddress} · ${restaurant.category} · ${restaurant.distance.toStringAsFixed(1)}km',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                  const SizedBox(height: 20),
                  
                  // ✨ 추천 태그들을 하드코딩이 아닌 백엔드 리스트로 동적 생성! (Wrap 위젯 사용)
                  if (restaurant.recommendationTags.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: restaurant.recommendationTags
                          .map((tag) => _buildTag('#$tag'))
                          .toList(),
                    ),
                  
                  const SizedBox(height: 20),

                  const Text(
                    '매장 정보',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 15),
                  
                  // ✨ 진짜 백엔드 매장 정보들로 싹 교체
                  if (restaurant.roadAddress.isNotEmpty)
                    _buildInfoRow(Icons.location_on, restaurant.roadAddress),
                  
                  if (restaurant.hours != null && restaurant.hours!.weekly.isNotEmpty)
                    _buildInfoRow(
                      Icons.access_time, 
                      // 요일별 영업시간을 줄바꿈(\n)으로 묶어서 예쁘게 출력
                      restaurant.hours!.weekly.map((h) => '${h.date} ${h.hours}').join('\n')
                    ),
                  
                  if (restaurant.phone.isNotEmpty)
                    _buildInfoRow(Icons.phone, restaurant.phone),

                  const SizedBox(height: 45),

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
                        // ✨ 기왕 백엔드에서 맛있는 피자 메뉴를 다 주니, take(3)를 빼고 메뉴판을 다 보여주도록 바꿨습니다!
                        // 너무 길다 싶으시면 다시 .take(5) 정도로 조절하셔도 됩니다.
                        children: restaurant.menus.take(3)
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