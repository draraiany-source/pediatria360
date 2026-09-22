import 'billing_models.dart';

enum BillingValidationCode {
  missingPlan,
  cardExpired,
  missingAuth,
  emptyProcedure,
  missingAmount,
  missingProfessional,
}

class BillingValidationIssue {
  const BillingValidationIssue({
    required this.code,
    required this.message,
    this.guideId,
  });

  final BillingValidationCode code;
  final String message;
  final String? guideId;
}

/// Valida guia antes de incluir em lote.
List<BillingValidationIssue> validateGuideForBatch({
  required BillingGuide guide,
  required DateTime now,
  PatientInsurance? patientInsurance,
  InsuranceAuthorization? authorization,
  bool requiresAuth = true,
}) {
  final List<BillingValidationIssue> issues = <BillingValidationIssue>[];

  if (guide.planId == null || guide.planId!.isEmpty) {
    issues.add(
      BillingValidationIssue(
        code: BillingValidationCode.missingPlan,
        message: 'Plano/operadora nao informado na guia.',
        guideId: guide.id,
      ),
    );
  }

  if (patientInsurance != null &&
      !patientInsurance.isCardValid(now) &&
      patientInsurance.coverageType != CoverageType.private_) {
    issues.add(
      BillingValidationIssue(
        code: BillingValidationCode.cardExpired,
        message: 'Carteirinha vencida ou invalida.',
        guideId: guide.id,
      ),
    );
  }

  if (requiresAuth && guide.type != BillingGuideType.consultation) {
    if (guide.authorizationId == null || guide.authorizationId!.isEmpty) {
      issues.add(
        BillingValidationIssue(
          code: BillingValidationCode.missingAuth,
          message: 'Autorizacao obrigatoria para este procedimento.',
          guideId: guide.id,
        ),
      );
    } else if (authorization == null || !authorization.isActiveAuth(now)) {
      issues.add(
        BillingValidationIssue(
          code: BillingValidationCode.missingAuth,
          message: 'Autorizacao ausente, negada ou expirada.',
          guideId: guide.id,
        ),
      );
    }
  }

  if (guide.procedureCode.isEmpty && guide.procedureName.isEmpty) {
    issues.add(
      BillingValidationIssue(
        code: BillingValidationCode.emptyProcedure,
        message: 'Procedimento nao informado.',
        guideId: guide.id,
      ),
    );
  }

  if (guide.amountCents <= 0) {
    issues.add(
      BillingValidationIssue(
        code: BillingValidationCode.missingAmount,
        message: 'Valor da guia invalido.',
        guideId: guide.id,
      ),
    );
  }

  if (guide.professionalId == null || guide.professionalId!.isEmpty) {
    issues.add(
      BillingValidationIssue(
        code: BillingValidationCode.missingProfessional,
        message: 'Profissional executante obrigatorio.',
        guideId: guide.id,
      ),
    );
  }

  return issues;
}
