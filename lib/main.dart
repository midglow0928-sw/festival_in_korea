import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

import 'screens/home_screen.dart';

const String kNaverMapClientId = 'bn5o7l3zg1';

class NaverMapAuthState {
  const NaverMapAuthState({
    this.errorMessage,
    this.revision = 0,
  });

  final String? errorMessage;
  final int revision;
}

final ValueNotifier<NaverMapAuthState> naverMapAuthStateNotifier =
    ValueNotifier<NaverMapAuthState>(const NaverMapAuthState());

bool _usingLegacyClient = false;

Future<void> initNaverMapSdk({bool forceLegacy = false}) async {
  naverMapAuthStateNotifier.value = NaverMapAuthState(
    errorMessage: null,
    revision: naverMapAuthStateNotifier.value.revision + 1,
  );

  if (forceLegacy || _usingLegacyClient) {
    _usingLegacyClient = true;
    try {
      // ignore: deprecated_member_use
      await NaverMapSdk.instance.initialize(
        clientId: kNaverMapClientId,
        onAuthFailed: (legacyEx) {
          debugPrint('NaverMap Legacy Auth Failed: $legacyEx');
          naverMapAuthStateNotifier.value = NaverMapAuthState(
            errorMessage:
                '네이버 지도 인증 대기/실패 ($legacyEx)\n'
                'NCP 콘솔 설정 변경 후 반영까지 1~2분 소요될 수 있습니다.',
            revision: naverMapAuthStateNotifier.value.revision,
          );
        },
      );
      return;
    } catch (e) {
      debugPrint('Legacy init failed: $e');
    }
  }

  try {
    await FlutterNaverMap().init(
      clientId: kNaverMapClientId,
      onAuthFailed: (ex) async {
        debugPrint('NaverMap NCP Auth Failed: $ex');
        if (!_usingLegacyClient) {
          debugPrint('Retrying with NaverMapSdk legacy client...');
          await initNaverMapSdk(forceLegacy: true);
          return;
        }
        naverMapAuthStateNotifier.value = NaverMapAuthState(
          errorMessage:
              '네이버 지도 인증 대기/실패 ($ex)\n'
              'NCP 콘솔 설정 변경 후 반영까지 1~2분 소요될 수 있습니다.',
          revision: naverMapAuthStateNotifier.value.revision,
        );
      },
    );
  } catch (e) {
    debugPrint('FlutterNaverMap init skipped or failed: $e');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initNaverMapSdk();
  runApp(const KoreaFestivalApp());
}

class KoreaFestivalApp extends StatelessWidget {
  const KoreaFestivalApp({
    super.key,
    this.initialUseNaverMap = true,
  });

  final bool initialUseNaverMap;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '대한민국 축제 지도',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0284C7),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      ),
      home: ValueListenableBuilder<NaverMapAuthState>(
        valueListenable: naverMapAuthStateNotifier,
        builder: (context, authState, _) {
          return HomeScreen(
            initialUseNaverMap: initialUseNaverMap,
            naverAuthErrorMessage: authState.errorMessage,
            naverMapRevision: authState.revision,
            onRetryNaverAuth: () async {
              _usingLegacyClient = false;
              await initNaverMapSdk();
            },
          );
        },
      ),
    );
  }
}
