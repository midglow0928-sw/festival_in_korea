import 'package:flutter/material.dart';

import '../models/korea_region.dart';

class KoreaMapWidget extends StatefulWidget {
  const KoreaMapWidget({
    super.key,
    required this.selectedRegion,
    required this.festivalCountsByRegion,
    required this.onRegionSelected,
  });

  final KoreaRegion? selectedRegion;
  final Map<KoreaRegion, int> festivalCountsByRegion;
  final ValueChanged<KoreaRegion?> onRegionSelected;

  @override
  State<KoreaMapWidget> createState() => _KoreaMapWidgetState();
}

class _KoreaMapWidgetState extends State<KoreaMapWidget> {
  final TransformationController _transformController =
      TransformationController();

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  void _resetZoom() {
    _transformController.value = Matrix4.identity();
  }

  void _handleTapUp(TapUpDetails details, Size widgetSize) {
    final canvasPoint = _toCanvasOffset(details.localPosition, widgetSize);
    if (canvasPoint == null) return;

    // 1차: 폴리곤 내부 터치 판정 (광역시·특별시 우선)
    for (final region in KoreaRegion.hitTestOrder) {
      if (region.toPath().contains(canvasPoint)) {
        _toggleOrSelect(region);
        return;
      }
    }

    // 2차: 라벨 배지 근처 터치 판정 (작은 광역시 터치 편의성 향상)
    KoreaRegion? closestRegion;
    var minDistance = 26.0;
    for (final region in KoreaRegion.hitTestOrder) {
      final dist = (region.labelPosition - canvasPoint).distance;
      if (dist < minDistance) {
        minDistance = dist;
        closestRegion = region;
      }
    }

    if (closestRegion != null) {
      _toggleOrSelect(closestRegion);
    }
  }

  void _toggleOrSelect(KoreaRegion region) {
    if (widget.selectedRegion == region) {
      widget.onRegionSelected(null);
    } else {
      widget.onRegionSelected(region);
    }
  }

  Offset? _toCanvasOffset(Offset localPosition, Size widgetSize) {
    const mapSize = KoreaRegion.mapCanvasSize;
    final scaleX = widgetSize.width / mapSize.width;
    final scaleY = widgetSize.height / mapSize.height;
    final scale = scaleX < scaleY ? scaleX : scaleY;

    final offsetX = (widgetSize.width - mapSize.width * scale) / 2;
    final offsetY = (widgetSize.height - mapSize.height * scale) / 2;

    final dx = (localPosition.dx - offsetX) / scale;
    final dy = (localPosition.dy - offsetY) / scale;

    if (dx < 0 ||
        dy < 0 ||
        dx > mapSize.width ||
        dy > mapSize.height) {
      return null;
    }
    return Offset(dx, dy);
  }

  @override
  Widget build(BuildContext context) {
    final totalCount = widget.festivalCountsByRegion.values.fold<int>(
      0,
      (sum, c) => sum + c,
    );

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFEBF5FB),
            Color(0xFFD6EAF8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFB3D4FC), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // 인터랙티브 대한민국 행정구역 지도
            LayoutBuilder(
              builder: (context, constraints) {
                final size = Size(constraints.maxWidth, constraints.maxHeight);
                return InteractiveViewer(
                  transformationController: _transformController,
                  minScale: 1.0,
                  maxScale: 2.8,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (details) => _handleTapUp(details, size),
                    child: CustomPaint(
                      size: size,
                      painter: _KoreaMapPainter(
                        selectedRegion: widget.selectedRegion,
                        festivalCountsByRegion: widget.festivalCountsByRegion,
                      ),
                    ),
                  ),
                );
              },
            ),

            // 좌측 상단 안내 배지
            Positioned(
              top: 10,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.touch_app_rounded,
                      size: 15,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      widget.selectedRegion == null
                          ? '지도에서 지역을 터치하세요 (전국 $totalCount개)'
                          : '${widget.selectedRegion!.fullName} 선택됨 (다시 터치 시 해제)',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 우측 상단 컨트롤 버튼 (전체보기 / 확대 초기화)
            Positioned(
              top: 10,
              right: 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (widget.selectedRegion != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Material(
                        color: Theme.of(context).colorScheme.primary,
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
                    ),
                  Material(
                    color: Colors.white.withValues(alpha: 0.88),
                    shape: const CircleBorder(),
                    child: IconButton(
                      tooltip: '지도 배율 초기화',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.center_focus_strong, size: 18),
                      onPressed: _resetZoom,
                    ),
                  ),
                ],
              ),
            ),

            // 좌측 하단 제주도 구분선 라벨
            Positioned(
              bottom: 8,
              right: 12,
              child: Text(
                '두 손가락으로 지도를 확대할 수 있습니다',
                style: TextStyle(
                  fontSize: 10.5,
                  color: Colors.blueGrey.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KoreaMapPainter extends CustomPainter {
  _KoreaMapPainter({
    required this.selectedRegion,
    required this.festivalCountsByRegion,
  });

  final KoreaRegion? selectedRegion;
  final Map<KoreaRegion, int> festivalCountsByRegion;

  @override
  void paint(Canvas canvas, Size size) {
    const mapSize = KoreaRegion.mapCanvasSize;
    final scaleX = size.width / mapSize.width;
    final scaleY = size.height / mapSize.height;
    final scale = scaleX < scaleY ? scaleX : scaleY;

    final offsetX = (size.width - mapSize.width * scale) / 2;
    final offsetY = (size.height - mapSize.height * scale) / 2;

    canvas.save();
    canvas.translate(offsetX, offsetY);
    canvas.scale(scale);

    // 제주도 구분 점선 박스
    final jejuBoxPaint = Paint()
      ..color = const Color(0xFF90CAF9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(58, 384, 112, 52),
        const Radius.circular(10),
      ),
      jejuBoxPaint,
    );

    // 1. 일반 도(Province) 먼저 그린 후 광역시·특별시를 위에 그림
    final provinces =
        KoreaRegion.values.where((r) => !r.isMetropolitan).toList();
    final metros = KoreaRegion.values.where((r) => r.isMetropolitan).toList();
    final drawOrder = [...provinces, ...metros];

    for (final region in drawOrder) {
      final path = region.toPath();
      final isSelected = selectedRegion == region;
      final isDimmed = selectedRegion != null && !isSelected;
      final count = festivalCountsByRegion[region] ?? 0;

      // 그림자
      canvas.drawShadow(
        path,
        Colors.black.withValues(alpha: isSelected ? 0.35 : 0.14),
        isSelected ? 6.0 : 2.0,
        false,
      );

      // 채우기 색상
      Color fillColor;
      if (isSelected) {
        fillColor = region.baseColor;
      } else if (isDimmed) {
        fillColor = Color.lerp(region.baseColor, Colors.white, 0.62)!;
      } else if (count > 0) {
        fillColor = Color.lerp(region.baseColor, Colors.white, 0.22)!;
      } else {
        fillColor = Colors.grey.shade300;
      }

      final fillPaint = Paint()
        ..color = fillColor
        ..style = PaintingStyle.fill;
      canvas.drawPath(path, fillPaint);

      // 외곽선
      final borderPaint = Paint()
        ..color = isSelected
            ? const Color(0xFF0F172A)
            : Colors.white.withValues(alpha: 0.92)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? 2.4 : 1.3
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(path, borderPaint);
    }

    // 2. 각 지역 라벨 및 2주 이내 축제 개수 배지 렌더링
    for (final region in drawOrder) {
      final isSelected = selectedRegion == region;
      final count = festivalCountsByRegion[region] ?? 0;
      _drawRegionBadge(
        canvas: canvas,
        region: region,
        count: count,
        isSelected: isSelected,
      );
    }

    canvas.restore();
  }

  void _drawRegionBadge({
    required Canvas canvas,
    required KoreaRegion region,
    required int count,
    required bool isSelected,
  }) {
    final text = count > 0 ? '${region.shortName} $count' : region.shortName;
    final textStyle = TextStyle(
      color: isSelected
          ? Colors.white
          : (count > 0 ? const Color(0xFF0F172A) : Colors.grey.shade600),
      fontSize: isSelected ? 10.5 : 9.5,
      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
      height: 1.1,
    );

    final textSpan = TextSpan(text: text, style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    final padH = isSelected ? 6.5 : 5.0;
    final padV = isSelected ? 3.5 : 2.5;
    final rectWidth = textPainter.width + padH * 2;
    final rectHeight = textPainter.height + padV * 2;

    final badgeRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: region.labelPosition,
        width: rectWidth,
        height: rectHeight,
      ),
      const Radius.circular(10),
    );

    final badgeBgPaint = Paint()
      ..color = isSelected
          ? const Color(0xFF0F172A)
          : Colors.white.withValues(alpha: 0.90)
      ..style = PaintingStyle.fill;

    final badgeBorderPaint = Paint()
      ..color = isSelected
          ? Colors.amberAccent
          : region.baseColor.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSelected ? 1.6 : 1.1;

    canvas.drawRRect(badgeRect, badgeBgPaint);
    canvas.drawRRect(badgeRect, badgeBorderPaint);

    textPainter.paint(
      canvas,
      Offset(
        region.labelPosition.dx - textPainter.width / 2,
        region.labelPosition.dy - textPainter.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _KoreaMapPainter oldDelegate) {
    return oldDelegate.selectedRegion != selectedRegion ||
        oldDelegate.festivalCountsByRegion != festivalCountsByRegion;
  }
}
