import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

import '../models/festival.dart';
import '../models/korea_region.dart';

class NaverFestivalMapWidget extends StatefulWidget {
  const NaverFestivalMapWidget({
    super.key,
    required this.selectedRegion,
    required this.festivalsWithinTwoWeeks,
    required this.festivalCountsByRegion,
    required this.referenceDate,
    required this.onRegionSelected,
    required this.onFestivalTapped,
    this.focusedFestival,
    this.authErrorMessage,
    this.onRetryAuth,
  });

  final KoreaRegion? selectedRegion;
  final List<Festival> festivalsWithinTwoWeeks;
  final Map<KoreaRegion, int> festivalCountsByRegion;
  final DateTime referenceDate;
  final ValueChanged<KoreaRegion?> onRegionSelected;
  final ValueChanged<Festival> onFestivalTapped;
  final Festival? focusedFestival;
  final String? authErrorMessage;
  final VoidCallback? onRetryAuth;

  @override
  State<NaverFestivalMapWidget> createState() => _NaverFestivalMapWidgetState();
}

class _NaverFestivalMapWidgetState extends State<NaverFestivalMapWidget> {
  NaverMapController? _mapController;
  final NDefaultMyLocationTracker _locationTracker =
      NDefaultMyLocationTracker();
  bool _showAllFestivalPinsInNationwide = false;
  bool _didInitialGpsMove = false;
  bool _suppressNextRegionCameraMove = false;
  NLatLng? _currentGpsLatLng;

  @override
  void didUpdateWidget(covariant NaverFestivalMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusedFestival != null &&
        oldWidget.focusedFestival != widget.focusedFestival) {
      _moveCameraToFestival(widget.focusedFestival!);
      _refreshOverlays();
    } else if (oldWidget.selectedRegion != widget.selectedRegion) {
      if (_suppressNextRegionCameraMove) {
        _suppressNextRegionCameraMove = false;
      } else {
        _moveCameraToRegion(widget.selectedRegion);
      }
      _refreshOverlays();
    } else if (oldWidget.festivalsWithinTwoWeeks !=
            widget.festivalsWithinTwoWeeks ||
        oldWidget.referenceDate != widget.referenceDate) {
      _refreshOverlays();
    }
  }

  /// 앱 시작 또는 '내 위치' 버튼 터치 시 실제 기기 GPS 위치를 가져와 이동
  Future<void> _moveToCurrentGpsLocation({
    bool autoSelectRegion = true,
  }) async {
    final controller = _mapController;
    if (controller == null) return;

    try {
      final pos = await _locationTracker.startLocationService();
      if (!mounted || pos == null) return;

      _currentGpsLatLng = pos;

      // 내 위치 파란 점 오버레이 활성화 및 실시간 위치 표시
      final locationOverlay = controller.getLocationOverlay();
      locationOverlay.setPosition(pos);
      locationOverlay.setIsVisible(true);
      controller.setLocationTrackingMode(NLocationTrackingMode.noFollow);

      if (KoreaRegion.isWithinKoreaBounds(pos.latitude, pos.longitude)) {
        final nearestRegion = KoreaRegion.nearestToLatLng(
          pos.latitude,
          pos.longitude,
        );

        if (autoSelectRegion &&
            nearestRegion != null &&
            widget.selectedRegion != nearestRegion) {
          // 내 실제 GPS 좌표를 중심으로 카메라를 맞추면서 해당 지역 선택
          _suppressNextRegionCameraMove = true;
          widget.onRegionSelected(nearestRegion);
        }

        final update = NCameraUpdate.scrollAndZoomTo(
          target: pos,
          zoom: 11.2,
        )..setAnimation(
            animation: NCameraAnimation.fly,
            duration: const Duration(milliseconds: 650),
          );
        await controller.updateCamera(update);
      }
    } catch (e) {
      debugPrint('Failed to get current GPS position: $e');
    }
  }

  Future<void> _moveCameraToFestival(Festival festival) async {
    final controller = _mapController;
    if (controller == null) return;

    final update = NCameraUpdate.scrollAndZoomTo(
      target: NLatLng(festival.effectiveLat, festival.effectiveLng),
      zoom: 13.5,
    )..setAnimation(
        animation: NCameraAnimation.fly,
        duration: const Duration(milliseconds: 600),
      );
    await controller.updateCamera(update);
  }

  Future<void> _moveCameraToRegion(KoreaRegion? region) async {
    final controller = _mapController;
    if (controller == null) return;

    final target = region != null
        ? NLatLng(region.centerLat, region.centerLng)
        : const NLatLng(
            KoreaRegion.koreaCenterLat,
            KoreaRegion.koreaCenterLng,
          );
    final zoom = region?.defaultZoom ?? KoreaRegion.koreaDefaultZoom;

    final update = NCameraUpdate.scrollAndZoomTo(
      target: target,
      zoom: zoom,
    )..setAnimation(
        animation: NCameraAnimation.fly,
        duration: const Duration(milliseconds: 550),
      );

    await controller.updateCamera(update);
  }

  Future<void> _refreshOverlays() async {
    final controller = _mapController;
    if (controller == null) return;

    await controller.clearOverlays();

    // clearOverlays 후 내 위치 오버레이 복원
    if (_currentGpsLatLng != null) {
      final locationOverlay = controller.getLocationOverlay();
      locationOverlay.setPosition(_currentGpsLatLng!);
      locationOverlay.setIsVisible(true);
    }

    final overlays = <NAddableOverlay>{};
    final selectedRegion = widget.selectedRegion;

    // 1. 특정 지역이 선택되었거나 '전국 축제 핀 보기' 모드일 때: 개별 축제 마커 표시
    if (selectedRegion != null || _showAllFestivalPinsInNationwide) {
      final targetFestivals = selectedRegion == null
          ? widget.festivalsWithinTwoWeeks
          : widget.festivalsWithinTwoWeeks
                .where((f) => f.region == selectedRegion)
                .toList();

      for (final festival in targetFestivals) {
        final isOngoing =
            festival.statusAt(widget.referenceDate) == FestivalStatus.ongoing;
        final marker = NMarker(
          id: 'festival_${festival.id}',
          position: NLatLng(festival.effectiveLat, festival.effectiveLng),
          iconTintColor: isOngoing
              ? const Color(0xFF16A34A)
              : const Color(0xFF2563EB),
          caption: NOverlayCaption(
            text: festival.title,
            textSize: 12,
            color: const Color(0xFF0F172A),
            haloColor: Colors.white,
            requestWidth: 150,
          ),
          subCaption: NOverlayCaption(
            text:
                '${festival.cityOrDistrict} · ${festival.statusBadgeText(widget.referenceDate)}',
            textSize: 10.5,
            color: isOngoing
                ? const Color(0xFF15803D)
                : const Color(0xFF1D4ED8),
            haloColor: Colors.white,
          ),
          isHideCollidedCaptions: true,
        );

        marker.setOnTapListener((_) {
          widget.onFestivalTapped(festival);
        });
        overlays.add(marker);
      }
    } else {
      // 2. 전국 보기 기본 모드: 17개 시·도별 마커 표시 (터치 시 해당 지역으로 줌인 + 필터)
      for (final region in KoreaRegion.values) {
        final count = widget.festivalCountsByRegion[region] ?? 0;
        final marker = NMarker(
          id: 'region_${region.id}',
          position: NLatLng(region.centerLat, region.centerLng),
          iconTintColor: region.baseColor,
          caption: NOverlayCaption(
            text: '${region.shortName} ($count)',
            textSize: 12.5,
            color: const Color(0xFF0F172A),
            haloColor: Colors.white,
          ),
          subCaption: count > 0
              ? const NOverlayCaption(
                  text: '터치하여 선택',
                  textSize: 9.5,
                  color: Color(0xFF475569),
                  haloColor: Colors.white,
                )
              : null,
        );

        marker.setOnTapListener((_) {
          widget.onRegionSelected(region);
        });
        overlays.add(marker);
      }
    }

    if (overlays.isNotEmpty) {
      await controller.addOverlayAll(overlays);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedRegion = widget.selectedRegion;
    final initialTarget = selectedRegion != null
        ? NLatLng(selectedRegion.centerLat, selectedRegion.centerLng)
        : const NLatLng(
            KoreaRegion.koreaCenterLat,
            KoreaRegion.koreaCenterLng,
          );
    final initialZoom =
        selectedRegion?.defaultZoom ?? KoreaRegion.koreaDefaultZoom;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2DB400), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(19),
        child: Stack(
          children: [
            NaverMap(
              forceGesture: true,
              options: NaverMapViewOptions(
                initialCameraPosition: NCameraPosition(
                  target: initialTarget,
                  zoom: initialZoom,
                ),
                minZoom: 5.5,
                maxZoom: 18.0,
                scaleBarEnable: true,
                compassEnable: true,
                locationButtonEnable: false,
                indoorEnable: false,
                consumeSymbolTapEvents: false,
              ),
              onMapReady: (controller) async {
                _mapController = controller;
                await _refreshOverlays();
                if (!_didInitialGpsMove && widget.selectedRegion == null) {
                  _didInitialGpsMove = true;
                  await _moveToCurrentGpsLocation(autoSelectRegion: true);
                }
              },
            ),

            // 좌측 상단 상태 배지
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF03C75A),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      selectedRegion == null
                          ? (_showAllFestivalPinsInNationwide
                                ? '네이버 지도 · 전국 축제 핀 표시 중'
                                : '네이버 지도 · 지역 마커를 터치하세요')
                          : '네이버 지도 · ${selectedRegion.fullName} 축제 핀',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 우측 상단 컨트롤 버튼 (전국 전체보기 / 내 현재 GPS 위치로 이동)
            Positioned(
              top: 10,
              right: 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (selectedRegion != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Material(
                        color: const Color(0xFF03C75A),
                        borderRadius: BorderRadius.circular(18),
                        elevation: 2,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () => widget.onRegionSelected(null),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.public,
                                  size: 14,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  '전국 전체보기',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Material(
                        color: Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(18),
                        elevation: 2,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () {
                            setState(() {
                              _showAllFestivalPinsInNationwide =
                                  !_showAllFestivalPinsInNationwide;
                            });
                            _refreshOverlays();
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _showAllFestivalPinsInNationwide
                                      ? Icons.account_tree_outlined
                                      : Icons.place_rounded,
                                  size: 14,
                                  color: const Color(0xFF03C75A),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _showAllFestivalPinsInNationwide
                                      ? '17개 시도별 보기'
                                      : '전국 축제 핀 모두 보기',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  Material(
                    color: Colors.white.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(18),
                    elevation: 2,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () =>
                          _moveToCurrentGpsLocation(autoSelectRegion: true),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.my_location_rounded,
                              size: 15,
                              color: Color(0xFF2563EB),
                            ),
                            SizedBox(width: 4),
                            Text(
                              '내 위치',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 인증 오류 발생 시 안내 배너
            if (widget.authErrorMessage != null)
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.authErrorMessage!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF991B1B),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (widget.onRetryAuth != null)
                        TextButton(
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: widget.onRetryAuth,
                          child: const Text(
                            '재시도',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
