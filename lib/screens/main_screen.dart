import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../services/location_service.dart';
import '../models/restaurant.dart';
import '../widgets/category_item.dart';
import '../theme/app_colors.dart';
import '../providers/restaurant_provider.dart';
import 'restaurant_detail_screen.dart';
import 'favorite_screen.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import '../screens/map_screen.dart';
import 'dart:js' as js;

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

// *변경 코드1* 지도를 부드럽게 움직이려면 with TickerProviderStateMixin 필요
class _MainScreenState extends ConsumerState<MainScreen> with TickerProviderStateMixin { 
  
  int? _detailRestaurantId;
  bool _isDetailOpen = false;
  FocusNode? _searchFocusNode;
  Position? _myPosition; // 내 진짜 위치 저장용
  bool _isLoadingLocation = true; // 로딩 상태

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

  int? _selectedRestaurantId;

  final FocusNode _chatFocusNode = FocusNode();
  final TextEditingController _chatInputController = TextEditingController();
  bool _isChatActive = false; // 채팅창 활성화 여부
  List<String> _chatMessages = []; // 임시 대화 기록
  ScrollController? _listScrollController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _animationController.addListener(() {
      if (_mapAnimation != null) {
        _mapController.value = _mapAnimation!.value; // 애니메이션 값에 따라 지도 화면을 갱신
      }
    });
    _initApp();
  }

  // ✨ 로딩 화면 -> 위치 찾기 -> 지도 열기
  void _initApp() async {
    // 1. 내 위치 가져오기 (권한 허용 기다림)
    _myPosition = await LocationService.getCurrentLocation();
    
    // 2. 위치를 성공적으로 찾았다면?
    if (_myPosition != null) {
      // 지도를 그리기 전에(JS가 실행되기 전에) 초기 위치를 강남역에서 내 위치로 바꿔버립니다!
      js.context.callMethod('setInitialLocation', [_myPosition!.latitude, _myPosition!.longitude]);
    }

    // 3. 로딩 끝! 화면 다시 그리기 (이제 지도가 렌더링됨)
    setState(() {
      _isLoadingLocation = false; 
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

  void _animateMapToRestaurant(Restaurant restaurant) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // 1. 지도 컨테이너 기준 핀의 x, y 좌표
    final double targetTop = (37.5000 - restaurant.latitude) * 100000 + 100;
    final double targetLeft = (restaurant.longitude - 127.0250) * 100000 + 100;

    // 2. 핀 자체의 크기를 감안한 진짜 '핀의 정중앙' 좌표
    final double pinCenterX = targetLeft;
    final double pinCenterY = targetTop + 15;  

    const double targetScale = 2.5;

    // 바텀시트가 0.45(45%)까지 올라와서 화면 하단을 가리고 있으므로,
    // 지도가 보이는 상단 55% 공간의 시각적 정중앙인 0.27(27%) 위치를 타겟으로 잡음
    final double visualCenterY = screenHeight * 0.27; 
    
    final double targetX = (screenWidth / 2) - (pinCenterX * targetScale);
    final double targetY = visualCenterY - (pinCenterY * targetScale);

    final targetMatrix = Matrix4.identity()
      ..setTranslationRaw(targetX, targetY, 0.0)
      ..scale(targetScale);

    _mapAnimation = Matrix4Tween(
      begin: _mapController.value,
      end: targetMatrix,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOutCubic,
    ));

    _animationController.forward(from: 0);

    // 바텀 시트 내리기
    _sheetController.animateTo(
      0.45, 
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOut,
    );
  }

  void _animateToMyLocation() {
    if (_myPosition != null) {
      // GPS 다시 찾을 필요 없이, 실시간으로 추적 중인 최신 좌표로 즉각 이동!
      js.context.callMethod('moveMap', [_myPosition!.latitude, _myPosition!.longitude]);
    }
  }
  // *4번 여기까지*

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
    final selectedCategory = ref.watch(categoryProvider);
    final asyncDisplayedRestaurants = ref.watch(filteredRestaurantsProvider);

    // *변경 코드6*
    Widget buildSheetHeader(int count) {
      return GestureDetector(
        onVerticalDragUpdate: (details) {
          final screenHeight = MediaQuery.of(context).size.height;
          double newSize = _sheetController.size - (details.primaryDelta! / screenHeight);
          _sheetController.jumpTo(newSize.clamp(0.14, 0.87));
        },
        onVerticalDragEnd: (details) {
          final currentSize = _sheetController.size;
          const snapSizes = [0.14, 0.45, 0.87]; 
          double closest = snapSizes.reduce((a, b) => 
            (a - currentSize).abs() < (b - currentSize).abs() ? a : b
          );
          _sheetController.animateTo(
            closest,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
          );
        },
        child: Container(
          color: Colors.transparent, 
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children:[
              Center(child: Container(margin: const EdgeInsets.only(top: 15, bottom: 15), width: 40, height: 5, decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(10)))),
              
              // 📍 1. 타이틀 영역 ('근처 추천 맛집')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20), 
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children:[
                    Text(selectedCategory.isEmpty ? '근처 추천 맛집' : '✨ 추천 $selectedCategory 맛집', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    Text('총 $count곳', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary.withOpacity(0.7))),
                  ],
                ),
              ),

              const SizedBox(height: 15), // 타이틀과 카테고리 사이 여백

              // 📍 2. 카테고리 리스트 영역 (여기로 이사 왔습니다!)
              Container(
                padding: const EdgeInsets.only(left: 20, bottom: 15),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children:[
                      CategoryItem(title: '한식', isSelected: selectedCategory == '한식', onTap: () => ref.read(categoryProvider.notifier).toggleCategory('한식')),
                      CategoryItem(title: '양식', isSelected: selectedCategory == '양식', onTap: () => ref.read(categoryProvider.notifier).toggleCategory('양식')),
                      CategoryItem(title: '중식', isSelected: selectedCategory == '중식', onTap: () => ref.read(categoryProvider.notifier).toggleCategory('중식')),
                      CategoryItem(title: '일식', isSelected: selectedCategory == '일식', onTap: () => ref.read(categoryProvider.notifier).toggleCategory('일식')),
                      CategoryItem(title: '아시안', isSelected: selectedCategory == '아시안', onTap: () => ref.read(categoryProvider.notifier).toggleCategory('아시안')),
                      CategoryItem(title: '멕시칸', isSelected: selectedCategory == '멕시칸', onTap: () => ref.read(categoryProvider.notifier).toggleCategory('멕시칸')),
                      CategoryItem(title: '술집', isSelected: selectedCategory == '술집', onTap: () => ref.read(categoryProvider.notifier).toggleCategory('술집')),
                    ],
                  ),
                ),
              ),
              
              // 하단 리스트와의 구분선
              Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
            ],
          ),
        ),
      );
    }
    // *여기까지 6번*
 

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: _isLoadingLocation
        // 1. 위치 찾는 중일 때: 빙글빙글 로딩창 표시
        ? const Center(child: CircularProgressIndicator()) 
          
          // 2. 위치 다 찾았을 때: 기존에 만든 지도와 UI 표시
        : SafeArea(
          child: Stack(
            children:[
              // 1층: 카카오 지도 배경

              Positioned.fill(
                child: Offstage(
                  offstage: _isChatActive, // 채팅창 열리면 지도 렌더링 잠시 멈춤
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
                                    ref.read(searchQueryProvider.notifier).updateQuery(selection);
                                    FocusScope.of(context).unfocus();
                                  },
                                  
                                  // 3. 기존 검색창 UI 유지
                                  fieldViewBuilder: (BuildContext context, TextEditingController textEditingController, FocusNode focusNode, VoidCallback onFieldSubmitted) {
                                    _searchFocusNode = focusNode;
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
                                              onChanged: (value) {
                                                ref.read(searchQueryProvider.notifier).updateQuery(value);
                                              },
                                              decoration: const InputDecoration(
                                                hintText: '음식점, 주소 검색', 
                                                hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 14), 
                                                border: InputBorder.none
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
              

              // 5층: 찜 목록 버튼 코드
              Positioned(
                top: 20, 
                right: 20,
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (context) => const FavoriteScreen(),
                    ));
                  },
                  child: Container(
                    height: 50, width: 60,
                    decoration: BoxDecoration(
                      color: AppColors.background, 
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 5)],
                      border: Border.all(color: AppColors.error.withOpacity(0.3)), 
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.favorite, color: AppColors.error, size: 20),
                        Text('keep', style: TextStyle(color: AppColors.error, fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),

              // *변경 코드5*
              // 3층: 바텀시트
              DraggableScrollableSheet(
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
                                error: (error, stack) => Column(children:[buildSheetHeader(0), Expanded(child: Center(child: Text('서버와 연결할 수 없어요 😢\n$error', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.error))))]),
                                data: (restaurants) {
                                  return Column(
                                    children:[
                                      buildSheetHeader(restaurants.length),
                                      Expanded(
                                        child: restaurants.isEmpty
                                            ? const Center(child: Text('검색 결과가 없습니다 텅~ 🍃\n다른 키워드로 검색해보세요!', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, fontSize: 16, height: 1.5)))
                                            : ListView.builder(
                                                controller: !_isDetailOpen ? scrollController : null, 
                                                key: const PageStorageKey('restaurant_list'), 
                                                padding: const EdgeInsets.only(bottom: 100),
                                                itemExtent: 85.0,
                                                itemCount: restaurants.length, 
                                                itemBuilder: (context, index) {
                                                  Restaurant restaurant = restaurants[index];
                                                  bool isSelected = _selectedRestaurantId == restaurant.id;

                                                  return Container(
                                                    margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                    decoration: BoxDecoration(color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.transparent, borderRadius: BorderRadius.circular(15), border: Border.all(color: isSelected ? AppColors.primary.withOpacity(0.5) : Colors.transparent, width: 1.5)),
                                                    child: ListTile(
                                                      onTap: () {
                                                        if (isSelected) {
                                                          setState(() {
                                                            _detailRestaurantId = restaurant.id;
                                                            _isDetailOpen = true; 
                                                          });
                                                          Future.delayed(const Duration(milliseconds: 50), () {
                                                            if (_sheetController.isAttached) { // 안전 장치: 컨트롤러가 잘 붙어있는지 확인
                                                              _sheetController.animateTo(
                                                                0.65, 
                                                                duration: const Duration(milliseconds: 400), 
                                                                curve: Curves.easeOutCubic
                                                              );
                                                            }
                                                          });
                                                        } else {
                                                          setState(() => _selectedRestaurantId = restaurant.id);
                                                          _animateMapToRestaurant(restaurant);
                                                          final restaurantsList = ref.read(filteredRestaurantsProvider).value ?? [];
                                                          final targetIndex = restaurantsList.indexWhere((r) => r.id == restaurant.id);
                                                          if (targetIndex != -1) {
                                                            Future.delayed(const Duration(milliseconds: 450), () {
                                                              if (scrollController.hasClients) {
                                                                scrollController.animateTo(targetIndex * 85.0, duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic);
                                                              }
                                                            });
                                                          }
                                                        }
                                                      },
                                                      // leading: ... (이미지 삭제 완료!)
                                                      title: Text(restaurant.name, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                                                      subtitle: Text('⭐ ${restaurant.rating}', style: const TextStyle(color: AppColors.textSecondary)), // 강남구, 거리 삭제 완료!
                                                      trailing: IconButton(icon: Icon(restaurant.isFavorite ? Icons.favorite : Icons.favorite_border, color: restaurant.isFavorite ? AppColors.error : AppColors.divider), onPressed: () => ref.read(restaurantProvider.notifier).toggleFavorite(restaurant.id)),
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
                                          });
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
              // 5.5층: 채팅 활성화 시 나타나는 오버레이 화면
              AnimatedPositioned(
                duration: const Duration(milliseconds: 400), 
                curve: Curves.easeOutCubic, 
                
                top: _isChatActive ? 0 : MediaQuery.of(context).size.height,
                bottom: _isChatActive ? 100 : -MediaQuery.of(context).size.height,
                left: 0,
                right: 0,
                
                child: PointerInterceptor(
                  child: GestureDetector(
                    onTap: () => _chatFocusNode.unfocus(), // 여백 누르면 키보드만 내리기
                    child: Container(
                      color: AppColors.background.withOpacity(0.95),
                      child: SafeArea( 
                        child: Column(
                          children: [
                            // 1. 상단 헤더 (뒤로가기 + 타이틀)
                            Container(
                              height: 60,
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary, size: 28),
                                    onPressed: () {
                                      // 1. 현재 포커스를 완전히 제거해서 키보드를 내립니다.
                                      FocusManager.instance.primaryFocus?.unfocus(); 
                                      
                                      // 2. 약간의 시간차(키보드가 내려가는 물리적인 시간)를 두고 상태를 바꿉니다.
                                      Future.delayed(const Duration(milliseconds: 100), () {
                                        setState(() {
                                          _isChatActive = false;
                                        });
                                      });
                                    },
                                  ),
                                  const SizedBox(width: 5),
                                  const Text(
                                    'AI 맛잘알 챗봇 🤖',
                                    style: TextStyle(
                                      fontSize: 18, 
                                      fontWeight: FontWeight.bold, 
                                      color: AppColors.textPrimary
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            // 2. 기존 채팅 메시지 리스트
                            Expanded(
                              child: ListView.builder(
                                reverse: true, 
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                                itemCount: _chatMessages.length,
                                itemBuilder: (context, index) {
                                  String msg = _chatMessages[_chatMessages.length - 1 - index];
                                  bool isMe = msg.startsWith("USER:");

                                  return Align(
                                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 15),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: isMe ? AppColors.primary : Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(20).copyWith(
                                          bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(20),
                                          bottomLeft: !isMe ? const Radius.circular(0) : const Radius.circular(20),
                                        ),
                                      ),
                                      child: Text(
                                        msg.replaceAll("USER:", "").replaceAll("BOT:", ""),
                                        style: TextStyle(color: isMe ? Colors.white : AppColors.textPrimary),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),  
              ),

              // 6층: 진짜 텍스트를 입력할 수 있는 하단 챗봇 버튼
              Positioned(
                bottom: 40, left: 20, right: 20,

                child: PointerInterceptor(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(30), boxShadow:[BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))], border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 1)),
                    child: Row(
                      children:[
                        const SizedBox(width: 10), const Icon(Icons.smart_toy, color: AppColors.primary), const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _chatInputController,
                            focusNode: _chatFocusNode, // 포커스 노드 연결
                            readOnly: false,
                            onTap: () {
                              setState(() {
                                _isChatActive = true;
                              });
                            },
                            onSubmitted: (text) => _sendMessage(text),
                            decoration: const InputDecoration(hintText: '어디 가고 싶으세요? 맛집 추천해드릴게요!', hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 13), border: InputBorder.none),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _sendMessage(_chatInputController.text),
                          child: Container(padding: const EdgeInsets.all(10), margin: const EdgeInsets.only(left: 5), decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle), child: const Icon(Icons.send, color: AppColors.background, size: 18)),
                        )
                      ],
                    ),
                  ),
                ),
              ),
              // *9번 여기까지*
            ],
          ),
        ),  
    );
  }
}