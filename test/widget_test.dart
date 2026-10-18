import 'package:festival_in_korea/main.dart';
import 'package:festival_in_korea/models/festival.dart';
import 'package:festival_in_korea/models/korea_region.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('2주 이내 축제 날짜 필터 검증', () {
    final referenceDate = DateTime(2026, 10, 18);

    Festival makeFestival(DateTime start, DateTime end) {
      return Festival(
        id: 'test',
        title: '테스트 축제',
        region: KoreaRegion.seoul,
        cityOrDistrict: '종로구',
        venue: '광화문광장',
        address: '서울특별시 종로구',
        startDate: start,
        endDate: end,
        category: '문화',
        summary: '요약',
        description: '설명',
      );
    }

    test('현재 진행 중인 축제는 2주 이내 필터에 포함된다', () {
      final ongoing = makeFestival(
        DateTime(2026, 10, 15),
        DateTime(2026, 10, 20),
      );
      expect(ongoing.isWithinNextTwoWeeks(referenceDate), isTrue);
      expect(ongoing.statusAt(referenceDate), FestivalStatus.ongoing);
    });

    test('기준일로부터 정확히 14일 뒤에 시작하는 축제까지 포함된다', () {
      final day14 = makeFestival(
        DateTime(2026, 11, 1),
        DateTime(2026, 11, 5),
      );
      expect(day14.isWithinNextTwoWeeks(referenceDate), isTrue);
      expect(day14.statusAt(referenceDate), FestivalStatus.upcoming);
    });

    test('기준일 이전에 이미 종료된 축제는 제외된다', () {
      final ended = makeFestival(
        DateTime(2026, 10, 1),
        DateTime(2026, 10, 17),
      );
      expect(ended.isWithinNextTwoWeeks(referenceDate), isFalse);
      expect(ended.statusAt(referenceDate), FestivalStatus.ended);
    });

    test('기준일로부터 15일 이후에 시작하는 축제는 제외된다', () {
      final tooLate = makeFestival(
        DateTime(2026, 11, 2),
        DateTime(2026, 11, 10),
      );
      expect(tooLate.isWithinNextTwoWeeks(referenceDate), isFalse);
    });
  });

  testWidgets('메인 화면에서 대한민국 지도 및 지역 선택 필터가 동작한다', (WidgetTester tester) async {
    await tester.pumpWidget(const KoreaFestivalApp(initialUseNaverMap: false));
    await tester.pumpAndSettle();

    expect(find.text('대한민국 2주 내 축제 지도'), findsOneWidget);
    expect(find.textContaining('조회 기간 (2주):'), findsOneWidget);

    // 2주 이후 시작이거나 이미 종료된 샘플 축제는 리스트에 노출되지 않아야 함
    expect(find.text('서울 윈터 페스타 빛초롱 축제', skipOffstage: false), findsNothing);
    expect(find.text('안성 남사당 바우덕이 축제 (종료)', skipOffstage: false), findsNothing);

    // 서울 칩을 선택하면 서울 지역 축제만 필터링됨
    await tester.tap(find.text('서울 (2)'));
    await tester.pumpAndSettle();

    expect(find.text('서울특별시 2주 이내 축제 (2건)'), findsOneWidget);
    expect(
      find.text('서울 억새축제 & 하늘공원 야간개장', skipOffstage: false),
      findsOneWidget,
    );
  });
}
