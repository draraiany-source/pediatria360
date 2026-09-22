import 'package:flutter_test/flutter_test.dart';

import 'package:pediatria360/features/billing/domain/billing_models.dart';

import 'package:pediatria360/features/billing/domain/billing_validation.dart';



void main() {

  final DateTime now = DateTime(2026, 3, 1);



  BillingGuide baseGuide() => BillingGuide(

        id: 'g1',

        ownerId: 'o1',

        type: BillingGuideType.procedure,

        childId: 'c1',

        serviceDate: now,

        amountCents: 10000,

        planId: 'plan1',

        professionalId: 'prof1',

        procedureCode: '10101012',

        procedureName: 'Consulta',

        authorizationId: 'a1',

      );



  test('valid guide has no issues', () {

    final List<BillingValidationIssue> issues = validateGuideForBatch(

      guide: baseGuide(),

      now: now,

      patientInsurance: PatientInsurance(

        id: 'pi1',

        ownerId: 'o1',

        childId: 'c1',

        coverageType: CoverageType.insurance,

        validUntil: now.add(const Duration(days: 30)),

      ),

      authorization: InsuranceAuthorization(

        id: 'a1',

        ownerId: 'o1',

        childId: 'c1',

        requestedAt: now,

        status: AuthorizationStatus.authorized,

        validUntil: now.add(const Duration(days: 10)),

      ),

      requiresAuth: true,

    );

    expect(issues, isEmpty);

  });



  test('missing plan flagged', () {

    final BillingGuide g = BillingGuide(

      id: 'g2',

      ownerId: 'o1',

      type: BillingGuideType.consultation,

      childId: 'c1',

      serviceDate: now,

      amountCents: 5000,

      professionalId: 'p1',

      procedureName: 'Consulta',

    );

    expect(

      validateGuideForBatch(guide: g, now: now).first.code,

      BillingValidationCode.missingPlan,

    );

  });

}

