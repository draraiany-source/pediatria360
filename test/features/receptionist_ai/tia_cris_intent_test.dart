import 'package:flutter_test/flutter_test.dart';
import 'package:pediatria360/features/receptionist_ai/domain/tia_cris_intent.dart';

void main() {
  const TiaCrisEngine engine = TiaCrisEngine();

  test('recusa clinica e pede handoff', () {
    final TiaCrisReply r = engine.reply('Estou com febre, qual remedio?');
    expect(r.intent, TiaCrisIntent.refuseClinical);
    expect(r.suggestHandoff, isTrue);
  });

  test('agendamento aponta agenda real', () {
    final TiaCrisReply r = engine.reply('Quero agendar consulta');
    expect(r.intent, TiaCrisIntent.bookingHelp);
    expect(r.suggestAgenda, isTrue);
  });

  test('kids aponta espaco kids', () {
    final TiaCrisReply r = engine.reply('Tem jogo para a crianca?');
    expect(r.intent, TiaCrisIntent.kidsHelp);
    expect(r.suggestKids, isTrue);
  });

  test('whatsapp nao finge envio', () {
    final TiaCrisReply r = engine.reply('Manda lembrete no whatsapp');
    expect(r.intent, TiaCrisIntent.whatsappStatus);
    expect(r.text.toLowerCase().contains('simulado') || r.text.contains('nunca'), isTrue);
  });
}
