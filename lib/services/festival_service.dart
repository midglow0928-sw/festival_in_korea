import 'dart:convert';
import 'dart:io';

import '../data/sample_festivals.dart';
import '../models/festival.dart';
import '../models/korea_region.dart';

class FestivalFetchResult {
  const FestivalFetchResult({
    required this.festivals,
    required this.isFromApi,
    this.statusMessage,
  });

  final List<Festival> festivals;
  final bool isFromApi;
  final String? statusMessage;
}

class FestivalService {
  /// 기준일(referenceDate) 기준 2주 이내 축제 데이터를 조회합니다.
  /// 공공데이터포털 TourAPI 서비스 키가 입력된 경우 API를 우선 호출하고,
  /// 키가 없거나 네트워크/API 오류 시 내장된 전국 17개 시·도 축제 데이터를 반환합니다.
  Future<FestivalFetchResult> fetchFestivals({
    required DateTime referenceDate,
    String? tourApiServiceKey,
  }) async {
    final trimmedKey = tourApiServiceKey?.trim() ?? '';
    if (trimmedKey.isEmpty) {
      return FestivalFetchResult(
        festivals: SampleFestivals.buildForDate(referenceDate),
        isFromApi: false,
      );
    }

    try {
      final apiFestivals = await _fetchFromTourApi(
        referenceDate: referenceDate,
        serviceKey: trimmedKey,
      );
      if (apiFestivals.isNotEmpty) {
        return FestivalFetchResult(
          festivals: apiFestivals,
          isFromApi: true,
          statusMessage: '한국관광공사 TourAPI 실시간 연동 완료 (${apiFestivals.length}건)',
        );
      }
      return FestivalFetchResult(
        festivals: SampleFestivals.buildForDate(referenceDate),
        isFromApi: false,
        statusMessage: 'API 조회 결과가 없어 기본 축제 데이터를 표시합니다.',
      );
    } catch (e) {
      return FestivalFetchResult(
        festivals: SampleFestivals.buildForDate(referenceDate),
        isFromApi: false,
        statusMessage: 'TourAPI 호출 실패로 기본 데이터를 표시합니다. ($e)',
      );
    }
  }

  Future<List<Festival>> _fetchFromTourApi({
    required DateTime referenceDate,
    required String serviceKey,
  }) async {
    final today = Festival.dateOnly(referenceDate);
    final startStr = _toYyyyMmDd(today);

    // 이미 인코딩된 키와 디코딩된 키 모두 지원
    final encodedKey =
        serviceKey.contains('%') ? serviceKey : Uri.encodeComponent(serviceKey);

    final url =
        'https://apis.data.go.kr/B551011/KorService1/searchFestival1'
        '?serviceKey=$encodedKey'
        '&numOfRows=200'
        '&pageNo=1'
        '&MobileOS=AND'
        '&MobileApp=FestivalInKorea'
        '&_type=json'
        '&listYN=Y'
        '&arrange=A'
        '&eventStartDate=$startStr';

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      if (response.statusCode != 200) {
        throw HttpException('HTTP ${response.statusCode}');
      }
      final body = await response.transform(utf8.decoder).join();
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final responseObj = decoded['response'] as Map<String, dynamic>?;
      final bodyObj = responseObj?['body'] as Map<String, dynamic>?;
      final itemsObj = bodyObj?['items'];

      if (itemsObj is! Map<String, dynamic>) {
        return [];
      }
      final rawItem = itemsObj['item'];
      final List<dynamic> itemList;
      if (rawItem is List) {
        itemList = rawItem;
      } else if (rawItem is Map) {
        itemList = [rawItem];
      } else {
        return [];
      }

      final results = <Festival>[];
      for (final item in itemList) {
        if (item is! Map<String, dynamic>) continue;
        final parsed = _parseTourApiItem(item);
        if (parsed != null) {
          results.add(parsed);
        }
      }
      return results;
    } finally {
      client.close();
    }
  }

  Festival? _parseTourApiItem(Map<String, dynamic> item) {
    final title = (item['title'] ?? '').toString().trim();
    final startRaw = (item['eventstartdate'] ?? '').toString().trim();
    final endRaw = (item['eventenddate'] ?? '').toString().trim();
    if (title.isEmpty || startRaw.length != 8 || endRaw.length != 8) {
      return null;
    }

    final startDate = _parseYyyyMmDd(startRaw);
    final endDate = _parseYyyyMmDd(endRaw);
    if (startDate == null || endDate == null) return null;

    final addr1 = (item['addr1'] ?? '').toString().trim();
    final addr2 = (item['addr2'] ?? '').toString().trim();
    final fullAddress = [addr1, addr2].where((s) => s.isNotEmpty).join(' ');
    final areaCode = (item['areacode'] ?? '').toString().trim();

    final region = KoreaRegion.fromAreaCodeOrAddress(
      areaCode: areaCode,
      address: fullAddress,
    );
    if (region == null) return null;

    final addressTokens = addr1.split(' ');
    final cityOrDistrict =
        addressTokens.length >= 2 ? addressTokens[1] : region.shortName;

    final lat = double.tryParse((item['mapy'] ?? '').toString().trim());
    final lng = double.tryParse((item['mapx'] ?? '').toString().trim());

    return Festival(
      id: (item['contentid'] ?? title).toString(),
      title: title,
      region: region,
      cityOrDistrict: cityOrDistrict,
      venue: addr2.isNotEmpty ? addr2 : addr1,
      address: fullAddress.isNotEmpty ? fullAddress : region.fullName,
      latitude: lat,
      longitude: lng,
      startDate: startDate,
      endDate: endDate,
      category: '문화·관광축제',
      summary: '$cityOrDistrict 일원에서 열리는 지역 대표 축제',
      description:
          '$fullAddress 일원에서 개최되는 축제입니다. 자세한 행사 일정과 프로그램은 주최 측 안내를 참고해 주세요.',
      tel: (item['tel'] ?? '').toString().trim(),
      imageUrl: (item['firstimage'] ?? '').toString().trim(),
      highlights: ['현장 체험 프로그램', '지역 문화 공연 및 부대행사'],
    );
  }

  static String _toYyyyMmDd(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y$m$day';
  }

  static DateTime? _parseYyyyMmDd(String raw) {
    if (raw.length != 8) return null;
    final y = int.tryParse(raw.substring(0, 4));
    final m = int.tryParse(raw.substring(4, 6));
    final d = int.tryParse(raw.substring(6, 8));
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }
}
