import 'package:flutter_test/flutter_test.dart';
import 'package:pediatria360/features/clinic/domain/clinic_workflow.dart';

void main() {
  test('resolve prefere workflowStatus ao status legado', () {
    expect(
      ClinicWorkflowStatus.resolve(
        workflowStatus: 'arrived',
        appointmentStatus: 'confirmed',
      ),
      ClinicWorkflowStatus.arrived,
    );
  });

  test('resolve cai no status legado sem workflow', () {
    expect(
      ClinicWorkflowStatus.resolve(
        workflowStatus: null,
        appointmentStatus: 'inProgress',
      ),
      ClinicWorkflowStatus.inService,
    );
  });

  test('called esta na coluna de recepcao', () {
    expect(ClinicWorkflowStatus.called.isReceptionColumn, isTrue);
    expect(ClinicWorkflowStatus.called.label, 'Chamado');
  });
}
