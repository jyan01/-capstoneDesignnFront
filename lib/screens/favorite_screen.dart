import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/restaurant_provider.dart';
import '../theme/app_colors.dart';
import 'restaurant_detail_screen.dart';

class FavoriteScreen extends ConsumerWidget {
  const FavoriteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ✨ 팀원분이 만드신 '찜한 식당만 필터링하는 Provider'를 구독합니다.
    final favoriteRestaurants = ref.watch(favoriteRestaurantsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          '💖 나의 찜 목록',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        foregroundColor: AppColors.textPrimary,
      ),
      body: favoriteRestaurants.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.favorite_border, size: 80, color: AppColors.divider),
                  const SizedBox(height: 20),
                  const Text(
                    '아직 찜한 식당이 없어요!\n지도에서 하트를 눌러보세요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary, 
                      fontSize: 16, 
                      height: 1.5
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
              itemCount: favoriteRestaurants.length,
              itemBuilder: (context, index) {
                final restaurant = favoriteRestaurants[index];

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                      )
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(10),
                    // ✨ 상세 화면으로 이동
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RestaurantDetailScreen(restaurantId: restaurant.id),
                        ),
                      );
                    },
                    leading: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: AppColors.secondaryLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.restaurant, color: AppColors.secondary),
                    ),
                    title: Text(
                      restaurant.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '강남구 · ${restaurant.distance}km · ⭐ ${restaurant.rating}',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.favorite, color: AppColors.error),
                      onPressed: () {
                        // ✨ 여기서 다시 누르면 찜 해제!
                        ref.read(restaurantProvider.notifier).toggleFavorite(restaurant.id);
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }
}