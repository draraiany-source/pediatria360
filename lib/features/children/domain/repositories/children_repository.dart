import '../../../../core/utils/result.dart';
import '../../../../shared/domain/entities/child.dart';
import '../../../../shared/domain/entities/growth_record.dart';
import '../../../../shared/domain/entities/vaccine.dart';

/// Contrato de acesso aos dados de crianças, crescimento e vacinas.
///
/// Todas as leituras são streams: a tela se inscreve uma vez e recebe tanto o
/// dado local (imediato) quanto o do servidor (quando chegar). Todas as
/// escritas gravam local primeiro e enfileiram o envio — por isso devolvem
/// sucesso mesmo sem rede.
abstract class ChildrenRepository {
  Stream<List<Child>> watchChildren();

  Stream<Child?> watchChild(String childId);

  Future<Result<Child>> saveChild(Child child);

  Future<Result<void>> deleteChild(String childId);

  /// Envia a foto e devolve a URL pública.
  Future<Result<String>> uploadPhoto({
    required String childId,
    required List<int> bytes,
    required String fileName,
  });

  // ------------------------------------------------------------ Crescimento

  Stream<List<GrowthRecord>> watchGrowth(String childId);

  Future<Result<GrowthRecord>> saveGrowth(GrowthRecord record);

  Future<Result<void>> deleteGrowth({
    required String childId,
    required String recordId,
  });

  // ---------------------------------------------------------------- Vacinas

  Stream<List<VaccineDose>> watchVaccineDoses(String childId);

  Future<Result<VaccineDose>> saveVaccineDose(VaccineDose dose);
}
