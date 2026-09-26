import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pediatria360/core/config/app_assets.dart';
import 'package:pediatria360/core/config/capi_pose.dart';
import 'package:pediatria360/core/widgets/capi_illustration.dart';
import 'package:pediatria360/core/widgets/child_avatar.dart';
import 'package:pediatria360/core/widgets/state_views.dart';

/// Renders Capi / avatar / empty-state widgets for docs/screenshots evidence.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpFrame(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4C9BFF)),
        ),
        home: Scaffold(
          body: Center(child: child),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('golden: Capi welcome illustration', (WidgetTester tester) async {
    await pumpFrame(
      tester,
      const CapiIllustration(pose: CapiPose.boasVindas, size: 180),
    );
    await expectLater(
      find.byType(CapiIllustration),
      matchesGoldenFile('../docs/screenshots/capi_welcome.png'),
    );
  });

  testWidgets('golden: child avatar picker', (WidgetTester tester) async {
    await pumpFrame(
      tester,
      SizedBox(
        width: 420,
        child: ChildAvatarPicker(
          selectedPhotoUrl: ChildAvatarRef.encode(AppAssets.avatarMeninaCoral),
          onSelected: (_) {},
        ),
      ),
    );
    await expectLater(
      find.byType(ChildAvatarPicker),
      matchesGoldenFile('../docs/screenshots/child_avatar_picker.png'),
    );
  });

  testWidgets('golden: empty state with Capi', (WidgetTester tester) async {
    await pumpFrame(
      tester,
      SizedBox(
        width: 360,
        child: EmptyState(
          icon: Icons.menu_book_outlined,
          illustration: AppAssets.capiForPose(CapiPose.boasVindas),
          title: 'Biblioteca vazia',
          message: 'Conteudos aparecem aqui quando estiverem disponiveis.',
          actionLabel: 'Explorar',
          onAction: () {},
        ),
      ),
    );
    await expectLater(
      find.byType(EmptyState),
      matchesGoldenFile('../docs/screenshots/empty_state_capi.png'),
    );
  });
}