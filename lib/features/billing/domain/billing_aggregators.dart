import 'billing_models.dart';

class BillingDashboardKpisComputer {
  BillingDashboardKpisComputer._();

  static BillingDashboardKpis compute({
    required DateTime now,
    required List<BillingGuide> guides,
    required List<BillingBatch> batches,
    required List<BillingGlosa> glosas,
    required Map<String, String> planLabels,
  }) {
    final DateTime monthStart = DateTime(now.year, now.month);
    final DateTime monthEnd = DateTime(now.year, now.month + 1);

    int billedMonth = 0;
    for (final BillingGuide g in guides) {
      if (!g.serviceDate.isBefore(monthStart) &&
          g.serviceDate.isBefore(monthEnd) &&
          g.status != BillingGuideStatus.cancelled) {
        billedMonth += g.amountCents;
      }
    }

    int received = 0;
    int pending = 0;
    final List<double> daysToReceive = <double>[];

    for (final BillingBatch b in batches) {
      if (b.status == BillingBatchStatus.paid ||
          b.status == BillingBatchStatus.withGlosa) {
        received += b.totalCents;
        if (b.sentAt != null && b.returnAt != null) {
          daysToReceive.add(
            b.returnAt!.difference(b.sentAt!).inHours / 24.0,
          );
        }
      } else if (b.status == BillingBatchStatus.sent ||
          b.status == BillingBatchStatus.processing ||
          b.status == BillingBatchStatus.closed) {
        pending += b.totalCents;
      }
    }

    int glosed = 0;
    for (final BillingGlosa gl in glosas) {
      if (gl.status != BillingGlosaStatus.accepted &&
          gl.status != BillingGlosaStatus.resolved) {
        glosed += gl.glosedCents;
      }
    }

    final double glosaRate =
        billedMonth > 0 ? glosed / billedMonth : 0.0;

    final double avgDays = daysToReceive.isEmpty
        ? 0.0
        : daysToReceive.reduce((double a, double b) => a + b) /
            daysToReceive.length;

    final String? topRevenue = _topPlanByAmount(
      guides,
      planLabels,
      onlyPaid: true,
    );
    final String? topGlosa = _topPlanByGlosa(glosas, planLabels);

    return BillingDashboardKpis(
      billedMonth: billedMonth,
      received: received,
      pending: pending,
      glosed: glosed,
      glosaRate: glosaRate,
      avgDaysToReceive: avgDays,
      topRevenuePlan: topRevenue,
      topGlosaPlan: topGlosa,
    );
  }

  static String? _topPlanByAmount(
    List<BillingGuide> guides,
    Map<String, String> planLabels, {
    required bool onlyPaid,
  }) {
    final Map<String, int> totals = <String, int>{};
    for (final BillingGuide g in guides) {
      if (onlyPaid && g.status != BillingGuideStatus.paid) continue;
      if (g.planId == null) continue;
      totals[g.planId!] = (totals[g.planId!] ?? 0) + g.amountCents;
    }
    return _maxKey(totals, planLabels);
  }

  static String? _topPlanByGlosa(
    List<BillingGlosa> glosas,
    Map<String, String> planLabels,
  ) {
    final Map<String, int> totals = <String, int>{};
    for (final BillingGlosa g in glosas) {
      if (g.planId == null) continue;
      totals[g.planId!] = (totals[g.planId!] ?? 0) + g.glosedCents;
    }
    return _maxKey(totals, planLabels);
  }

  static String? _maxKey(Map<String, int> totals, Map<String, String> labels) {
    if (totals.isEmpty) return null;
    String? bestId;
    int best = 0;
    totals.forEach((String id, int v) {
      if (v > best) {
        best = v;
        bestId = id;
      }
    });
    if (bestId == null) return null;
    return labels[bestId] ?? bestId;
  }
}

class BillingCsvExport {
  BillingCsvExport._();

  static String guidesCsv(List<BillingGuide> guides) {
    final StringBuffer sb = StringBuffer()
      ..writeln(
        'id,tipo,paciente,plano,procedimento,valor_centavos,status,data',
      );
    for (final BillingGuide g in guides) {
      sb.writeln(
        '${g.id},${g.type.name},${g.childId},${g.planId ?? ''},'
        '${g.procedureName.replaceAll(',', ';')},${g.amountCents},'
        '${g.status.name},${g.serviceDate.toIso8601String()}',
      );
    }
    return sb.toString();
  }

  static String glosasCsv(List<BillingGlosa> glosas) {
    final StringBuffer sb = StringBuffer()
      ..writeln('id,guia,valor_glosado,motivo,status,prazo_recurso');
    for (final BillingGlosa g in glosas) {
      sb.writeln(
        '${g.id},${g.guideId ?? ''},${g.glosedCents},'
        '${g.reason.replaceAll(',', ';')},${g.status.firestoreName},'
        '${g.appealDeadline?.toIso8601String() ?? ''}',
      );
    }
    return sb.toString();
  }

  static String batchesCsv(List<BillingBatch> batches) {
    final StringBuffer sb = StringBuffer()
      ..writeln('id,guias,total_centavos,status,protocolo,enviado_em');
    for (final BillingBatch b in batches) {
      sb.writeln(
        '${b.id},${b.guideCount},${b.totalCents},${b.status.name},'
        '${b.protocol.replaceAll(',', ';')},'
        '${b.sentAt?.toIso8601String() ?? ''}',
      );
    }
    return sb.toString();
  }
}

/// Id estavel de recebivel por guia (evita duplicata no financeiro).
String billingReceivableIdForGuide(String guideId) => 'guia_$guideId';
