import '../../../shared/domain/entities/app_user.dart';
import '../../../shared/domain/entities/clinic_organization.dart';
import '../../../core/config/app_config.dart';
import '../../bi/domain/bi_access.dart';
import '../../billing/domain/billing_access.dart';
import '../../finance/domain/finance_access.dart';
import '../../inventory/domain/inventory_access.dart';
import '../../pending/domain/pending_access.dart';
import '../../pending/domain/pending_item.dart';
import 'security_access.dart';

/// Modulos cobertos pela matriz central (FASE 8).
enum PermissionModule {
  patients,
  chart,
  agenda,
  reception,
  crm,
  pending,
  vaccines,
  telemedicine,
  messages,
  clinicalAi,
  finance,
  billing,
  glosas,
  inventory,
  bi,
  reports,
  documents,
  settings,
  users,
  audit,
}

enum PermissionAction {
  view,
  create,
  edit,
  delete,
  sign,
  export,
  approve,
  cancel,
  refund,
  administer,
}

/// Rotulos de perfil exibidos na UI — aliases documentados, sem novos [ClinicRole].
///
/// - Pediatra / Medico → [ClinicRole.physician]
/// - Neuropediatra → physician + campo specialty (sem poder clinico extra)
/// - Faturamento → finance ([ClinicRole.canAccessBilling])
/// - Estoque manage → [ClinicRole.canManageInventory]
/// - Administrativo → clinicAdmin ou recepcionista limitado
/// - Multidisciplinar → [ClinicRole.healthProfessional]
class PlatformProfileLabel {
  PlatformProfileLabel._();

  static const Map<String, String> aliases = <String, String>{
    'pediatra': 'Medico (physician)',
    'medico': 'Medico (physician)',
    'neuropediatra': 'Medico — Neuropediatria (specialty)',
    'faturamento': 'Financeiro (canAccessBilling)',
    'administrativo': 'Admin clinica ou recepcao limitada',
    'multidisciplinar': 'Profissional de saude (healthProfessional)',
  };

  static String displayForMembership(ClinicMembership? membership) {
    if (membership == null) return '—';
    final String specialty = membership.specialty.trim().toLowerCase();
    if (specialty.contains('neuropediatria')) {
      return aliases['neuropediatra']!;
    }
    return membership.role.label;
  }
}

/// Matriz de permissao — delega aos getters RBAC existentes (FASE 1–7).
///
/// **Isolamento multitenant:** esta camada usa o [ClinicMembership] ativo no
/// app. Regras Firestore de ledgers continuam por `ownerId`; clinicId nos logs
/// e para filtro administrativo, nao abre leitura cross-owner.
class PermissionMatrix {
  PermissionMatrix._();

  static bool allows({
    required AppUser? user,
    required ClinicMembership? membership,
    required PermissionModule module,
    required PermissionAction action,
  }) {
    if (user == null) return false;
    if (user.role.isAdmin) return true;

    final ClinicRole? role =
        membership != null && membership.active ? membership.role : null;

    if (role == ClinicRole.patient) {
      return _patientAllows(module: module, action: action);
    }

    switch (module) {
      case PermissionModule.patients:
        return _patients(role: role, user: user, action: action);
      case PermissionModule.chart:
        return _chart(role: role, user: user, action: action);
      case PermissionModule.agenda:
      case PermissionModule.reception:
        return _agenda(role: role, user: user, action: action);
      case PermissionModule.crm:
        return _crm(role: role, user: user, action: action);
      case PermissionModule.pending:
        return _pending(
          role: role,
          user: user,
          membership: membership,
          action: action,
        );
      case PermissionModule.vaccines:
        return _clinicalOrAgenda(role: role, user: user, action: action);
      case PermissionModule.telemedicine:
        return _agenda(role: role, user: user, action: action);
      case PermissionModule.messages:
        return user.role == UserRole.professional && action == PermissionAction.view;
      case PermissionModule.clinicalAi:
        if (!AppConfig.voiceConsultationEnabled) return false;
        return _chart(role: role, user: user, action: action);
      case PermissionModule.finance:
        return _finance(user: user, membership: membership, action: action);
      case PermissionModule.billing:
        return _billing(user: user, membership: membership, action: action);
      case PermissionModule.glosas:
        return _billing(user: user, membership: membership, action: action) &&
            (action == PermissionAction.view ||
                _billingManage(user: user, membership: membership));
      case PermissionModule.inventory:
        return _inventory(user: user, membership: membership, action: action);
      case PermissionModule.bi:
        return _bi(user: user, membership: membership, action: action);
      case PermissionModule.reports:
        return _reports(user: user, membership: membership, action: action);
      case PermissionModule.documents:
        return _chart(role: role, user: user, action: action) ||
            role == ClinicRole.clinicAdmin;
      case PermissionModule.settings:
        return role == ClinicRole.clinicAdmin ||
            user.role == UserRole.professional;
      case PermissionModule.users:
        return role?.canManageStaff == true || user.role.isAdmin;
      case PermissionModule.audit:
        return _audit(user: user, membership: membership, action: action);
    }
  }

  static bool _patientAllows({
    required PermissionModule module,
    required PermissionAction action,
  }) =>
      module == PermissionModule.messages &&
      action == PermissionAction.view;

  static bool _patients({
    required ClinicRole? role,
    required AppUser user,
    required PermissionAction action,
  }) {
    if (role != null) {
      if (action == PermissionAction.view) {
        return role.canManageAgenda || role.canAccessClinicalChart;
      }
      if (action == PermissionAction.create || action == PermissionAction.edit) {
        // Recepcao: cadastro administrativo; evolucao clinica continua em [chart].
        return role.canAccessClinicalChart || role == ClinicRole.receptionist;
      }
      return role.canManageStaff;
    }
    return user.role == UserRole.professional;
  }

  static bool _chart({
    required ClinicRole? role,
    required AppUser user,
    required PermissionAction action,
  }) {
    final bool clinical = role?.canAccessClinicalChart == true ||
        (role == null && user.role == UserRole.professional);
    return switch (action) {
      PermissionAction.view ||
      PermissionAction.create ||
      PermissionAction.edit ||
      PermissionAction.sign =>
        clinical,
      PermissionAction.delete => role?.canManageStaff == true,
      PermissionAction.export => clinical || role == ClinicRole.clinicAdmin,
      _ => false,
    };
  }

  static bool _agenda({
    required ClinicRole? role,
    required AppUser user,
    required PermissionAction action,
  }) {
    final bool ok = role?.canManageAgenda == true ||
        (role == null && user.role == UserRole.professional);
    return ok &&
        (action == PermissionAction.view ||
            action == PermissionAction.create ||
            action == PermissionAction.edit ||
            action == PermissionAction.cancel);
  }

  static bool _crm({
    required ClinicRole? role,
    required AppUser user,
    required PermissionAction action,
  }) {
    final bool ok = role?.canManageAgenda == true ||
        role?.canAccessClinicalChart == true ||
        (role == null && user.role == UserRole.professional);
    return ok && action != PermissionAction.refund;
  }

  static bool _clinicalOrAgenda({
    required ClinicRole? role,
    required AppUser user,
    required PermissionAction action,
  }) =>
      _chart(role: role, user: user, action: action) ||
      _agenda(role: role, user: user, action: action);

  static bool _pending({
    required ClinicRole? role,
    required AppUser user,
    required ClinicMembership? membership,
    required PermissionAction action,
  }) {
    if (action == PermissionAction.view) {
      return PendingAccess.canViewCategory(
            user: user,
            clinicMembership: membership,
            category: PendingCategory.clinical,
          ) ||
          PendingAccess.canViewCategory(
            user: user,
            clinicMembership: membership,
            category: PendingCategory.financial,
          );
    }
    return PendingAccess.canViewCategory(
      user: user,
      clinicMembership: membership,
      category: PendingCategory.administrative,
    );
  }

  static bool _finance({
    required AppUser user,
    required ClinicMembership? membership,
    required PermissionAction action,
  }) {
    if (!FinanceAccess.canAccessModule(
      user: user,
      clinicMembership: membership,
    )) {
      return false;
    }
    return switch (action) {
      PermissionAction.view => FinanceAccess.canViewDashboard(
          user: user,
          clinicMembership: membership,
        ),
      PermissionAction.create ||
      PermissionAction.edit ||
      PermissionAction.approve =>
        FinanceAccess.canManageLedger(
          user: user,
          clinicMembership: membership,
        ),
      PermissionAction.refund ||
      PermissionAction.cancel =>
        FinanceAccess.canManageLedger(
          user: user,
          clinicMembership: membership,
        ),
      PermissionAction.export => FinanceAccess.canManageLedger(
          user: user,
          clinicMembership: membership,
        ),
      _ => false,
    };
  }

  static bool _billingManage({
    required AppUser user,
    required ClinicMembership? membership,
  }) =>
      BillingAccess.canManagePlans(
        user: user,
        clinicMembership: membership,
      );

  static bool _billing({
    required AppUser user,
    required ClinicMembership? membership,
    required PermissionAction action,
  }) {
    if (!BillingAccess.canAccessModule(
      user: user,
      clinicMembership: membership,
    )) {
      return false;
    }
    return switch (action) {
      PermissionAction.view => true,
      PermissionAction.create ||
      PermissionAction.edit ||
      PermissionAction.approve ||
      PermissionAction.cancel =>
        _billingManage(user: user, membership: membership),
      PermissionAction.export => _billingManage(user: user, membership: membership),
      _ => false,
    };
  }

  static bool _inventory({
    required AppUser user,
    required ClinicMembership? membership,
    required PermissionAction action,
  }) {
    if (!InventoryAccess.canAccessModule(
      user: user,
      clinicMembership: membership,
    )) {
      return false;
    }
    return switch (action) {
      PermissionAction.view => InventoryAccess.canView(
          user: user,
          clinicMembership: membership,
        ),
      PermissionAction.create ||
      PermissionAction.edit =>
        InventoryAccess.canStockOps(
              user: user,
              clinicMembership: membership,
            ) ||
            InventoryAccess.canManagePurchases(
              user: user,
              clinicMembership: membership,
            ),
      PermissionAction.delete ||
      PermissionAction.approve =>
        InventoryAccess.canManagePurchases(
          user: user,
          clinicMembership: membership,
        ),
      PermissionAction.export => InventoryAccess.canViewCosts(
          user: user,
          clinicMembership: membership,
        ),
      _ => false,
    };
  }

  static bool _bi({
    required AppUser user,
    required ClinicMembership? membership,
    required PermissionAction action,
  }) {
    if (!BiAccess.canAccessModule(
      user: user,
      clinicMembership: membership,
    )) {
      return false;
    }
    if (action == PermissionAction.export) {
      return BiAccess.canExport(
        user: user,
        clinicMembership: membership,
      );
    }
    return action == PermissionAction.view;
  }

  static bool _reports({
    required AppUser user,
    required ClinicMembership? membership,
    required PermissionAction action,
  }) =>
      _finance(user: user, membership: membership, action: action) ||
      _billing(user: user, membership: membership, action: action) ||
      _bi(user: user, membership: membership, action: action);

  static bool _audit({
    required AppUser user,
    required ClinicMembership? membership,
    required PermissionAction action,
  }) {
    if (action == PermissionAction.export) {
      return SecurityAccess.canExportAuditLogs(
        user: user,
        clinicMembership: membership,
      );
    }
    if (action == PermissionAction.view || action == PermissionAction.administer) {
      return SecurityAccess.canAdministerAudit(
        user: user,
        clinicMembership: membership,
      );
    }
    return SecurityAccess.canAppendOwnAuditEvent(user: user);
  }
}
