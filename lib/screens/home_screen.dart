import 'package:flutter/material.dart';

import '../models/festival.dart';
import '../models/korea_region.dart';
import '../services/festival_service.dart';
import '../widgets/festival_detail_sheet.dart';
import '../widgets/korea_map_widget.dart';

enum ScheduleFilter {
  allWithinTwoWeeks('2주 이내 전체'),
  ongoingOnly('현재 진행 중'),
  upcomingOnly('2주 내 개막 예정');

  const ScheduleFilter(this.label);
  final String label;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FestivalService _festivalService = FestivalService();
  final TextEditingController _searchController = TextEditingController();

  DateTime _referenceDate = Festival.dateOnly(DateTime.now());
  KoreaRegion? _selectedRegion;
  ScheduleFilter _scheduleFilter = ScheduleFilter.allWithinTwoWeeks;
  String _searchQuery = '';
  String _tourApiKey = '';

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
            Container(
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
          // 1. 현재 기준일 ~ 2주 이내 조회 기간 배너
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.date_range_rounded,
                  size: 17,
                  color: Color(0xFF38BDF8),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '조회 기간 (2주): ${Festival.formatDate(_referenceDate)} ~ ${Festival.formatDate(twoWeeksLater)}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                if (!isToday)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _referenceDate = today;
                      });
                      _loadFestivals();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF38BDF8),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        '오늘로 복귀',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _isFromApi ? '실시간 TourAPI' : '전국 17개 시도',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFE2E8F0),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // 2. 메인 스크롤 영역 (대한민국 지도 + 지역 선택 칩 + 축제 리스트)
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : CustomScrollView(
                    cacheExtent: 600,
                    slivers: [
                      // 대한민국 지도 영역
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                          child: SizedBox(
                            height: 270,
                            child: KoreaMapWidget(
                              selectedRegion: _selectedRegion,
                              festivalCountsByRegion: countsByRegion,
                              onRegionSelected: (region) {
                                setState(() {
                                  _selectedRegion = region;
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
                            padding: const EdgeInsets.symmetric(horizontal: 14),
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
                                    });
                                  },
                                ),
                              ),
                              ...KoreaRegion.values.map((region) {
                                final count = countsByRegion[region] ?? 0;
                                final isSelected = _selectedRegion == region;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: ChoiceChip(
                                    label: Text('${region.shortName} ($count)'),
                                    selected: isSelected,
                                    selectedColor: region.baseColor.withValues(
                                      alpha: 0.25,
                                    ),
                                    onSelected: (_) {
                                      setState(() {
                                        _selectedRegion =
                                            isSelected ? null : region;
                                      });
                                    },
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ),

                      // 검색 및 일정 상태 필터 바
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
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
                                        fontSize: 16.5,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                  ),
                                  if (_selectedRegion != null)
                                    TextButton.icon(
                                      style: TextButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _selectedRegion = null;
                                        });
                                      },
                                      icon: const Icon(Icons.close, size: 15),
                                      label: const Text('지역 해제'),
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
                                  contentPadding: const EdgeInsets.symmetric(
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
                              // 상태 세그먼트 칩 (2주 이내 전체 / 현재 진행 중 / 2주 내 개막 예정)
                              Wrap(
                                spacing: 8,
                                children: ScheduleFilter.values.map((filter) {
                                  final selected = _scheduleFilter == filter;
                                  return FilterChip(
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
                                        _scheduleFilter = filter;
                                      });
                                    },
                                  );
                                }).toList(),
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
                                onTap: () => FestivalDetailSheet.show(
                                  context,
                                  festival: festival,
                                  referenceDate: _referenceDate,
                                ),
                              );
                            },
                          ),
                        ),
                    ],
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
  });

  final Festival festival;
  final DateTime referenceDate;
  final VoidCallback onTap;

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

              // 축제명
              Text(
                festival.title,
                style: const TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
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
