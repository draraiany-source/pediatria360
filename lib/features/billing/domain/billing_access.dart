import '../../../shared/domain/entities/app_user.dart';

import '../../../shared/domain/entities/clinic_organization.dart';

import 'billing_models.dart';



enum BillingAccessLevel {

  none,

  receptionBasic,

  physicianView,

  full,

}



class BillingAccess {

  BillingAccess._();



  static BillingAccessLevel level({

    required AppUser? user,

    required ClinicMembership? clinicMembership,

  }) {

    if (user == null) return BillingAccessLevel.none;

    if (user.role.isAdmin) return BillingAccessLevel.full;



    if (clinicMembership != null && clinicMembership.active) {

      final ClinicRole role = clinicMembership.role;

      if (role.canAccessBilling) return BillingAccessLevel.full;

      if (role == ClinicRole.physician ||

          role == ClinicRole.healthProfessional) {

        return BillingAccessLevel.physicianView;

      }

      if (role.canManageAgenda) return BillingAccessLevel.receptionBasic;

    }



    if (user.role == UserRole.professional) {

      return BillingAccessLevel.full;

    }



    return BillingAccessLevel.none;

  }



  static bool canAccessModule({

    required AppUser? user,

    required ClinicMembership? clinicMembership,

  }) =>

      level(user: user, clinicMembership: clinicMembership) !=

      BillingAccessLevel.none;



  static bool canManagePlans({

    required AppUser? user,

    required ClinicMembership? clinicMembership,

  }) {

    final BillingAccessLevel l =

        level(user: user, clinicMembership: clinicMembership);

    return l == BillingAccessLevel.full;

  }



  static bool canManageBatches({

    required AppUser? user,

    required ClinicMembership? clinicMembership,

  }) =>

      canManagePlans(user: user, clinicMembership: clinicMembership);



  static bool canViewAuthorization({

    required AppUser? user,

    required ClinicMembership? clinicMembership,

    required InsuranceAuthorization auth,

  }) {

    final BillingAccessLevel l =

        level(user: user, clinicMembership: clinicMembership);

    if (l == BillingAccessLevel.full ||

        l == BillingAccessLevel.receptionBasic) {

      return true;

    }

    if (l == BillingAccessLevel.physicianView) {

      return auth.professionalId == user?.uid;

    }

    return false;

  }



  static bool canViewPatientBilling({

    required AppUser? user,

    required ClinicMembership? clinicMembership,

  }) {

    final BillingAccessLevel l =

        level(user: user, clinicMembership: clinicMembership);

    return l != BillingAccessLevel.none;

  }

}

