/// Catalogo estrutural de suplementacao. Sem doses/protocolos numericos.
/// Textos clinicos ficam como placeholder ate validacao medica / CMS.
library;

const String kSupplementContentPending =
    'Conteudo pendente de validacao medica.';

const String kSupplementClinicalDisclaimer =
    'Ferramenta de apoio a decisao clinica. A interpretacao e a conduta '
    'final sao de responsabilidade do profissional assistente.';

class MicronutrientSection {
  const MicronutrientSection({required this.id, required this.title, this.body = kSupplementContentPending});
  final String id;
  final String title;
  final String body;
}

class MicronutrientProfile {
  const MicronutrientProfile({required this.id, required this.name, required this.shortCode, required this.sections, this.relatedExamIds = const <String>[], this.favoriteDefault = false});
  final String id;
  final String name;
  final String shortCode;
  final List<MicronutrientSection> sections;
  final List<String> relatedExamIds;
  final bool favoriteDefault;
}

class LabExamDefinition {
  const LabExamDefinition({required this.id, required this.name, this.defaultUnit = '', this.relatedMicronutrientIds = const <String>[]});
  final String id;
  final String name;
  final String defaultUnit;
  final List<String> relatedMicronutrientIds;
}

class SupplementProtocolCard {
  const SupplementProtocolCard({required this.id, required this.title, this.nutrientsToConsider = const <String>[], this.summary = kSupplementContentPending});
  final String id;
  final String title;
  final List<String> nutrientsToConsider;
  final String summary;
}

class FoodSourceCard {
  const FoodSourceCard({required this.id, required this.foodName, required this.nutrientId, this.portion = kSupplementContentPending, this.notes = kSupplementContentPending, this.group = 'Geral', this.tags = const <String>[]});
  final String id;
  final String foodName;
  final String nutrientId;
  final String portion;
  final String notes;
  final String group;
  final List<String> tags;
}

const List<MicronutrientSection> _defaultSections = <MicronutrientSection>[
  MicronutrientSection(id: 'overview', title: 'Visao geral'),
  MicronutrientSection(id: 'functions', title: 'Principais funcoes'),
  MicronutrientSection(id: 'investigate', title: 'Quando investigar'),
  MicronutrientSection(id: 'risk', title: 'Grupos de risco'),
  MicronutrientSection(id: 'deficiency', title: 'Sinais de deficiencia'),
  MicronutrientSection(id: 'excess', title: 'Sinais de excesso/toxicidade'),
  MicronutrientSection(id: 'labs', title: 'Exames associados'),
  MicronutrientSection(id: 'foods', title: 'Fontes alimentares'),
  MicronutrientSection(id: 'forms', title: 'Formas disponiveis'),
  MicronutrientSection(id: 'prevention', title: 'Prevencao'),
  MicronutrientSection(id: 'treatment', title: 'Tratamento'),
  MicronutrientSection(id: 'monitoring', title: 'Monitorizacao'),
  MicronutrientSection(id: 'followup', title: 'Tempo de acompanhamento'),
  MicronutrientSection(id: 'interactions', title: 'Interacoes importantes'),
  MicronutrientSection(id: 'alerts', title: 'Alertas'),
  MicronutrientSection(id: 'references', title: 'Referencias'),
];

const List<MicronutrientProfile> kMicronutrientCatalog = <MicronutrientProfile>[
  MicronutrientProfile(id: 'iron', name: 'Ferro', shortCode: 'Fe', sections: _defaultSections),
  MicronutrientProfile(id: 'b12', name: 'Vitamina B12', shortCode: 'B12', sections: _defaultSections),
  MicronutrientProfile(id: 'folate', name: 'Acido folico / B9', shortCode: 'B9', sections: _defaultSections),
  MicronutrientProfile(id: 'zinc', name: 'Zinco', shortCode: 'Zn', sections: _defaultSections),
  MicronutrientProfile(id: 'b6', name: 'Vitamina B6', shortCode: 'B6', sections: _defaultSections),
  MicronutrientProfile(id: 'vit_a', name: 'Vitamina A', shortCode: 'A', sections: _defaultSections),
  MicronutrientProfile(id: 'vit_d', name: 'Vitamina D', shortCode: 'D', sections: _defaultSections),
  MicronutrientProfile(id: 'vit_e', name: 'Vitamina E', shortCode: 'E', sections: _defaultSections),
  MicronutrientProfile(id: 'vit_k', name: 'Vitamina K', shortCode: 'K', sections: _defaultSections),
  MicronutrientProfile(id: 'vit_c', name: 'Vitamina C', shortCode: 'C', sections: _defaultSections),
  MicronutrientProfile(id: 'magnesium', name: 'Magnesio', shortCode: 'Mg', sections: _defaultSections),
  MicronutrientProfile(id: 'omega3', name: 'Omega 3', shortCode: 'n-3', sections: _defaultSections),
  MicronutrientProfile(id: 'calcium', name: 'Calcio', shortCode: 'Ca', sections: _defaultSections),
  MicronutrientProfile(id: 'complex_b', name: 'Complexo B', shortCode: 'B', sections: _defaultSections),
  MicronutrientProfile(id: 'selenium', name: 'Selenio', shortCode: 'Se', sections: _defaultSections),
  MicronutrientProfile(id: 'copper', name: 'Cobre', shortCode: 'Cu', sections: _defaultSections),
];

const List<LabExamDefinition> kLabExamCatalog = <LabExamDefinition>[
  LabExamDefinition(id: 'cbc', name: 'Hemograma'),
  LabExamDefinition(id: 'hb', name: 'Hemoglobina'),
  LabExamDefinition(id: 'ht', name: 'Hematocrito'),
  LabExamDefinition(id: 'mcv', name: 'VCM'),
  LabExamDefinition(id: 'mch', name: 'HCM'),
  LabExamDefinition(id: 'mchc', name: 'CHCM'),
  LabExamDefinition(id: 'rdw', name: 'RDW'),
  LabExamDefinition(id: 'wbc', name: 'Leucograma'),
  LabExamDefinition(id: 'plt', name: 'Plaquetas'),
  LabExamDefinition(id: 'ferritin', name: 'Ferritina'),
  LabExamDefinition(id: 'serum_iron', name: 'Ferro serico'),
  LabExamDefinition(id: 'b12', name: 'B12'),
  LabExamDefinition(id: 'folate', name: 'Folato'),
  LabExamDefinition(id: 'mma', name: 'Acido metilmalonico'),
  LabExamDefinition(id: 'hcy', name: 'Homocisteina'),
  LabExamDefinition(id: 'zinc', name: 'Zinco'),
  LabExamDefinition(id: 'vit_a', name: 'Vitamina A'),
  LabExamDefinition(id: 'vit_d_25oh', name: '25-OH Vitamina D'),
  LabExamDefinition(id: 'vit_e', name: 'Vitamina E'),
  LabExamDefinition(id: 'vit_k', name: 'Vitamina K'),
  LabExamDefinition(id: 'vit_c', name: 'Vitamina C'),
  LabExamDefinition(id: 'magnesium', name: 'Magnesio'),
  LabExamDefinition(id: 'calcium', name: 'Calcio'),
  LabExamDefinition(id: 'selenium', name: 'Selenio'),
  LabExamDefinition(id: 'copper', name: 'Cobre'),
  LabExamDefinition(id: 'tsh', name: 'TSH'),
  LabExamDefinition(id: 'ft4', name: 'T4 livre'),
];

const List<SupplementProtocolCard> kSupplementProtocols = <SupplementProtocolCard>[
  SupplementProtocolCard(id: 'nb', title: 'Recem-nascido'),
  SupplementProtocolCard(id: 'preterm', title: 'Prematuro'),
  SupplementProtocolCard(id: 'infant', title: 'Lactente'),
  SupplementProtocolCard(id: 'child', title: 'Crianca'),
  SupplementProtocolCard(id: 'teen', title: 'Adolescente'),
  SupplementProtocolCard(id: 'anemia', title: 'Anemia'),
  SupplementProtocolCard(id: 'selective', title: 'Seletividade alimentar'),
  SupplementProtocolCard(id: 'faltering', title: 'Baixo ganho ponderal'),
  SupplementProtocolCard(id: 'restrictive', title: 'Dietas restritivas'),
  SupplementProtocolCard(id: 'vegan', title: 'Vegetarianismo/veganismo'),
  SupplementProtocolCard(id: 'malabsorb', title: 'Ma absorcao'),
  SupplementProtocolCard(id: 'diarrhea', title: 'Diarreia cronica'),
  SupplementProtocolCard(id: 'sun', title: 'Baixa exposicao solar'),
  SupplementProtocolCard(id: 'obesity', title: 'Obesidade'),
  SupplementProtocolCard(id: 'asd', title: 'TEA'),
  SupplementProtocolCard(id: 'adhd', title: 'TDAH'),
  SupplementProtocolCard(id: 'chronic', title: 'Doencas cronicas'),
];

const List<FoodSourceCard> kFoodSourceCatalog = <FoodSourceCard>[
  FoodSourceCard(id: 'f_iron_1', foodName: 'Alimentos fonte de ferro (revisao medica)', nutrientId: 'iron', tags: <String>['geral']),
  FoodSourceCard(id: 'f_b12_1', foodName: 'Alimentos fonte de B12 (revisao medica)', nutrientId: 'b12', tags: <String>['geral']),
  FoodSourceCard(id: 'f_ca_1', foodName: 'Alimentos fonte de calcio (revisao medica)', nutrientId: 'calcium', tags: <String>['geral']),
  FoodSourceCard(id: 'f_zn_1', foodName: 'Alimentos fonte de zinco (revisao medica)', nutrientId: 'zinc', tags: <String>['geral']),
  FoodSourceCard(id: 'f_d_1', foodName: 'Fontes dieteticas relacionadas a vitamina D (revisao)', nutrientId: 'vit_d', tags: <String>['geral']),
];

MicronutrientProfile? micronutrientById(String id) {
  for (final MicronutrientProfile m in kMicronutrientCatalog) {
    if (m.id == id) return m;
  }
  return null;
}

LabExamDefinition? labExamById(String id) {
  for (final LabExamDefinition e in kLabExamCatalog) {
    if (e.id == id) return e;
  }
  return null;
}
