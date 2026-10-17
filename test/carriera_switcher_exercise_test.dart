import 'package:flutter_test/flutter_test.dart';
import 'package:uniapp/exercises/carriera_switcher_exercise.dart';

void main() {
  const laurea = Carriera(matricola: '0512100001', corsoDiStudio: 'Informatica (L-31)');
  const magistrale = Carriera(matricola: '0512200002', corsoDiStudio: 'Ingegneria Informatica (LM-32)');

  test('il costruttore rifiuta una lista vuota', () {
    expect(() => CarrieraSwitcher([]), throwsArgumentError);
  });

  test('la prima carriera della lista è attiva di default', () {
    final s = CarrieraSwitcher([laurea, magistrale]);
    expect(s.carrieraAttiva, laurea);
  });

  test('carriere espone tutte le matricole nell\'ordine originale', () {
    final s = CarrieraSwitcher([laurea, magistrale]);
    expect(s.carriere, [laurea, magistrale]);
  });

  test('carriereAltre esclude solo quella attiva', () {
    final s = CarrieraSwitcher([laurea, magistrale]);
    expect(s.carriereAltre, [magistrale]);
  });

  test('selezionaCarriera cambia la carriera attiva', () {
    final s = CarrieraSwitcher([laurea, magistrale]);
    s.selezionaCarriera('0512200002');
    expect(s.carrieraAttiva, magistrale);
    expect(s.carriereAltre, [laurea]);
  });

  test('selezionaCarriera con matricola inesistente lancia errore e non cambia nulla', () {
    final s = CarrieraSwitcher([laurea, magistrale]);
    expect(() => s.selezionaCarriera('0000000000'), throwsArgumentError);
    expect(s.carrieraAttiva, laurea);
  });

  test('con una sola carriera, carriereAltre è vuota', () {
    final s = CarrieraSwitcher([laurea]);
    expect(s.carriereAltre, isEmpty);
    expect(s.carrieraAttiva, laurea);
  });
}
