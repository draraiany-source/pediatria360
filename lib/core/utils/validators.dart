import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Validadores de formulario, em pt-BR.
///
/// Mensagem de erro diz o que corrigir, nunca so "campo invalido".
class Validators {
  const Validators._();

  static final RegExp _email = RegExp(
    r'^[\w.\-+]+@([\w\-]+\.)+[a-zA-Z]{2,}$',
  );

  static String? required(String? value, {String field = 'Este campo'}) {
    if (value == null || value.trim().isEmpty) {
      return '$field e obrigatorio.';
    }
    return null;
  }

  static String? email(String? value) {
    final String v = (value ?? '').trim();
    if (v.isEmpty) return 'Informe seu e-mail.';
    if (!_email.hasMatch(v)) return 'E-mail invalido. Exemplo: nome@email.com';
    return null;
  }

  /// Senha do app: 8+ caracteres, com letra e numero. Regra escrita em uma
  /// linha para o usuario, nao em cinco mensagens diferentes.
  static String? password(String? value) {
    final String v = value ?? '';
    if (v.isEmpty) return 'Crie uma senha.';
    if (v.length < 8) return 'Use pelo menos 8 caracteres.';
    if (!RegExp(r'[A-Za-z]').hasMatch(v) || !RegExp(r'\d').hasMatch(v)) {
      return 'Misture letras e numeros.';
    }
    return null;
  }

  static String? confirmPassword(String? value, String original) {
    if (value != original) return 'As senhas nao coincidem.';
    return null;
  }

  static String? name(String? value) {
    final String v = (value ?? '').trim();
    if (v.isEmpty) return 'Informe o nome.';
    if (v.length < 2) return 'Nome muito curto.';
    return null;
  }

  /// Valida CPF pelos digitos verificadores.
  static String? cpf(String? value) {
    final String digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return 'Informe o CPF.';
    if (digits.length != 11) return 'O CPF tem 11 digitos.';
    if (RegExp(r'^(\d)\1{10}$').hasMatch(digits)) return 'CPF invalido.';

    int check(int length) {
      int sum = 0;
      for (int i = 0; i < length; i++) {
        sum += int.parse(digits[i]) * (length + 1 - i);
      }
      final int rest = (sum * 10) % 11;
      return rest == 10 ? 0 : rest;
    }

    if (check(9) != int.parse(digits[9]) ||
        check(10) != int.parse(digits[10])) {
      return 'CPF invalido.';
    }
    return null;
  }

  /// Valida CRM no formato `123456/UF`.
  static String? crm(String? value) {
    final String v = (value ?? '').trim().toUpperCase();
    if (v.isEmpty) return 'Informe o CRM.';
    if (!RegExp(r'^\d{4,7}\/[A-Z]{2}$').hasMatch(v)) {
      return 'Use o formato 123456/SP.';
    }
    return null;
  }

  static String? phone(String? value) {
    final String digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return 'Informe o telefone.';
    if (digits.length < 10 || digits.length > 11) {
      return 'Telefone invalido. Inclua o DDD.';
    }
    return null;
  }

  /// Data de nascimento: nao pode ser futura nem anterior a 25 anos (o app
  /// acompanha ate a adolescencia).
  static String? birthDate(DateTime? value) {
    if (value == null) return 'Informe a data de nascimento.';
    final DateTime now = DateTime.now();
    if (value.isAfter(now)) return 'A data nao pode estar no futuro.';
    if (now.difference(value).inDays > 365 * 25) {
      return 'Data fora do intervalo do acompanhamento pediatrico.';
    }
    return null;
  }

  /// Peso em kg. Recem-nascido prematuro pode ter 0,4 kg; adolescente, 150 kg.
  static String? weightKg(String? value) {
    final double? v = Parsers.decimal(value);
    if (v == null) return 'Informe o peso em kg.';
    if (v < 0.3 || v > 150) return 'Peso fora do esperado (0,3 a 150 kg).';
    return null;
  }

  static String? heightCm(String? value) {
    final double? v = Parsers.decimal(value);
    if (v == null) return 'Informe a altura em cm.';
    if (v < 20 || v > 220) return 'Altura fora do esperado (20 a 220 cm).';
    return null;
  }

  static String? headCircumferenceCm(String? value) {
    if (value == null || value.trim().isEmpty) return null; // opcional
    final double? v = Parsers.decimal(value);
    if (v == null) return 'Valor invalido.';
    if (v < 20 || v > 70) return 'Perimetro fora do esperado (20 a 70 cm).';
    return null;
  }
}

/// Conversores tolerantes ao formato brasileiro (virgula decimal).
class Parsers {
  const Parsers._();

  /// Converte texto digitado em número, aceitando o separador decimal
  /// brasileiro (vírgula).
  ///
  /// ## O bug que esta versão corrige
  ///
  /// A versão anterior trocava toda vírgula por ponto e nada mais. Isso
  /// funciona para "5,5", mas quebra qualquer número com separador de
  /// milhar: "1.234,5" virava "1.234.5" — dois pontos, `double.tryParse`
  /// retorna nulo, a calculadora simplesmente não calcula nada. Pior:
  /// "3.000" (por exemplo, uma dose máxima diária de 3000 mg) passava sem
  /// erro nenhum, mas retornava **3.0** — mil vezes menor que o digitado,
  /// silenciosamente. Essa função é a base de toda calculadora clínica do
  /// app; um erro de magnitude aqui não é cosmético.
  ///
  /// ## O que fica ambíguo de propósito
  ///
  /// Um único ponto sem vírgula ("1.234") continua sendo lido como decimal
  /// (1,234), não como milhar (1234). Não há como diferenciar as duas
  /// leituras só pelo texto — e é exatamente o que um teclado numérico
  /// produz ao digitar "5.5". Resolver o caso ambíguo por adivinhação
  /// arriscaria quebrar o caso comum para consertar o raro.
  static double? decimal(String? value) {
    if (value == null) return null;
    String normalized = value.trim();
    if (normalized.isEmpty) return null;

    if (normalized.contains(',')) {
      // Vírgula presente: é o separador decimal, sem ambiguidade. Qualquer
      // ponto antes dela só pode ser separador de milhar.
      normalized = normalized.replaceAll('.', '').replaceAll(',', '.');
    } else if (normalized.split('.').length > 2) {
      // Mais de um ponto, sem vírgula: só é possível como agrupamento de
      // milhar ("1.234.567") — nenhum decimal real tem dois pontos.
      normalized = normalized.replaceAll('.', '');
    } else {
      final List<String> parts = normalized.split('.');
      // Um único ponto seguido de exatamente três zeros é milhar redondo
      // brasileiro ("3.000", "10.000") — não decimal. "5.5" e "1.234"
      // continuam sendo lidos como decimal, o caso comum do teclado.
      if (parts.length == 2 && parts[1] == '000') {
        normalized = '${parts[0]}000';
      }
    }

    return double.tryParse(normalized);
  }

  static int? integer(String? value) =>
      int.tryParse((value ?? '').replaceAll(RegExp(r'\D'), ''));
}

/// Formatadores de exibicao.
class Formatters {
  const Formatters._();

  static const List<String> _monthsPt = <String>[
    'janeiro',
    'fevereiro',
    'marco',
    'abril',
    'maio',
    'junho',
    'julho',
    'agosto',
    'setembro',
    'outubro',
    'novembro',
    'dezembro',
  ];

  // Padrões numéricos não dependem de initializeDateFormatting — evita crash
  // em testes e em qualquer chamada antes do bootstrap do app.
  static final DateFormat _date = DateFormat('dd/MM/yyyy');
  static final DateFormat _dateTime = DateFormat('dd/MM/yyyy HH:mm');
  static final NumberFormat _currency = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$',
  );

  static String date(DateTime value) => _date.format(value);

  /// Data por extenso, usada como cabecalho de dia na linha do tempo.
  ///
  /// "Hoje" e "Ontem" em vez da data: quem le um prontuario recem-atualizado
  /// se orienta melhor pela referencia relativa.
  static String dateLong(DateTime value) {
    final DateTime now = DateTime.now();
    bool sameDay(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;

    if (sameDay(value, now)) return 'Hoje';
    if (sameDay(value, now.subtract(const Duration(days: 1)))) return 'Ontem';

    final String base = '${value.day} de ${_monthsPt[value.month - 1]}';
    return value.year == now.year ? base : '$base de ${value.year}';
  }
  static String dateTime(DateTime value) => _dateTime.format(value);

  static final DateFormat _time = DateFormat('HH:mm');
  static String time(DateTime value) => _time.format(value);

  static String monthYear(DateTime value) =>
      '${_monthsPt[value.month - 1]} ${value.year}';
  static String currency(num value) => _currency.format(value);

  static String decimal(num value, {int digits = 1}) =>
      NumberFormat.decimalPatternDigits(
        locale: 'pt_BR',
        decimalDigits: digits,
      ).format(value);

  static String cpf(String digits) {
    final String d = digits.replaceAll(RegExp(r'\D'), '').padRight(11, ' ');
    return '${d.substring(0, 3)}.${d.substring(3, 6)}.'
            '${d.substring(6, 9)}-${d.substring(9, 11)}'
        .trim();
  }

  /// Idade pediatrica: ate 2 anos conta-se em meses; depois, em anos.
  /// Essa e a convencao clinica — "18 meses" diz mais que "1 ano e meio".
  static String pediatricAge(DateTime birthDate, {DateTime? at}) {
    final DateTime reference = at ?? DateTime.now();
    final int totalMonths = monthsBetween(birthDate, reference);

    if (totalMonths < 1) {
      final int days = reference.difference(birthDate).inDays;
      return days <= 1 ? '$days dia' : '$days dias';
    }
    if (totalMonths < 24) {
      return totalMonths == 1 ? '1 mes' : '$totalMonths meses';
    }
    final int years = totalMonths ~/ 12;
    final int months = totalMonths % 12;
    if (months == 0) return years == 1 ? '1 ano' : '$years anos';
    return '$years ${years == 1 ? 'ano' : 'anos'} e $months '
        '${months == 1 ? 'mes' : 'meses'}';
  }

  static int monthsBetween(DateTime from, DateTime to) {
    int months = (to.year - from.year) * 12 + (to.month - from.month);
    if (to.day < from.day) months -= 1;
    return months < 0 ? 0 : months;
  }

  /// "ha 3 dias", "agora" — usado em feed e historico.
  static String relative(DateTime value, {DateTime? at}) {
    final Duration diff = (at ?? DateTime.now()).difference(value);
    if (diff.inMinutes < 1) return 'agora';
    if (diff.inMinutes < 60) return 'ha ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'ha ${diff.inHours} h';
    if (diff.inDays < 7) {
      return diff.inDays == 1 ? 'ontem' : 'ha ${diff.inDays} dias';
    }
    return date(value);
  }

  static String duration(Duration value) {
    final int minutes = value.inMinutes;
    if (minutes < 60) return '$minutes min';
    final int hours = minutes ~/ 60;
    final int rest = minutes % 60;
    return rest == 0 ? '${hours}h' : '${hours}h ${rest}min';
  }
}

/// Mascaras de entrada.
class Masks {
  const Masks._();

  static List<TextInputFormatter> get digitsOnly => <TextInputFormatter>[
        FilteringTextInputFormatter.digitsOnly,
      ];

  static List<TextInputFormatter> get decimal => <TextInputFormatter>[
        FilteringTextInputFormatter.allow(RegExp(r'[\d,.]')),
      ];

  static List<TextInputFormatter> get cpf => <TextInputFormatter>[
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(11),
        _CpfFormatter(),
      ];

  static List<TextInputFormatter> get phone => <TextInputFormatter>[
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(11),
        _PhoneFormatter(),
      ];
}

class _CpfFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final String digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i == 3 || i == 6) buffer.write('.');
      if (i == 9) buffer.write('-');
      buffer.write(digits[i]);
    }
    final String text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class _PhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final String digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i == 0) buffer.write('(');
      if (i == 2) buffer.write(') ');
      if (i == (digits.length > 10 ? 7 : 6)) buffer.write('-');
      buffer.write(digits[i]);
    }
    final String text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
