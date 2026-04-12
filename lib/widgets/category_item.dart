import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class CategoryItem extends StatelessWidget {
  final String emoji;
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const CategoryItem({
    super.key,
    required this.emoji,
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(right: 20),
        child: Column(
          children:[
            Container(
              width: 55,
              height: 55,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primaryLight : AppColors.background, // 디자인 시스템 적용
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppColors.primary : Colors.transparent, // 디자인 시스템 적용
                  width: 2,
                ),
                boxShadow:[
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)
                ],
              ),
              child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 26)), // 글씨는 변하지 않으니 const 유지
              ),
            ),
            const SizedBox(height: 8), // 여백도 변하지 않으니 const
            Text(
              title, 
              style: TextStyle(
                fontSize: 12, 
                fontWeight: FontWeight.bold,
                color: isSelected ? AppColors.primary : AppColors.textPrimary, // 디자인 시스템 적용
              )
            ),
          ],
        ),
      ),
    );
  }
}