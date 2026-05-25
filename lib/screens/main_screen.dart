import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/gestures.dart';
import 'package:geolocator/geolocator.dart';
import '../services/location_service.dart';
import '../models/restaurant.dart';
import '../widgets/category_item.dart';
import '../theme/app_colors.dart';
import '../providers/restaurant_provider.dart';
import 'restaurant_detail_screen.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import '../screens/map_screen.dart';
import 'package:matjib_app/services/kakao_api_service.dart';
import 'dart:js' as js;
import 'dart:convert';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

// *변경 코드1* 지도를 부드럽게 움직이려면 with TickerProviderStateMixin 필요
class _MainScreenState extends ConsumerState<MainScreen> with TickerProviderStateMixin { 
  
  String? _detailRestaurantId;
  String? _selectedRestaurantId;
  bool _isDetailOpen = false;
  FocusNode? _searchFocusNode;
  Position? _myPosition; // 내 진짜 위치 저장용
  bool _isLoadingLocation = true; // 로딩 상태
  bool _isKeepMode = false; // ✨ 킵(보관함) 모드 켜짐/꺼짐 상태
  bool _isCategoryExpanded = false; // ✨ [여기 추가!] 카테고리 드롭다운 열림/닫힘 상태 기억
  TextEditingController? _autoCompleteController;
  // *1번 여기까지*
  final TransformationController _mapController = TransformationController();
  static const List<String> _searchKeywords = [
    '강남구 맛집', '강남역 스시', '강남 이자카야', '초밥의 달인', '불맛 짬뽕집', '파스타 공방', '할머니 국밥',
  ];

  // *변경 코드2* 애니메이션 코드 추가, 변수 추가
  // 바텀 시트를 코드로 끌어내리기 위한 컨트롤러
  final DraggableScrollableController _sheetController = DraggableScrollableController();
  
  // 지도를 움직이기 위한 애니메이션 컨트롤러
  late AnimationController _animationController;
  Animation<Matrix4>? _mapAnimation;

  final FocusNode _chatFocusNode = FocusNode();
  final TextEditingController _chatInputController = TextEditingController();
  bool _isChatActive = false; // 채팅창 활성화 여부
  List<String> _chatMessages = []; // 임시 대화 기록
  ScrollController? _listScrollController;

  @override
  void initState() {
    super.initState();
    _initApp(); 

    js.context['onMarkerClicked'] = js.allowInterop((String clickedId) {
      print('🎯 마커 클릭됨! 식당 ID: $clickedId');
      
      // 1. 현재 화면에 떠있는 리스트에서 클릭된 식당의 진짜 데이터(위도/경도)를 찾아옵니다.
      final displayList = _isKeepMode 
          ? (ref.read(filteredRestaurantsProvider).value?.where((r) => r.isFavorite).toList() ?? [])
          : (ref.read(filteredRestaurantsProvider).value ?? []);
          
      final clickedRestaurant = displayList.firstWhere((r) => r.id == clickedId);

      setState(() {
        _detailRestaurantId = clickedId;
        _selectedRestaurantId = clickedId; // 🚀 내부에 선택 상태 각인!
        _isDetailOpen = true; 
      });
      
      // 2. 다른 핀들을 싹 숨기고, 선택된 이 핀만 빨갛고 크게 만듭니다.
      _syncMarkers(); 

      // 3. 지도를 꿀렁임 없이, 딱 한 번만 정가운데로 부드럽게 이동시킵니다!
      js.context.callMethod('moveMap', [clickedRestaurant.latitude, clickedRestaurant.longitude, 3]);

      // 4. 바텀시트를 상세 모드(0.65)로 예쁘게 올려줍니다.
      Future.delayed(const Duration(milliseconds: 50), () {
        if (_sheetController.isAttached) {
          _sheetController.animateTo(
            0.65, 
            duration: const Duration(milliseconds: 400), 
            curve: Curves.easeOutCubic
          );
        }
      });
    });
  }

  // ✨ 로딩 화면 -> 위치 찾기 -> 지도 열기
  void _initApp() async {
    // 1. 내 위치 가져오기 (권한 허용 기다림)
    _myPosition = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high, 
    );
    
    // 2. 위치를 성공적으로 찾았다면?
    if (_myPosition != null) {
      // 지도를 그리기 전에(JS가 실행되기 전에) 초기 위치를 강남역에서 내 위치로 바꿔버립니다!
      js.context.callMethod('setInitialLocation', [_myPosition!.latitude, _myPosition!.longitude]);
    }

    // 3. 로딩 끝! 화면 다시 그리기 (이제 지도가 렌더링됨)
    setState(() {
      _isLoadingLocation = false; 
    });

    // 🚀 [핵심 추가] 지도가 화면에 그려질 시간(약 0.8초)을 잠깐 기다렸다가, 처음 핀을 강제로 꽂아줍니다!
    Future.delayed(const Duration(milliseconds: 800), () {
      // 1. 현재 불러와져 있는 식당 리스트를 슬쩍 가져옵니다.
      final initialRestaurants = ref.read(filteredRestaurantsProvider).value;
      
      // 2. 데이터가 있다면 자바스크립트로 전송!
      if (initialRestaurants != null && initialRestaurants.isNotEmpty) {
        final markerData = initialRestaurants.map((r) => {
          'id': r.id,
          'latitude': r.latitude,
          'longitude': r.longitude,
          'name': r.name,
          'bestGrade': r.bestGrade,
        }).toList();
        
        js.context.callMethod('setRestaurantMarkers', [json.encode(markerData)]);

        if (_myPosition != null) {
          js.context.callMethod('moveMap', [_myPosition!.latitude, _myPosition!.longitude]);
        }
      }
    });

    // 로딩이 끝나면 백그라운드에서 실시간 위치 추적(레이더) 시작!
    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 2, // ✨ 내가 2미터 이상 이동할 때만 갱신 (배터리 절약)
      ),
    ).listen((Position position) {
      // 내 위치가 바뀔 때마다 상태를 업데이트하고, 파란 점만 이동시킵니다!
      // (이때 지도는 안 움직입니다. 사용자가 다른 곳 구경 중일 수 있으니까요!)
      _myPosition = position; 
      js.context.callMethod('updateUserMarker', [position.latitude, position.longitude]);
    });
  }

  // 🚀 [목표 1, 3 해결] 화면 상태(Keep, 상세창, 선택)를 싹 다 파악해서 핀을 그려주는 전담 매니저!
  void _syncMarkers() {
    final restaurants = ref.read(filteredRestaurantsProvider).value ?? [];
    if (restaurants.isEmpty) {
      js.context.callMethod('setRestaurantMarkers', ['[]']);
      return;
    }

    // ① Keep 모드 필터링 (킵 켜지면 하트 누른 식당만 남김)
    List<Restaurant> displayList = _isKeepMode 
        ? restaurants.where((r) => r.isFavorite).toList() 
        : restaurants;

    // ② 상세 화면 필터링 (상세창 열리면 그 식당 1개만 덜렁 남김)
    if (_isDetailOpen && _detailRestaurantId != null) {
      displayList = displayList.where((r) => r.id == _detailRestaurantId).toList();
    }

    // ③ 선택 유무(빨간불) 정보를 포함해서 JS로 전송
    final markerData = displayList.map((r) => {
      'id': r.id,
      'latitude': r.latitude,
      'longitude': r.longitude,
      'name': r.name,
      'bestGrade': r.bestGrade,
      'isSelected': (r.id == _selectedRestaurantId || r.id == _detailRestaurantId), // 👈 이게 JS에서 핀을 키워줍니다!
    }).toList();

    js.context.callMethod('setRestaurantMarkers', [json.encode(markerData)]);
  }

  // ✨ [추가] 나중에 '내 위치로 돌아가기' 버튼을 누르면 실행할 함수!
  void _goToMyLocation() async {
    // 버튼 누를 때마다 최신 위치를 새로 가져와서 거기로 이동합니다.
    Position? freshPos = await LocationService.getCurrentLocation();
    if (freshPos != null) {
      setState(() { _myPosition = freshPos; });
      js.context.callMethod('moveMap', [freshPos.latitude, freshPos.longitude]);
    }
  }
  // *2번 여기까지*

  @override
  void dispose() {
    _mapController.dispose();
    // *변경 코드3* 메모리 해제
    _sheetController.dispose();
    _animationController.dispose();
    _chatFocusNode.dispose();
    _chatInputController.dispose();
    // *3번 여기까지*
    super.dispose();
  }

  // *변경 코드4* 
  void _sendMessage(String text) {
    if (text.trim().isEmpty) return; // 빈 칸이면 무시

    setState(() {
      _chatMessages.add("USER:$text"); // 내 화면에 말풍선 추가
    });
    
    _chatInputController.clear(); // 입력창 비우기
    _chatFocusNode.requestFocus();

    // TODO: 여기에 실제 AI API를 호출하는 코드를 넣기
    // 아래는 AI가 답변을 고민하고 1.5초 뒤에 말하는 척 하는 가짜 코드
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _chatMessages.add("BOT:'$text' 주변의 맛집을 열심히 찾고 있어요! 🍕");
        });
      }
    });
  }

  // ✨ 리스트에서 식당을 클릭했을 때 지도를 움직이는 함수
  void _animateMapToRestaurant(Restaurant restaurant) {
    // 🚀 1. 복잡했던 Matrix4 계산 코드는 전부 삭제!
    // 진짜 카카오맵에게 "이 식당 좌표로 이동하고, 건물 앞까지 가깝게 '줌인(레벨 3)' 해줘!" 라고 명령합니다.
    js.context.callMethod('moveMap', [restaurant.latitude, restaurant.longitude, 3]);

    // 🚀 2. 바텀 시트 조절 기능은 원본 그대로 유지!
    // 맛집 정보와 지도가 한눈에 보기 좋게 바텀시트 높이를 0.45 비율로 스르륵 맞춰줍니다.
    if (_sheetController.isAttached) {
      _sheetController.animateTo(
        0.45, 
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic, // 기존보다 조금 더 부드러운 감속 곡선 적용
      );
    }
  }

  void _animateToMyLocation() {
    print("📍 내 위치로 스르륵 날아갑니다...");

    if (_myPosition != null) {
      // 1. 핀 지우고 지도를 내 위치로 이동!
      js.context.callMethod('clearSearchMarker');
      js.context.callMethod('moveMap', [_myPosition!.latitude, _myPosition!.longitude]);
      
      // ✨ 2. 검색창에 적혀있던 글자를 싹 지워줍니다.
      ref.read(searchQueryProvider.notifier).updateQuery('');
      
      // ✨ 3. 바텀시트가 열려있었다면 닫고, 높이를 0.45로 원상 복구합니다.
      setState(() {
        _isDetailOpen = false;
      });
      if (_sheetController.isAttached) {
        _sheetController.animateTo(
          0.45, 
          duration: const Duration(milliseconds: 400), 
          curve: Curves.easeOutCubic
        );
      }

      // 🚨 4. [나중에 1번(백엔드) 작업할 때 여기에 들어갈 코드]
      // 아직 백엔드가 없어서 데이터가 안 바뀌는 것입니다!
      // 나중에 서버 통신이 연결되면, 이 자리에 아래와 같은 코드가 추가될 예정입니다.
      // 예: ref.read(restaurantProvider.notifier).fetchRestaurants(_myPosition!.latitude, _myPosition!.longitude);
    }
  }
  // *4번 여기까지*

  // ✨ 검색 처리 함수 (식당 vs 랜드마크 자동 분류)
  // ✨ 검색 처리 함수 (빛의 속도로 타이핑해도 엇나가지 않음!)
  void _handleSearch(String keyword) async {
    FocusScope.of(context).unfocus(); 
    if (keyword.trim().isEmpty) return;
    
    setState(() {
      _selectedRestaurantId = null;
      _detailRestaurantId = null;
      _isDetailOpen = false;
    });

    // 🚀 [1번 버그 해결] 필터링이 덜 끝난 '현재 화면 리스트'를 믿지 말고,
    // '전체 원본 리스트'에서 방금 입력한 keyword가 포함된 식당을 직접 0.001초 만에 솎아냅니다!
    final allRestaurants = ref.read(restaurantProvider).value ?? [];
    final matchedRestaurants = allRestaurants.where((r) => r.name.contains(keyword)).toList();

    // 🍔 우리 데이터에 일치하는 식당이 있다? -> '식당 검색 모드'
    if (matchedRestaurants.isNotEmpty) {
      print('🍔 식당 검색으로 인식됨: "$keyword"');
      
      // 🚀 검색어를 리버팟 창고에 강제로 즉시 밀어 넣어서 동기화를 완벽하게 맞춥니다.
      ref.read(searchQueryProvider.notifier).updateQuery(keyword);

      // 내가 찾은 식당 목록 중 첫 번째 식당으로 이동!
      final targetRestaurant = matchedRestaurants.first;
      js.context.callMethod('moveMap', [targetRestaurant.latitude, targetRestaurant.longitude, 3]);
      
      _syncMarkers(); 

      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted && _sheetController.isAttached) {
          _sheetController.animateTo(0.45, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
        }
      });
    } 
    // 📍 일치하는 식당이 하나도 없다? -> '랜드마크 검색 모드'
    else {
      print('📍 랜드마크 검색으로 인식됨: "$keyword"');
      final result = await KakaoApiService.searchPlace(keyword);
      
      if (result != null) {
        js.context.callMethod('moveMap', [result['lat'], result['lng'], 5]);
        
        ref.read(searchQueryProvider.notifier).updateQuery(''); 
        ref.read(categoryProvider.notifier).toggleCategory(''); 
        _autoCompleteController?.clear();

        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted && _sheetController.isAttached) {
            _sheetController.animateTo(0.45, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
          }
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('앗! "$keyword" 위치를 찾을 수 없어요. 😢')),
          );
        }
      }
    }
  }

  // *변경 코드7*
Widget _buildRankingMarker(Restaurant restaurant, double top, double left, Color color, BuildContext context, double currentScale) {
    // 현재 핀이 사용자가 선택한 핀인지 확인
    bool isSelected = _selectedRestaurantId == restaurant.id;

    return Positioned(
      top: top, left: left,
      child: FractionalTranslation(
        translation: const Offset(-0.5, 0),
        child: Transform.scale(
          scale: 1 / currentScale, 
          alignment: Alignment.bottomCenter, 
          child: GestureDetector(
            onTap: () {
              if (isSelected) {
                setState(() {
                  _detailRestaurantId = restaurant.id;
                  _isDetailOpen = true;
                });
                Future.delayed(const Duration(milliseconds: 50), () {
                  if (_sheetController.isAttached) {
                    _sheetController.animateTo(
                      0.65, // 예쁜 황금 비율 높이!
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOutCubic,
                    );
                  }
                });
              } else {
                setState(() {
                  _selectedRestaurantId = restaurant.id;
                  _isDetailOpen = false;
                });
                _animateMapToRestaurant(restaurant);

                // 1. 리스트 전체를 뒤져서 현재 누른 핀의 순서를 찾음
                final restaurantsList = ref.read(filteredRestaurantsProvider).value ?? [];
                final targetIndex = restaurantsList.indexWhere((r) => r.id == restaurant.id);
                
                if (targetIndex != -1) {
                  // 2. 바텀 시트가 올라오는 시간을 기다림
                  Future.delayed(const Duration(milliseconds: 450), () {
                    if (_listScrollController != null && _listScrollController!.hasClients) {
                      _listScrollController!.animateTo(
                        targetIndex * 82.0, 
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOutCubic,
                      );
                    }
                  });
                }
              }
            },
            child: Column(
              children:[
                // 핀 이름표 UI: 선택된 핀은 파란색 배경으로, 선택 안 된 핀은 하얀색 배경
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : Colors.white, 
                    borderRadius: BorderRadius.circular(8), 
                    boxShadow:[BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4)]
                  ),
                  child: Text(
                    restaurant.name, 
                    style: TextStyle(
                      fontSize: isSelected ? 12 : 10, // 선택되면 글씨도 살짝 커짐
                      fontWeight: FontWeight.bold, 
                      color: isSelected ? Colors.white : AppColors.textPrimary
                    )
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: AppColors.background, width: 2), boxShadow:[BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 5)]),
                  child: const Icon(Icons.workspace_premium, color: AppColors.background, size: 20),
                ),
                Container(width: 3, height: 12, decoration: BoxDecoration(color: color, boxShadow:[BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 2)])),
              ],
            ), 
          ), 
        ), 
      ), 
    ); 
  }
   // *여기까지 7번*

  @override
  Widget build(BuildContext context) {
    
    ref.listen(filteredRestaurantsProvider, (previous, next) {
      _syncMarkers();
    });

    final selectedCategory = ref.watch(categoryProvider);
    final asyncDisplayedRestaurants = ref.watch(filteredRestaurantsProvider);
// *변경 코드6*
    Widget buildSheetHeader(int count) {
      final categoryNames = [
        '한식', '중식', '일식', '양식', '분식', '패스트푸드', '아시안', '멕시칸', '카페',
        '고깃집', '돼지갈비', '소고기', '한우', '보쌈', '닭갈비',
        '초밥', '돈카츠', '사케동', '일본가정식', '일식당', '해산물',
        '짬뽕', '칼국수', '막국수', '소바', '메밀칼국수', '면요리', '만두', '군만두',
        '설렁탕', '순두부', '알탕', '곤이', '옹심이', '국물요리',
        '밥집', '한정식', '보리밥정식', '나물',
        '빵', '브런치', '이탈리안', '태국음식', '베트남음식', '뷔페',
        '술집'
      ];

      final categoryWidgets = categoryNames.map((name) {
        return CategoryItem(
          title: name,
          isSelected: selectedCategory == name,
          onTap: () => ref.read(categoryProvider.notifier).toggleCategory(name)
        );
      }).toList();

      return GestureDetector(
        onVerticalDragUpdate: (details) {
          final screenHeight = MediaQuery.of(context).size.height;
          double newSize = _sheetController.size - (details.primaryDelta! / screenHeight);
          _sheetController.jumpTo(newSize.clamp(0.22, 0.87));

          // ✨ 안전장치 1: 바텀시트를 밑으로 끌어내리면 열려있던 카테고리를 즉시 닫아서 터짐 방지!
          if (details.primaryDelta! > 0 && _isCategoryExpanded) {
            setState(() { _isCategoryExpanded = false; });
          }
        },
        onVerticalDragEnd: (details) {
          final currentSize = _sheetController.size;
          final velocity = details.primaryVelocity ?? 0;

          if (velocity < -100) {
            _sheetController.animateTo(0.87, duration: const Duration(milliseconds: 250), curve: Curves.easeOutQuart);
          } else if (velocity > 100) {
            // ✨ 안전장치 2: 휙! 하고 아래로 스와이프해서 닫을 때도 카테고리 창 자동 닫기
            if (_isCategoryExpanded) {
              setState(() { _isCategoryExpanded = false; });
            }
            _sheetController.animateTo(0.22, duration: const Duration(milliseconds: 250), curve: Curves.easeOutQuart);
          } else {
            const snapSizes = [0.22, 0.45, 0.87]; 
            double closest = snapSizes.reduce((a, b) => (a - currentSize).abs() < (b - currentSize).abs() ? a : b);
            
            // ✨ 안전장치 3: 어중간한 높이(0.45)나 아래(0.22)에 멈춰설 때도 자동 닫기
            if (closest != 0.87 && _isCategoryExpanded) {
              setState(() { _isCategoryExpanded = false; });
            }
            _sheetController.animateTo(closest, duration: const Duration(milliseconds: 250), curve: Curves.easeOutQuart);
          }
        },
        child: Container(
          color: Colors.transparent, 
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children:[
              Center(child: Container(margin: const EdgeInsets.only(top: 15, bottom: 15), width: 40, height: 5, decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(10)))),
              
              // 📍 1. 타이틀 & 드롭다운 버튼 영역
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20), 
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children:[
                    Text(
                      _isKeepMode 
                          ? 'keep list 💖' 
                          : (selectedCategory.isEmpty ? '근처 추천 맛집' : '✨ 추천 $selectedCategory 맛집'), 
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)
                    ),
                    
                    Row(
                      children: [
                        Text('총 $count곳', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary.withOpacity(0.7))),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _isCategoryExpanded = !_isCategoryExpanded;
                            });
                            // 열릴 때는 무조건 넓은 0.87 높이로 강제 확장!
                            if (_isCategoryExpanded && _sheetController.isAttached) {
                              _sheetController.animateTo(0.87, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
                            }
                          },
                          child: AnimatedRotation(
                            turns: _isCategoryExpanded ? 0.5 : 0.0, 
                            duration: const Duration(milliseconds: 300),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
                              child: const Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary, size: 20),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 15),

              // 📍 2. 카테고리 리스트 영역
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 300),
                firstCurve: Curves.easeOutCubic,
                secondCurve: Curves.easeOutCubic,
                sizeCurve: Curves.easeOutCubic,
                crossFadeState: _isCategoryExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                
                firstChild: Container(
                  padding: const EdgeInsets.only(bottom: 15),
                  width: double.infinity,
                  child: ScrollConfiguration(
                    behavior: ScrollConfiguration.of(context).copyWith(
                      dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse},
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(children: categoryWidgets),
                    ),
                  ),
                ),
                
                secondChild: Container(
                  // ✨ 안전장치 4: 고정 높이 250px를 버리고 화면 높이에 맞춰 쪼그라들게 만듦! (100px 밑으로는 안 떨어짐)
                  constraints: BoxConstraints(
                    maxHeight: (MediaQuery.of(context).size.height * 0.3).clamp(100.0, 180.0)
                  ),
                  padding: const EdgeInsets.only(left: 20, right: 20, bottom: 15),
                  width: double.infinity,
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: categoryWidgets,
                    ),
                  ),
                ),
              ),
              
              Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
            ],
          ),
        ),
      );
    }
    // *여기까지 6번*

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: _isLoadingLocation
        // 1. 위치 찾는 중일 때: 빙글빙글 로딩창 표시
        ? const Center(child: CircularProgressIndicator()) 
          
          // 2. 위치 다 찾았을 때: 기존에 만든 지도와 UI 표시
        : SafeArea(
          child: Stack(
            children:[
              // 1층: 카카오 지도 배경
              Positioned.fill(
                child: AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  // 상세 페이지 열릴 때 지도를 위로 밀어올리는 효과
                  top: _isDetailOpen ? -150 : 0,
                  bottom: _isDetailOpen ? 150 : 0,
                  left: 0,
                  right: 0,
                  child: const MapScreen(), // 👈 HtmlElementView 대신 이미 만들어둔 MapScreen 하나만 씁니다!
                ),
              ),
              // *여기까지 8번*

              // *변경 코드10*
              // 1.5층: 내 위치 버튼
              Positioned(
                bottom: 150, right: 20,
                child: FloatingActionButton(
                  backgroundColor: AppColors.background, mini: true, elevation: 4,
                  onPressed: _animateToMyLocation, 
                  child: const Icon(Icons.my_location, color: AppColors.primary),
                ),
              ),

              
              // *변경 코드11* 4층 5층 코드 3층 앞으로 이동
              // 4층: 검색창 (최종: 부드럽게 원형으로 변신하는 Morphing 애니메이션)
              Positioned(
                top: 20, 
                left: 20, // 왼쪽 고정!
                
                // 🌟 1단계: 모양과 크기 변화를 담당하는 AnimatedContainer
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300), // 변신 속도
                  curve: Curves.easeInOutCubic, // 부드러운 움직임
                  
                  // ✨ 상세 열림 여부에 따라 크기와 너비를 동적으로 변경
                  width: _isDetailOpen ? 50 : MediaQuery.of(context).size.width - 110,
                  height: 50,
                  
                  decoration: BoxDecoration(
                    color: AppColors.background, // (또는 Colors.white)
                    // ✨ 핵심: 좁아지면서 완벽한 원형(25)으로 맞춰짐
                    borderRadius: BorderRadius.circular(25), 
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
                  ),
                  
                  // 🌟 2단계: 안쪽 글자가 튀어나가는 걸 방지하는 ClipRRect
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(25),
                    child: SingleChildScrollView( // 긴 검색창 내용물이 잘릴 때 오류 방지
                      scrollDirection: Axis.horizontal,
                      physics: const NeverScrollableScrollPhysics(), // 드래그 금지
                      
                      // 🌟 3단계: 내용물 전환을 담당하는 AnimatedSwitcher
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200), // 내용물 전환 속도
                        switchInCurve: Curves.easeIn,
                        switchOutCurve: Curves.easeOut,
                        
                        child: _isDetailOpen 
                            ? SizedBox(
                                key: const ValueKey('search_btn_morph'),
                                width: 50, height: 50,
                                // 🌟 상태 1: 상세 열림 - 동그란 돋보기 아이콘 버튼
                                child: IconButton(
                                  icon: const Icon(Icons.search, color: Colors.black87, size: 24,),
                                  onPressed: () {
                                    // 돋보기 누르면 다시 검색창이 길어짐
                                    setState(() { _isDetailOpen = false; });
                                    Future.delayed(const Duration(milliseconds: 50), () {
                                      if (_sheetController.isAttached) {
                                        _sheetController.animateTo(
                                          0.45, // 뒤로가기와 똑같이 0.45로 복귀!
                                          duration: const Duration(milliseconds: 400),
                                          curve: Curves.easeOutCubic,
                                        );
                                      }
                                    });
                                    // ✨ 3. [추가] 검색창이 길어질 시간(0.3초)을 기다렸다가 키보드 강제 소환!
                                    Future.delayed(const Duration(milliseconds: 300), () {
                                      _searchFocusNode?.requestFocus();
                                    });
                                  },
                                ),
                              )
                            : SizedBox(
                                key: const ValueKey('search_bar_morph'),
                                // ✨ 긴 검색창의 너비를 고정시켜서 에러 원천 차단
                                width: MediaQuery.of(context).size.width - 110,
                                height: 50,
                                // 🌟 상태 2: 평소 화면 - 긴 Autocomplete 검색창
                                child: Autocomplete<String>(
                                  // 🚀 [핵심 1] 화면이 다시 그려질 때(상세화면을 열었다 닫을 때 등), 리버팟에 저장된 검색어를 텍스트창에 짠! 하고 채워줍니다.
                                  initialValue: TextEditingValue(text: ref.read(searchQueryProvider)),

                                  // 1. 검색어 필터링 로직
                                  optionsBuilder: (TextEditingValue textEditingValue) {
                                    if (textEditingValue.text.isEmpty) {
                                      return const Iterable<String>.empty();
                                    }
                                    return _searchKeywords.where((String keyword) {
                                      return keyword.contains(textEditingValue.text);
                                    });
                                  },
                                  
                                  // 2. 연관 검색어를 클릭했을 때의 동작
                                  onSelected: (String selection) {
                                    _handleSearch(selection);
                                  },
                                  
                                  // 3. 기존 검색창 UI 유지 + 지우기(X) 버튼 추가
                                  fieldViewBuilder: (BuildContext context, TextEditingController textEditingController, FocusNode focusNode, VoidCallback onFieldSubmitted) {
                                    _searchFocusNode = focusNode;
                                    _autoCompleteController = textEditingController;
                                    
                                    return Container(
                                      height: 50, 
                                      decoration: BoxDecoration(
                                        color: AppColors.background, 
                                        borderRadius: BorderRadius.circular(25), 
                                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)]
                                      ),
                                      child: Row(
                                        children: [
                                          const SizedBox(width: 15), 
                                          const Icon(Icons.search, color: AppColors.textSecondary), 
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: TextField(
                                              controller: textEditingController, 
                                              focusNode: focusNode,
                                              textAlignVertical: TextAlignVertical.center,

                                              onTap: () {
                                                // 상세 화면이 열려있거나 핀이 선택된 상태라면?
                                                if (_isDetailOpen || _selectedRestaurantId != null) {
                                                  setState(() {
                                                    _isDetailOpen = false; // 상세 화면 닫기
                                                    _detailRestaurantId = null; // 핀 선택 취소
                                                    _selectedRestaurantId = null; 
                                                  });
                                                  
                                                  _syncMarkers(); // 핀 색상과 크기를 원래대로 싹 되돌림!

                                                  // 바텀시트도 다시 리스트 보기 편한 기본 높이(0.45)로 스르륵 내려줍니다.
                                                  if (_sheetController.isAttached) {
                                                    _sheetController.animateTo(
                                                      0.45, 
                                                      duration: const Duration(milliseconds: 300), 
                                                      curve: Curves.easeOutCubic
                                                    );
                                                  }
                                                }
                                              },
                                              
                                              onChanged: (value) {
                                                ref.read(searchQueryProvider.notifier).updateQuery(value);
                                              },
                                              onSubmitted: (value) {
                                                _handleSearch(value);
                                              },
                                              // 🚀 [핵심 2] const를 빼고 suffixIcon을 추가합니다!
                                              decoration: InputDecoration(
                                                isDense: true,
                                                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                                                hintText: '음식점, 주소 검색', 
                                                hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14), 
                                                border: InputBorder.none,
                                                // 검색창에 글자가 한 글자라도 있으면 우측에 'X' 버튼을 띄워줍니다.
                                                suffixIcon: textEditingController.text.isNotEmpty
                                                    ? IconButton(
                                                        icon: const Icon(Icons.cancel, color: Colors.grey, size: 20),
                                                        onPressed: () {
                                                          // X 버튼을 누르면 텍스트를 비우고, 필터를 초기화하며, 지도 핀도 싹 새로고침합니다!
                                                          textEditingController.clear();
                                                          ref.read(searchQueryProvider.notifier).updateQuery('');
                                                          ref.read(categoryProvider.notifier).toggleCategory('');
                                                          _syncMarkers();
                                                        },
                                                      )
                                                    : null,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                  
                                  // 4. 연관 검색어 드롭다운 창 UI 디자인
                                  optionsViewBuilder: (BuildContext context, AutocompleteOnSelected<String> onSelected, Iterable<String> options) {
                                    return Align(
                                      alignment: Alignment.topLeft,
                                      // 🚀 [2번 버그 해결] 허공이나 테두리를 터치해도 신호가 아래층 지도로 새어나가지 않게 완벽 차단!
                                      child: GestureDetector(
                                        behavior: HitTestBehavior.opaque, // 빈 공간도 터치를 인식하게 만듦
                                        onTap: () {}, // 아무 일도 안 하는 빈 함수로 터치를 꿀꺽 삼킵니다.
                                        child: Material(
                                          color: Colors.transparent,
                                          child: Container(
                                            margin: const EdgeInsets.only(top: 8), 
                                            decoration: BoxDecoration(
                                              color: AppColors.background,
                                              borderRadius: BorderRadius.circular(20),
                                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
                                            ),
                                            constraints: BoxConstraints(maxHeight: 200, maxWidth: MediaQuery.of(context).size.width - 110),
                                            child: ListView.builder(
                                              padding: const EdgeInsets.symmetric(vertical: 8),
                                              shrinkWrap: true,
                                              itemCount: options.length,
                                              itemBuilder: (BuildContext context, int index) {
                                                final String option = options.elementAt(index);
                                                return InkWell(
                                                  onTap: () => onSelected(option),
                                                  borderRadius: BorderRadius.circular(10),
                                                  child: Padding(
                                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                                    child: Row(
                                                      children: [
                                                        const Icon(Icons.search, size: 16, color: AppColors.textSecondary),
                                                        const SizedBox(width: 10),
                                                        Text(option, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                                                      ],
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                // 👆 여기까지 개발자님의 기존 Autocomplete<String>( ... ) 코드입니다!
                              ),
                      ),
                    ),
                  ),
                ),
              ),
              

              // 5층: 찜 목록 버튼 코드 (바텀시트 연동형으로 진화 🚀)
              Positioned(
                top: 20, 
                right: 20,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      // ✨ 1. [핵심] 버튼을 누를 때마다 킵 모드를 껐다 켭니다!
                      _isKeepMode = !_isKeepMode; 
                      
                      // 킵 모드가 켜질 때는 상세화면이 열려있었다면 닫아줍니다.
                      if (_isKeepMode) {
                        _isDetailOpen = false; 
                      }
                    });
                    _syncMarkers();
                  },
                  child: AnimatedContainer( // ✨ 색상 변화를 부드럽게 주기 위해 AnimatedContainer로 업그레이드!
                    duration: const Duration(milliseconds: 200),
                    height: 50, width: 60,
                    decoration: BoxDecoration(
                      // ✨ 3. [디테일] 킵 모드가 켜지면 배경색을 빨간색으로, 꺼지면 기본 배경색으로 반전!
                      color: _isKeepMode ? AppColors.error : AppColors.background, 
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 5)],
                      border: Border.all(
                        color: _isKeepMode ? Colors.transparent : AppColors.error.withOpacity(0.3)
                      ), 
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // ✨ 4. [디테일] 킵 모드가 켜지면 아이콘을 흰색으로, 꺼지면 빨간색으로 변경!
                        Icon(
                          Icons.favorite, 
                          color: _isKeepMode ? Colors.white : AppColors.error, 
                          size: 20
                        ),
                        // ✨ 5. [디테일] 텍스트 색상도 동일하게 반전!
                        Text(
                          'keep', 
                          style: TextStyle(
                            color: _isKeepMode ? Colors.white : AppColors.error, 
                            fontSize: 10, 
                            fontWeight: FontWeight.bold
                          )
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              
              // *변경 코드5*
              // 3층: 바텀시트
              DraggableScrollableSheet(
                key: const ValueKey('bottom_sheet_key'), // ✨ 고정 키 부여!
                controller: _sheetController, 
                initialChildSize: 0.45, minChildSize: 0.22, 
                maxChildSize: _isDetailOpen ? 1.0 : 0.87, snap: true, snapSizes: _isDetailOpen ? const [0.22, 0.65, 1.0] : const [0.22, 0.45, 0.87],
                builder: (BuildContext context, ScrollController scrollController) {
                  _listScrollController = scrollController;
                  return PointerInterceptor(
                    child: Container(
                      decoration: BoxDecoration(color: AppColors.background, borderRadius: const BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)), boxShadow:[BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, spreadRadius: 2)]),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
                        
                        // 1층(리스트)과 2층(상세화면)을 겹쳐놓고 슬라이드
                        child: Stack(
                          children: [
                            // 1층: 리스트 화면 (항상 뒤에 깔려있음)
                            Container(
                              child: asyncDisplayedRestaurants.when(
                                loading: () => Column(children:[buildSheetHeader(0), const Expanded(child: Center(child: CircularProgressIndicator(color: AppColors.primary)))]),
                                // ✨ 수정할 코드 (컨트롤러를 달아주고, 진짜 에러 내용을 화면에 출력합니다!)
                                error: (err, stack) => SingleChildScrollView(
                                  controller: scrollController, // 🚀 이게 있어야 에러 화면에서도 바텀시트가 움직입니다!
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  child: Container(
                                    height: 300, // 드래그할 수 있는 충분한 공간 확보
                                    alignment: Alignment.center,
                                    padding: const EdgeInsets.all(20),
                                    child: Text(
                                      '앗! 데이터를 못 불러왔어요.\n\n이유: $err', // 🚀 여기에 진짜 에러 원인이 뜹니다!
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(color: Colors.red),
                                    ),
                                  ),
                                ),
                                data: (restaurants) {
                                  // ✨ 1. Keep 모드가 켜져있으면 하트(isFavorite) 누른 것만 추려냅니다.
                                  final displayList = _isKeepMode 
                                      ? restaurants.where((r) => r.isFavorite).toList() 
                                      : restaurants;

                                  return Column(
                                    children:[
                                      // 상단 헤더 개수 표시
                                      buildSheetHeader(displayList.length),
                                      
                                      Expanded(
                                        child: displayList.isEmpty
                                            ? SingleChildScrollView(
                                                controller: !_isDetailOpen ? scrollController : null,
                                                physics: const AlwaysScrollableScrollPhysics(), 
                                                child: Container(
                                                  height: 300, 
                                                  alignment: Alignment.center,
                                                  child: Text(
                                                    _isKeepMode 
                                                      ? '보관한 맛집이 없습니다 텅~ 💔\n마음에 드는 식당에 하트를 눌러보세요!'
                                                      : '검색 결과가 없습니다 텅~ 🍃\n다른 키워드로 검색해보세요!', 
                                                    textAlign: TextAlign.center, 
                                                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 16, height: 1.5)
                                                  ),
                                                ),
                                              )
                                            : ListView.builder(
                                                controller: !_isDetailOpen ? scrollController : null,
                                                key: const PageStorageKey('restaurant_list'), 
                                                padding: const EdgeInsets.only(bottom: 100),
                                                itemExtent: 85.0,
                                                itemCount: displayList.length, 
                                                itemBuilder: (context, index) {
                                                  Restaurant restaurant = displayList[index];
                                                  bool isSelected = _selectedRestaurantId == restaurant.id;

                                                  return Container(
                                                    margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                    decoration: BoxDecoration(color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.transparent, borderRadius: BorderRadius.circular(15), border: Border.all(color: isSelected ? AppColors.primary.withOpacity(0.5) : Colors.transparent, width: 1.5)),
                                                    child: ListTile(
                                                      onTap: () {
                                                        if (isSelected) {
                                                          // 🏢 1. 이미 선택된 카드를 '한 번 더' 눌러 상세화면(0.65)으로 갈 때
                                                          setState(() {
                                                            _detailRestaurantId = restaurant.id;
                                                            _isDetailOpen = true; 
                                                          });
                                                          _syncMarkers();

                                                          js.context.callMethod('moveMap', [restaurant.latitude, restaurant.longitude, 3]);

                                                          Future.delayed(const Duration(milliseconds: 50), () {
                                                            if (_sheetController.isAttached) { 
                                                              _sheetController.animateTo(
                                                                0.65, 
                                                                duration: const Duration(milliseconds: 400), 
                                                                curve: Curves.easeOutCubic
                                                              );
                                                            }
                                                          });
                                                        } else {
                                                          // 🏢 2. 카드를 '처음' 탭했을 때 (선택 + 지도 이동 + 시트 0.45 정렬)
                                                          setState(() => _selectedRestaurantId = restaurant.id);
                                                          
                                                          _syncMarkers();
                                                          
                                                          // 🚀 _animateMapToRestaurant 대신 직접 호출! (중복 제거)
                                                          js.context.callMethod('moveMap', [restaurant.latitude, restaurant.longitude, 3]);

                                                          if (_sheetController.isAttached) {
                                                            _sheetController.animateTo(
                                                              0.45, 
                                                              duration: const Duration(milliseconds: 300), 
                                                              curve: Curves.easeOutCubic,
                                                            );
                                                          }
                                                          
                                                          // 📜 [2번 버그 해결] 원본 프로바이더 대신, 현재 화면에 띄워진 'displayList'를 기준으로 인덱스를 찾습니다!
                                                          // 이렇게 해야 일반 모드든 킵 모드든 내 눈에 보이는 순서대로 정확히 스크롤됩니다.
                                                          final targetIndex = displayList.indexWhere((r) => r.id == restaurant.id);
                                                          
                                                          if (targetIndex != -1) {
                                                            Future.delayed(const Duration(milliseconds: 300), () {
                                                              if (scrollController.hasClients) {
                                                                scrollController.animateTo(
                                                                  targetIndex * 85.0, 
                                                                  duration: const Duration(milliseconds: 400), 
                                                                  curve: Curves.easeOutCubic
                                                                );
                                                              }
                                                            });
                                                          }
                                                        }
                                                      },
                                                      title: Text(restaurant.name, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                                                      subtitle: Text('⭐ ${restaurant.rating}', style: const TextStyle(color: AppColors.textSecondary)), 
                                                      trailing: IconButton(
                                                        icon: Icon(restaurant.isFavorite ? Icons.favorite : Icons.favorite_border, color: restaurant.isFavorite ? AppColors.error : AppColors.divider), 
                                                        onPressed: () => ref.read(restaurantProvider.notifier).toggleFavorite(restaurant.id)
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                      ),
                                    ],
                                  );
                                }
                              ),
                            ),
                            
                            // 2층: 상세 화면 (슬라이드 애니메이션 적용)
                            AnimatedPositioned(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOutCubic, 
                              top: 0, bottom: 0,
                              // 슬라이드 로직: 열려있으면 제자리, 닫혀있으면 화면 오른쪽 끝으로 밀어서 숨김
                              left: _isDetailOpen ? 0 : MediaQuery.of(context).size.width,
                              right: _isDetailOpen ? 0 : -MediaQuery.of(context).size.width,
                              child: Container(
                                color: AppColors.background,
                                child: _detailRestaurantId != null
                                    ? RestaurantDetailScreen(
                                        key: ValueKey(_detailRestaurantId),
                                        restaurantId: _detailRestaurantId!,
                                        scrollController: _isDetailOpen ? scrollController : null, 
                                        onBack: () {
                                          setState(() {
                                            _isDetailOpen = false; 
                                            _detailRestaurantId = null;
                                            _selectedRestaurantId = null;
                                          });
                                          _syncMarkers();
                                          // 자석 배열이 평소 상태로 돌아올 때까지 0.05초 기다렸다가 0.45로 스윽 내립니다.
                                          Future.delayed(const Duration(milliseconds: 50), () {
                                            if (_sheetController.isAttached) {
                                              _sheetController.animateTo(
                                                0.45, 
                                                duration: const Duration(milliseconds: 400), 
                                                curve: Curves.easeOutCubic
                                              );
                                            }
                                          });
                                        },
                                      )
                                    : const SizedBox(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              // *5번 여기까지*
              
              // *변경 코드9*
            // 5.5층: 아담한 플로팅 AI 채팅 위젯 (키보드 대응 완료 🚀)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                top: _isChatActive ? 0 : MediaQuery.of(context).size.height,
                bottom: _isChatActive ? 0 : -MediaQuery.of(context).size.height,
                left: 0,
                right: 0,
                child: PointerInterceptor(
                  child: GestureDetector(
                    onTap: () {
                      FocusManager.instance.primaryFocus?.unfocus();
                      setState(() => _isChatActive = false);
                    },
                    child: AnimatedContainer( // ✨ Container를 AnimatedContainer로 변경!
                      duration: const Duration(milliseconds: 250), // 키보드 올라오는 속도와 맞춤
                      curve: Curves.easeOut,
                      color: Colors.transparent,
                      // ✨ 2. [핵심] 키보드가 올라온 높이(viewInsets.bottom)만큼만 아래 여백을 줘서 채팅창을 위로 밀어 올림!
                      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                      alignment: const Alignment(0, -0.25), 
                      child: GestureDetector(
                        onTap: () {}, 
                        child: Container(
                          constraints: const BoxConstraints(
                            maxWidth: 420, 
                            maxHeight: 550, 
                          ),
                          width: MediaQuery.of(context).size.width * 0.92, 
                          height: MediaQuery.of(context).size.height * 0.55, 
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 15, spreadRadius: 3)
                            ],
                          ),
                          child: Column(
                            children: [
                              // 1. 헤더 
                              Container(
                                height: 50,
                                padding: const EdgeInsets.symmetric(horizontal: 15),
                                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('AI 맛잘알 챗봇 🤖', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                                    IconButton(
                                      icon: const Icon(Icons.close, color: AppColors.textPrimary, size: 22),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(), 
                                      onPressed: () {
                                        FocusManager.instance.primaryFocus?.unfocus();
                                        setState(() => _isChatActive = false);
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              
                              // 2. 메시지 리스트
                              Expanded(
                                child: ListView.builder(
                                  reverse: true, 
                                  padding: const EdgeInsets.all(16),
                                  itemCount: _chatMessages.length,
                                  itemBuilder: (context, index) {
                                    String msg = _chatMessages[_chatMessages.length - 1 - index];
                                    bool isMe = msg.startsWith("USER:");
                                    return Align(
                                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                                      child: Container(
                                        margin: const EdgeInsets.only(bottom: 12),
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        decoration: BoxDecoration(
                                          color: isMe ? AppColors.primary : Colors.grey.shade200,
                                          borderRadius: BorderRadius.circular(15).copyWith(
                                            bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(15),
                                            bottomLeft: !isMe ? const Radius.circular(0) : const Radius.circular(15),
                                          ),
                                        ),
                                        child: Text(msg.replaceAll("USER:", "").replaceAll("BOT:", ""), style: TextStyle(color: isMe ? Colors.white : AppColors.textPrimary, fontSize: 14)),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              
                              // 3. 채팅 입력창 
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade200))),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        height: 45, 
                                        padding: const EdgeInsets.symmetric(horizontal: 14),
                                        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(20)),
                                        child: TextField(
                                          controller: _chatInputController,
                                          focusNode: _chatFocusNode,
                                          style: const TextStyle(fontSize: 14),
                                          onSubmitted: (text) => _sendMessage(text),
                                          decoration: const InputDecoration(
                                            isDense: true,
                                            contentPadding: EdgeInsets.symmetric(vertical: 12),
                                            hintText: '맛집을 물어보세요!', 
                                            hintStyle: TextStyle(fontSize: 14), 
                                            border: InputBorder.none
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: () => _sendMessage(_chatInputController.text),
                                      child: Container(padding: const EdgeInsets.all(10), decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle), child: const Icon(Icons.send, color: Colors.white, size: 18)),
                                    )
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // 6층: 우측 하단 동그란 챗봇 열기 버튼
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                bottom: _isChatActive ? -100 : 40, 
                right: 20,
                child: PointerInterceptor(
                  child: FloatingActionButton(
                    onPressed: () {
                      setState(() { _isChatActive = true; });
                      Future.delayed(const Duration(milliseconds: 400), () => _chatFocusNode.requestFocus());
                    },
                    backgroundColor: AppColors.primary,
                    elevation: 5,
                    child: const Icon(Icons.chat_bubble_outline, color: Colors.white),
                  ),
                ),
              ),
              // *9번 여기까지*
            ], // Stack children 닫기
          ), // Stack 닫기
        ), // SafeArea 닫기
    ); // Scaffold 닫기
  } // build 메서드 닫기
} // _MainScreenState 클래스 닫기