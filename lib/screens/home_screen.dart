import 'package:flutter/material.dart';

import '../models/festival.dart';
import '../models/korea_region.dart';
import '../services/festival_service.dart';
import '../widgets/festival_detail_sheet.dart';
import '../widgets/korea_map_widget.dart';
import '../widgets/naver_festival_map_widget.dart';

enum ScheduleFilter {
  allWithinTwoWeeks('2주 이내 전체'),
  ongoingOnly('현재 진행 중'),
  upcomingOnly('2주 내 개막 예정');

  const ScheduleFilter(this.label);
  final String label;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.initialUseNaverMap = true,
    this.naverAuthErrorMessage,
    this.naverMapRevision = 0,
    this.onRetryNaverAuth,
  });

  final bool initialUseNaverMap;
  final String? naverAuthErrorMessage;
  final int naverMapRevision;
  final VoidCallback? onRetryNaverAuth;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FestivalService _festivalService = FestivalService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  DateTime _referenceDate = Festival.dateOnly(DateTime.now());
  KoreaRegion? _selectedRegion;
  Festival? _focusedFestival;
  ScheduleFilter _scheduleFilter = ScheduleFilter.allWithinTwoWeeks;
  String _searchQuery = '';
  String _tourApiKey = '';
  late bool _useNaverMap = widget.initialUseNaverMap;

  List<Festival> _allFestivals = [];
  bool _isLoading = true;
  bool _isFromApi = false;

  @override
  void initState() {
    super.initState();
    _loadFestivals();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadFestivals() async {
    setState(() {
      _isLoading = true;
    });

    final result = await _festivalService.fetchFestivals(
      referenceDate: _referenceDate,
      tourApiServiceKey: _tourApiKey,
    );

    if (!mounted) return;
    setState(() {
      _allFestivals = result.festivals;
      _isFromApi = result.isFromApi;
      _isLoading = false;
    });

    if (result.statusMessage != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.statusMessage!),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  /// 기준일로부터 2주(14일) 이내에 진행 중이거나 시작하는 축제만 필터링
  List<Festival> get _festivalsWithinTwoWeeks {
    final list = _allFestivals
        .where((f) => f.isWithinNextTwoWeeks(_referenceDate))
        .toList();
    list.sort((a, b) => a.compareBySchedule(b, _referenceDate));
    return list;
  }

  /// 각 17개 시·도별 2주 이내 축제 개수 집계
  Map<KoreaRegion, int> get _festivalCountsByRegion {
    final counts = <KoreaRegion, int>{
      for (final region in KoreaRegion.values) region: 0,
    };
    for (final festival in _festivalsWithinTwoWeeks) {
      counts[festival.region] = (counts[festival.region] ?? 0) + 1;
    }
    return counts;
  }

  /// 선택된 지역 + 상태 필터 + 검색어가 모두 적용된 최종 축제 목록
  List<Festival> get _filteredFestivals {
    return _festivalsWithinTwoWeeks.where((festival) {
      if (_selectedRegion != null && festival.region != _selectedRegion) {
        return false;
      }
      if (_scheduleFilter == ScheduleFilter.ongoingOnly &&
          festival.statusAt(_referenceDate) != FestivalStatus.ongoing) {
        return false;
      }
      if (_scheduleFilter == ScheduleFilter.upcomingOnly &&
          festival.statusAt(_referenceDate) != FestivalStatus.upcoming) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchesTitle = festival.title.toLowerCase().contains(q);
        final matchesCity = festival.cityOrDistrict.toLowerCase().contains(q);
        final matchesCategory = festival.category.toLowerCase().contains(q);
        final matchesVenue = festival.venue.toLowerCase().contains(q);
        if (!matchesTitle && !matchesCity && !matchesCategory && !matchesVenue) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  void _focusFestivalOnNaverMap(Festival festival) {
    setState(() {
      _useNaverMap = true;
      _selectedRegion = festival.region;
      _focusedFestival = festival;
    });
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _openFestivalDetail(Festival festival) {
    FestivalDetailSheet.show(
      context,
      festival: festival,
      referenceDate: _referenceDate,
      onShowOnNaverMap: () => _focusFestivalOnNaverMap(festival),
    );
  }

  Future<void> _pickReferenceDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _referenceDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: '기준 날짜 선택 (선택일로부터 2주 이내 축제 조회)',
    );
    if (picked != null) {
      setState(() {
        _referenceDate = Festival.dateOnly(picked);
      });
      await _loadFestivals();
    }
  }

  Future<void> _showApiKeyDialog() async {
    final controller = TextEditingController(text: _tourApiKey);
    final saved = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            '한국관광공사 TourAPI 설정',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '공공데이터포털(data.go.kr) 국문 관광정보 서비스 키를 입력하면 실시간 축제 API를 호출합니다.\n비워두면 내장된 전국 17개 시·도 축제 데이터를 사용합니다.',
                style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'TourAPI Service Key (선택)',
                  hintText: '공공데이터포털 인증키 입력',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('적용'),
            ),
          ],
        );
      },
    );

    if (saved != null) {
      setState(() {
        _tourApiKey = saved;
      });
      await _loadFestivals();
    }
  }

  @override
  Widget build(BuildContext context) {
    final twoWeeksLater = _referenceDate.add(const Duration(days: 14));
    final countsByRegion = _festivalCountsByRegion;
    final filtered = _filteredFestivals;
    final today = Festival.dateOnly(DateTime.now());
    final isToday = _referenceDate == today;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        titleSpacing: 16,
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                'assets/icon/app_icon.png',
                width: 36,
                height: 36,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.festival_rounded,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '대한민국 2주 내 축제 지도',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    '지역을 선택해 향후 14일 이내 축제를 확인하세요',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '기준 날짜 변경',
            onPressed: _pickReferenceDate,
            icon: const Icon(Icons.edit_calendar_rounded),
          ),
          IconButton(
            tooltip: 'TourAPI 키 설정',
            onPressed: _showApiKeyDialog,
            icon: Icon(
              _isFromApi ? Icons.cloud_done_rounded : Icons.tune_rounded,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. 현재 기준일 ~ 2주 이내 조회 기간 배너 + 지도 모드 전환 스위치
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.date_range_rounded,
                  size: 16,
                  color: Color(0xFF38BDF8),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '조회 기간 (2주): ${Festival.formatDate(_referenceDate)} ~ ${Festival.formatDate(twoWeeksLater)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                if (!isToday)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _referenceDate = today;
                        });
                        _loadFestivals();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF38BDF8),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          '오늘로 복귀',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ),
                  ),
                // 네이버 지도 <-> 행정구역 지도 전환 버튼
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _useNaverMap = !_useNaverMap;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _useNaverMap
                          ? const Color(0xFF03C75A)
                          : Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _useNaverMap
                              ? Icons.map_rounded
                              : Icons.grid_view_rounded,
                          size: 13,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _useNaverMap ? '네이버 지도 (전환)' : '행정구역도 (전환)',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. 메인 스크롤 영역 (첫 화면: 대형 지도 + 지역 칩 + 검색/필터 도구, 스크롤 시 축제 카드 목록)
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : LayoutBuilder(
                    builder: (context, constraints) {
                      // 첫 화면에 지도 + 지역 칩(44) + 검색/필터 도구(~176)만 딱 맞게 보이도록 지도 높이 자동 계산
                      final mapHeight = (constraints.maxHeight - 224).clamp(
                        340.0,
                        720.0,
                      );

                      return CustomScrollView(
                        controller: _scrollController,
                        cacheExtent: 800,
                        slivers: [
                          // 대한민국 지도 영역 (네이버 지도 SDK 또는 17개 시도 폴리곤 지도)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                14,
                                10,
                                14,
                                8,
                              ),
                              child: SizedBox(
                                height: mapHeight,
                                child: _useNaverMap
                                    ? NaverFestivalMapWidget(
                                        key: ValueKey(widget.naverMapRevision),
                                        selectedRegion: _selectedRegion,
                                        festivalsWithinTwoWeeks:
                                            _festivalsWithinTwoWeeks,
                                        festivalCountsByRegion: countsByRegion,
                                        referenceDate: _referenceDate,
                                        focusedFestival: _focusedFestival,
                                        authErrorMessage:
                                            widget.naverAuthErrorMessage,
                                        onRetryAuth: widget.onRetryNaverAuth,
                                        onRegionSelected: (region) {
                                          setState(() {
                                            _selectedRegion = region;
                                            _focusedFestival = null;
                                          });
                                        },
                                        onFestivalTapped: _openFestivalDetail,
                                      )
                                    : KoreaMapWidget(
                                        selectedRegion: _selectedRegion,
                                        festivalCountsByRegion: countsByRegion,
                                        onRegionSelected: (region) {
                                          setState(() {
                                            _selectedRegion = region;
                                            _focusedFestival = null;
                                          });
                                        },
                                      ),
                              ),
                            ),
                          ),

                          // 가로 스크롤 지역 빠른 선택 바
                          SliverToBoxAdapter(
                            child: SizedBox(
                              height: 44,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                ),
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: ChoiceChip(
                                      label: Text(
                                        '전국 (${_festivalsWithinTwoWeeks.length})',
                                      ),
                                      selected: _selectedRegion == null,
                                      onSelected: (_) {
                                        setState(() {
                                          _selectedRegion = null;
                                          _focusedFestival = null;
                                        });
                                      },
                                    ),
                                  ),
                                  ...KoreaRegion.values.map((region) {
                                    final count = countsByRegion[region] ?? 0;
                                    final isSelected =
                                        _selectedRegion == region;
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 6),
                                      child: ChoiceChip(
                                        label: Text(
                                          '${region.shortName} ($count)',
                                        ),
                                        selected: isSelected,
                                        selectedColor: region.baseColor
                                            .withValues(alpha: 0.25),
                                        onSelected: (_) {
                                          setState(() {
                                            _selectedRegion = isSelected
                                                ? null
                                                : region;
                                            _focusedFestival = null;
                                          });
                                        },
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                          ),

                          // 검색 및 일정 상태 필터 바 (첫 화면 하단에 위치)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                14,
                                8,
                                14,
                                10,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _selectedRegion == null
                                              ? '전국 2주 이내 축제 (${filtered.length}건)'
                                              : '${_selectedRegion!.fullName} 2주 이내 축제 (${filtered.length}건)',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                      ),
                                      if (_selectedRegion != null)
                                        TextButton.icon(
                                          style: TextButton.styleFrom(
                                            visualDensity:
                                                VisualDensity.compact,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _selectedRegion = null;
                                              _focusedFestival = null;
                                            });
                                          },
                                          icon: const Icon(
                                            Icons.close,
                                            size: 15,
                                          ),
                                          label: const Text('지역 해제'),
                                        ),
                                      TextButton.icon(
                                        style: TextButton.styleFrom(
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        onPressed: () {
                                          if (_scrollController.hasClients) {
                                            _scrollController.animateTo(
                                              mapHeight + 50,
                                              duration: const Duration(
                                                milliseconds: 400,
                                              ),
                                              curve: Curves.easeOutCubic,
                                            );
                                          }
                                        },
                                        icon: const Icon(
                                          Icons.keyboard_arrow_down_rounded,
                                          size: 18,
                                        ),
                                        label: const Text('목록 보기'),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  // 검색창
                                  TextField(
                                    controller: _searchController,
                                    onChanged: (value) {
                                      setState(() {
                                        _searchQuery = value.trim();
                                      });
                                    },
                                    decoration: InputDecoration(
                                      hintText: '축제명, 시·군·구, 카테고리 검색',
                                      prefixIcon: const Icon(
                                        Icons.search_rounded,
                                        size: 20,
                                      ),
                                      suffixIcon: _searchQuery.isNotEmpty
                                          ? IconButton(
                                              icon: const Icon(
                                                Icons.clear_rounded,
                                                size: 18,
                                              ),
                                              onPressed: () {
                                                _searchController.clear();
                                                setState(() {
                                                  _searchQuery = '';
                                                });
                                              },
                                            )
                                          : null,
                                      filled: true,
                                      fillColor: Colors.white,
                                      isDense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 10,
                                          ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: const BorderSide(
                                          color: Color(0xFFE2E8F0),
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: const BorderSide(
                                          color: Color(0xFFE2E8F0),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  // 상태 세그먼트 칩 + 스크롤 안내
                                  Row(
                                    children: [
                                      Expanded(
                                        child: SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          child: Row(
                                            children: ScheduleFilter.values.map(
                                              (filter) {
                                                final selected =
                                                    _scheduleFilter == filter;
                                                return Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        right: 8,
                                                      ),
                                                  child: FilterChip(
                                                    visualDensity: VisualDensity
                                                        .compact,
                                                    label: Text(
                                                      filter.label,
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight: selected
                                                            ? FontWeight.w700
                                                            : FontWeight.w500,
                                                      ),
                                                    ),
                                                    selected: selected,
                                                    onSelected: (_) {
                                                      setState(() {
                                                        _scheduleFilter =
                                                            filter;
                                                      });
                                                    },
                                                  ),
                                                );
                                              },
                                            ).toList(),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),

                      // 축제 카드 리스트
                      if (filtered.isEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.event_busy_rounded,
                                    size: 46,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    '해당 조건의 2주 이내 축제가 없습니다.',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '지도에서 다른 지역을 터치하거나 검색 필터를 초기화해 보세요.',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(14, 4, 14, 28),
                          sliver: SliverList.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final festival = filtered[index];
                              return _FestivalCard(
                                festival: festival,
                                referenceDate: _referenceDate,
                                onTap: () => _openFestivalDetail(festival),
                                onMapFocusTap: () =>
                                    _focusFestivalOnNaverMap(festival),
                              );
                            },
                          ),
                        ),
                    ],
                  );
                },
              ),
          ),
        ],
      ),
    );
  }
}

class _FestivalCard extends StatelessWidget {
  const _FestivalCard({
    required this.festival,
    required this.referenceDate,
    required this.onTap,
    required this.onMapFocusTap,
  });

  final Festival festival;
  final DateTime referenceDate;
  final VoidCallback onTap;
  final VoidCallback onMapFocusTap;

  @override
  Widget build(BuildContext context) {
    final status = festival.statusAt(referenceDate);
    final badgeText = festival.statusBadgeText(referenceDate);
    final isOngoing = status == FestivalStatus.ongoing;

    final badgeColor = isOngoing
        ? const Color(0xFF16A34A)
        : const Color(0xFF2563EB);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 상단 지역 배지 + 상태 배지 + 카테고리
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3.5,
                    ),
                    decoration: BoxDecoration(
                      color: festival.region.baseColor.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${festival.region.shortName} · ${festival.cityOrDistrict}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: festival.region.baseColor.withValues(
                          alpha: 0.95,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3.5,
                    ),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: badgeColor,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    festival.category,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // 축제명 + 네이버 지도 위치 이동 버튼
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      festival.title,
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: onMapFocusTap,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF03C75A).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.location_on_rounded,
                            size: 13,
                            color: Color(0xFF03C75A),
                          ),
                          SizedBox(width: 2),
                          Text(
                            '지도위치',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF028A3E),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // 한줄 요약
              Text(
                festival.summary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 10),

              // 기간 및 장소
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today_rounded,
                    size: 14,
                    color: Color(0xFF64748B),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    festival.formattedPeriod,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(
                    Icons.place_outlined,
                    size: 15,
                    color: Color(0xFF64748B),
                  ),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Text(
                      festival.venue,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
