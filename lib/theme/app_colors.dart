import 'package:flutter/material.dart';

// 앱에서 쓰는 모든 색상
class AppColors {
  static const Color primary = Colors.blueAccent;       // 메인 브랜드 컬러 (파란색)
  static const Color primaryLight = Color(0xFFE3F2FD);  // 연한 파란색 (챗봇 배경 등)
  
  static const Color secondary = Colors.deepOrange;     // 포인트 컬러 (주황색)
  static const Color secondaryLight = Color(0xFFFFE0B2);// 연한 주황색 (아이콘 배경 등)
  
  static const Color background = Colors.white;         // 앱 기본 하얀 배경
  static const Color mapBackground = Color(0xFFEAF1F8); // 지도 빈 공간 배경 (회색/연푸른색)
  
  static const Color textPrimary = Colors.black87;      // 진한 기본 글씨
  static const Color textSecondary = Colors.grey;       // 연한 힌트 글씨
  
  static const Color divider = Color(0xFFE0E0E0);       // 구분선 색상
  static const Color error = Colors.redAccent;          // 에러/하트 색상
}