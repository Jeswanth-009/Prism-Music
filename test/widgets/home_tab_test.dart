import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/core/di/injection.dart';
import 'package:prism_music/presentation/pages/home_tab.dart';

import '../helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await getIt.reset();
    initTestHive('home');
  });

  tearDown(() async {
    await getIt.reset();
  });

  testWidgets('renders greeting and content rails with stubbed loaders',
      (tester) async {
    final musicRepo = FakeMusicRepository()
      ..trendingResult = Right([song('tr1', 'Trending Hit')])
      ..newReleasesResult = const Right([]);
    registerTestGetIt(
      musicRepository: musicRepo,
      recommendationService: FakeRecommendationService(),
    );

    await pumpTestWidget(
      tester,
      const HomeTab(),
      size: const Size(400, 1800),
    );
    // Several loader futures settle across frames — pump until content
    // replaces the skeletons.
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // Header + section scaffolding render.
    expect(find.text('Trending now'), findsOneWidget);
  });

}
