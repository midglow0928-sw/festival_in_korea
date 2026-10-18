import 'package:flutter/material.dart';

/// 대한민국 17개 시·도 행정구역 정의
enum KoreaRegion {
  seoul(
    id: 'seoul',
    shortName: '서울',
    fullName: '서울특별시',
    areaCode: '1',
    baseColor: Color(0xFFEF5350),
    labelPosition: Offset(132, 98),
    isMetropolitan: true,
    polygonPoints: [
      Offset(122, 90),
      Offset(138, 88),
      Offset(143, 97),
      Offset(139, 106),
      Offset(123, 105),
      Offset(119, 97),
    ],
  ),
  incheon(
    id: 'incheon',
    shortName: '인천',
    fullName: '인천광역시',
    areaCode: '2',
    baseColor: Color(0xFF29B6F6),
    labelPosition: Offset(96, 102),
    isMetropolitan: true,
    polygonPoints: [
      Offset(84, 84),
      Offset(107, 86),
      Offset(118, 95),
      Offset(115, 114),
      Offset(92, 117),
      Offset(80, 103),
    ],
  ),
  gyeonggi(
    id: 'gyeonggi',
    shortName: '경기',
    fullName: '경기도',
    areaCode: '31',
    baseColor: Color(0xFFFFA726),
    labelPosition: Offset(146, 124),
    isMetropolitan: false,
    polygonPoints: [
      Offset(106, 54),
      Offset(145, 48),
      Offset(172, 65),
      Offset(182, 102),
      Offset(175, 138),
      Offset(152, 148),
      Offset(114, 145),
      Offset(102, 122),
      Offset(115, 112),
      Offset(106, 84),
    ],
  ),
  gangwon(
    id: 'gangwon',
    shortName: '강원',
    fullName: '강원특별자치도',
    areaCode: '32',
    baseColor: Color(0xFF66BB6A),
    labelPosition: Offset(224, 92),
    isMetropolitan: false,
    polygonPoints: [
      Offset(145, 48),
      Offset(218, 30),
      Offset(252, 62),
      Offset(286, 116),
      Offset(276, 145),
      Offset(230, 148),
      Offset(175, 138),
      Offset(182, 102),
      Offset(172, 65),
    ],
  ),
  sejong(
    id: 'sejong',
    shortName: '세종',
    fullName: '세종특별자치시',
    areaCode: '8',
    baseColor: Color(0xFFAB47BC),
    labelPosition: Offset(138, 174),
    isMetropolitan: true,
    polygonPoints: [
      Offset(131, 164),
      Offset(148, 164),
      Offset(150, 180),
      Offset(133, 182),
    ],
  ),
  daejeon(
    id: 'daejeon',
    shortName: '대전',
    fullName: '대전광역시',
    areaCode: '3',
    baseColor: Color(0xFF7E57C2),
    labelPosition: Offset(152, 200),
    isMetropolitan: true,
    polygonPoints: [
      Offset(142, 190),
      Offset(162, 189),
      Offset(164, 209),
      Offset(143, 210),
    ],
  ),
  chungnam(
    id: 'chungnam',
    shortName: '충남',
    fullName: '충청남도',
    areaCode: '34',
    baseColor: Color(0xFF26A69A),
    labelPosition: Offset(104, 186),
    isMetropolitan: false,
    polygonPoints: [
      Offset(74, 152),
      Offset(114, 145),
      Offset(152, 148),
      Offset(150, 188),
      Offset(143, 212),
      Offset(155, 224),
      Offset(102, 226),
      Offset(82, 202),
      Offset(68, 174),
    ],
  ),
  chungbuk(
    id: 'chungbuk',
    shortName: '충북',
    fullName: '충청북도',
    areaCode: '33',
    baseColor: Color(0xFF9CCC65),
    labelPosition: Offset(185, 168),
    isMetropolitan: false,
    polygonPoints: [
      Offset(152, 148),
      Offset(230, 148),
      Offset(226, 172),
      Offset(198, 196),
      Offset(192, 224),
      Offset(162, 222),
      Offset(162, 188),
      Offset(148, 164),
    ],
  ),
  jeonbuk(
    id: 'jeonbuk',
    shortName: '전북',
    fullName: '전북특별자치도',
    areaCode: '37',
    baseColor: Color(0xFFFFCA28),
    labelPosition: Offset(132, 252),
    isMetropolitan: false,
    polygonPoints: [
      Offset(102, 226),
      Offset(192, 224),
      Offset(188, 274),
      Offset(140, 280),
      Offset(94, 274),
      Offset(88, 248),
    ],
  ),
  gwangju(
    id: 'gwangju',
    shortName: '광주',
    fullName: '광주광역시',
    areaCode: '5',
    baseColor: Color(0xFFEC407A),
    labelPosition: Offset(122, 304),
    isMetropolitan: true,
    polygonPoints: [
      Offset(108, 294),
      Offset(136, 294),
      Offset(138, 314),
      Offset(109, 314),
    ],
  ),
  jeonnam(
    id: 'jeonnam',
    shortName: '전남',
    fullName: '전라남도',
    areaCode: '38',
    baseColor: Color(0xFF42A5F5),
    labelPosition: Offset(124, 342),
    isMetropolitan: false,
    polygonPoints: [
      Offset(94, 274),
      Offset(188, 274),
      Offset(184, 336),
      Offset(152, 368),
      Offset(96, 378),
      Offset(68, 352),
      Offset(74, 306),
    ],
  ),
  daegu(
    id: 'daegu',
    shortName: '대구',
    fullName: '대구광역시',
    areaCode: '4',
    baseColor: Color(0xFFFF7043),
    labelPosition: Offset(234, 246),
    isMetropolitan: true,
    polygonPoints: [
      Offset(218, 232),
      Offset(250, 230),
      Offset(252, 258),
      Offset(220, 260),
    ],
  ),
  gyeongbuk(
    id: 'gyeongbuk',
    shortName: '경북',
    fullName: '경상북도',
    areaCode: '35',
    baseColor: Color(0xFF5C6BC0),
    labelPosition: Offset(248, 192),
    isMetropolitan: false,
    polygonPoints: [
      Offset(230, 148),
      Offset(276, 145),
      Offset(298, 185),
      Offset(296, 256),
      Offset(262, 266),
      Offset(250, 230),
      Offset(218, 232),
      Offset(220, 260),
      Offset(188, 256),
      Offset(192, 224),
      Offset(198, 196),
      Offset(226, 172),
    ],
  ),
  ulsan(
    id: 'ulsan',
    shortName: '울산',
    fullName: '울산광역시',
    areaCode: '7',
    baseColor: Color(0xFF26C6DA),
    labelPosition: Offset(284, 278),
    isMetropolitan: true,
    polygonPoints: [
      Offset(266, 264),
      Offset(298, 260),
      Offset(300, 294),
      Offset(268, 294),
    ],
  ),
  busan(
    id: 'busan',
    shortName: '부산',
    fullName: '부산광역시',
    areaCode: '6',
    baseColor: Color(0xFF1E88E5),
    labelPosition: Offset(272, 314),
    isMetropolitan: true,
    polygonPoints: [
      Offset(252, 298),
      Offset(292, 294),
      Offset(286, 328),
      Offset(248, 326),
    ],
  ),
  gyeongnam(
    id: 'gyeongnam',
    shortName: '경남',
    fullName: '경상남도',
    areaCode: '36',
    baseColor: Color(0xFF8D6E63),
    labelPosition: Offset(218, 298),
    isMetropolitan: false,
    polygonPoints: [
      Offset(188, 256),
      Offset(262, 266),
      Offset(268, 294),
      Offset(252, 298),
      Offset(248, 326),
      Offset(230, 344),
      Offset(184, 336),
    ],
  ),
  jeju(
    id: 'jeju',
    shortName: '제주',
    fullName: '제주특별자치도',
    areaCode: '39',
    baseColor: Color(0xFFFF8A65),
    labelPosition: Offset(116, 412),
    isMetropolitan: false,
    polygonPoints: [
      Offset(84, 398),
      Offset(132, 394),
      Offset(152, 408),
      Offset(138, 426),
      Offset(90, 428),
      Offset(74, 414),
    ],
  );

  const KoreaRegion({
    required this.id,
    required this.shortName,
    required this.fullName,
    required this.areaCode,
    required this.baseColor,
    required this.labelPosition,
    required this.isMetropolitan,
    required this.polygonPoints,
  });

  final String id;
  final String shortName;
  final String fullName;
  final String areaCode;
  final Color baseColor;
  final Offset labelPosition;

  /// 광역시·특별시는 도(道) 내부에 포함되거나 인접하므로 터치 판정 시 우선순위를 높임
  final bool isMetropolitan;
  final List<Offset> polygonPoints;

  /// 지도 캔버스의 기준 크기
  static const Size mapCanvasSize = Size(340, 445);

  /// 폴리곤 Path 생성
  Path toPath() {
    final path = Path();
    if (polygonPoints.isEmpty) return path;
    path.moveTo(polygonPoints.first.dx, polygonPoints.first.dy);
    for (var i = 1; i < polygonPoints.length; i++) {
      path.lineTo(polygonPoints[i].dx, polygonPoints[i].dy);
    }
    path.close();
    return path;
  }

  /// 터치 판정용 정렬 리스트 (광역시·특별시 먼저 검사 후 일반 도 검사)
  static List<KoreaRegion> get hitTestOrder {
    final metros = values.where((r) => r.isMetropolitan).toList();
    final provinces = values.where((r) => !r.isMetropolitan).toList();
    return [...metros, ...provinces];
  }

  /// TourAPI areaCode 또는 주소 문자열로부터 지역 매핑
  static KoreaRegion? fromAreaCodeOrAddress({
    String? areaCode,
    String? address,
  }) {
    if (areaCode != null && areaCode.isNotEmpty) {
      for (final region in values) {
        if (region.areaCode == areaCode) {
          return region;
        }
      }
    }
    if (address != null && address.isNotEmpty) {
      for (final region in values) {
        if (address.contains(region.shortName) ||
            address.contains(region.fullName)) {
          return region;
        }
      }
    }
    return null;
  }
}
