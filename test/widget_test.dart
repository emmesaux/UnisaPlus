import 'package:flutter_test/flutter_test.dart';
import 'package:unisa_plus/main.dart';

void main() {
  testWidgets('App avvia e mostra la schermata di accesso', (WidgetTester tester) async {
    await tester.pumpWidget(const UniApp());
    // Il controllo della sessione salvata ha un timeout di sicurezza di 5s
    // (vedi AuthService.restoreSession): lo si aspetta per intero così la
    // schermata di accesso compare anche senza un plugin di storage reale.
    await tester.pump(const Duration(seconds: 6));
    expect(find.textContaining('Bentornato'), findsOneWidget);
  });
}
