import 'package:flutter/material.dart';

class RestaurantDetailScreen extends StatelessWidget {
  final int restaurantId;
  // *변경 코드11*
  final VoidCallback? onBack; 
  final ScrollController? scrollController;

  const RestaurantDetailScreen({
    super.key, 
    required this.restaurantId,
    this.onBack,
    this.scrollController,
  });
  // *여기까지 11번*

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
        children:[
          Icon(icon, color: Colors.grey, size: 20),
          const SizedBox(width: 10),
          Text(text, style: const TextStyle(fontSize: 14, color: Colors.black87)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        // *변경 코드12*
        controller: scrollController, 
        slivers:[
          SliverAppBar(
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
                children:[
                  Container(
                    color: Colors.orange[100],
                    child: const Icon(Icons.restaurant, size: 80, color: Colors.deepOrange),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors:[Colors.black.withOpacity(0.1), Colors.transparent],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 15,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        width: 40,
                        height: 5,
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
          // *여기까지 12번*
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children:[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children:[
                      Text('AI 추천 맛집 $restaurantId', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      const Row(
                        children:[
                          Icon(Icons.star, color: Colors.amber, size: 24),
                          SizedBox(width: 4),
                          Text('4.8', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('서울 강남구 테헤란로 · 한식 · 0.3km', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                  const SizedBox(height: 20),
                  Row(
                    children:[
                      _buildTag('#가성비갑'),
                      const SizedBox(width: 8),
                      _buildTag('#데이트추천'),
                      const SizedBox(width: 8),
                      _buildTag('#분위기맛집'),
                    ],
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
                      children:[
                        const Row(
                          children:[
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