import 'korea_region.dart';

enum FestivalStatus {
  ongoing,
  upcoming,
  ended,
}

class Festival {
  const Festival({
    required this.id,
    required this.title,
    required this.region,
    required this.cityOrDistrict,
    required this.venue,
    required this.address,
    required this.startDate,
    required this.endDate,
    required this.category,
    required this.summary,
    required this.description,
    this.latitude,
    this.longitude,
    this.tel = '',
    this.feeInfo = '무료 (일부 체험 프로그램 유료)',
    this.homepageUrl = '',
    this.imageUrl = '',
    this.highlights = const [],
  });

  final String id;
  final String title;
  final KoreaRegion region;
  final String cityOrDistrict;
  final String venue;
  final String address;
  final DateTime startDate;
  final DateTime endDate;
  final String category;
  final String summary;
  final String description;
  final double? latitude;
  final double? longitude;
  final String tel;
  final String feeInfo;
  final String homepageUrl;
  final String imageUrl;
  final List<String> highlights;

  /// 네이버 지도 마커 표시용 위도 (미지정 시 지역 중심 위도 반환)
  double get effectiveLat => latitude ?? region.centerLat;

  /// 네이버 지도 마커 표시용 경도 (미지정 시 지역 중심 경도 반환)
  double get effectiveLng => longitude ?? region.centerLng;

  /// 날짜의 시/분/초를 제거한 자정 기준 날짜 반환
  static DateTime dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  /// 기준 날짜(`referenceDate`)로부터 2주(14일) 이내 기간과 축제 기간이 하루라도 겹치는지 확인
  /// - 조회 구간: [today, today + 14일]
  /// - 조건: 축제 종료일 >= today && 축제 시작일 <= today + 14일
  bool isWithinNextTwoWeeks(DateTime referenceDate) {
    final today = dateOnly(referenceDate);
    final twoWeeksLater = today.add(const Duration(days: 14));
    final start = dateOnly(startDate);
    final end = dateOnly(endDate);

    return !end.isBefore(today) && !start.isAfter(twoWeeksLater);
  }

  /// 기준 날짜 대비 축제의 현재 상태 반환
  FestivalStatus statusAt(DateTime referenceDate) {
    final today = dateOnly(referenceDate);
    final start = dateOnly(startDate);
    final end = dateOnly(endDate);

    if (end.isBefore(today)) {
      return FestivalStatus.ended;
    }
    if (!start.isAfter(today) && !end.isBefore(today)) {
      return FestivalStatus.ongoing;
    }
    return FestivalStatus.upcoming;
  }

  /// 기준 날짜 대비 상태 배지 문자열 반환 (예: '진행 중', '오늘 시작', 'D-3', '종료')
  String statusBadgeText(DateTime referenceDate) {
    final today = dateOnly(referenceDate);
    final start = dateOnly(startDate);
    final end = dateOnly(endDate);

    if (end.isBefore(today)) {
      return '종료';
    }
    if (!start.isAfter(today)) {
      final remainingDays = end.difference(today).inDays;
      if (remainingDays == 0) {
        return '오늘 마감';
      }
      return '진행 중 · 종료 D-$remainingDays';
    }
    final daysUntilStart = start.difference(today).inDays;
    return '개막 D-$daysUntilStart';
  }

  /// 정렬 우선순위: 진행 중인 축제 우선 -> 시작일 빠른 순 -> 종료일 빠른 순
  int compareBySchedule(Festival other, DateTime referenceDate) {
    final myStatus = statusAt(referenceDate);
    final otherStatus = statusAt(referenceDate);

    if (myStatus != otherStatus) {
      return myStatus.index.compareTo(otherStatus.index);
    }
    final startCmp = dateOnly(startDate).compareTo(dateOnly(other.startDate));
    if (startCmp != 0) return startCmp;
    return dateOnly(endDate).compareTo(dateOnly(other.endDate));
  }

  /// YYYY.MM.DD 형식 문자열 반환
  static String formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y.$m.$d';
  }

  String get formattedPeriod =>
      '${formatDate(startDate)} ~ ${formatDate(endDate)}';
}
