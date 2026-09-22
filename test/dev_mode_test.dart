import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pediatria360/core/config/dev_mode.dart';
import 'package:pediatria360/core/router/route_authorization.dart';
import 'package:pediatria360/core/router/routes.dart';
import 'package:pediatria360/shared/domain/entities/app_user.dart';

void main() {
  test('DevMode user is professional-ready and fully onboarded', () {
    final AppUser u = DevMode.user;
    expect(u.uid, DevMode.userId);
    expect(u.role, UserRole.professional);
    expect(u.onboardingDone, isTrue);
    expect(u.professionalVerified, isTrue);
    expect(u.canPrescribe, isTrue);
    expect(u.email, contains('@pediatria360.local'));
  });

  test('com unlockAllRoles, splash e login vão para home', () {
    expect(
      resolveRouteRedirect(
        maintenanceMode: false,
        location: Routes.splashPath,
        authLoading: false,
        onboardingLoading: false,
        user: DevMode.user,
        seenOnboarding: true,
        unlockAllRoles: true,
      ),
      Routes.homePath,
    );
    expect(
      resolveRouteRedirect(
        maintenanceMode: false,
        location: Routes.loginPath,
        authLoading: false,
        onboardingLoading: false,
        user: DevMode.user,
        seenOnboarding: true,
        unlockAllRoles: true,
      ),
      Routes.homePath,
    );
  });

  test('com unlockAllRoles, profissional acessa prontuário e admin', () {
    expect(
      resolveRouteRedirect(
        maintenanceMode: false,
        location: Routes.patientsPath,
        authLoading: false,
        onboardingLoading: false,
        user: DevMode.user,
        seenOnboarding: true,
        unlockAllRoles: true,
      ),
      isNull,
    );
    expect(
      resolveRouteRedirect(
        maintenanceMode: false,
        location: Routes.adminPath,
        authLoading: false,
        onboardingLoading: false,
        user: DevMode.user,
        seenOnboarding: true,
        unlockAllRoles: true,
      ),
      isNull,
    );
  });

  test('sem unlockAllRoles, profissional acessa prontuário', () {
    expect(
      resolveRouteRedirect(
        maintenanceMode: false,
        location: Routes.patientsPath,
        authLoading: false,
        onboardingLoading: false,
        user: DevMode.user,
        seenOnboarding: true,
      ),
      isNull,
    );
  });

  test('sem unlockAllRoles, profissional NÃO acessa admin', () {
    expect(
      resolveRouteRedirect(
        maintenanceMode: false,
        location: Routes.adminPath,
        authLoading: false,
        onboardingLoading: false,
        user: DevMode.user,
        seenOnboarding: true,
      ),
      Routes.homePath,
    );
  });

  test('DevMode.isEnabled segue kDebugMode quando SKIP_AUTH off', () {
    expect(DevMode.isEnabled, kDebugMode);
  });
}
