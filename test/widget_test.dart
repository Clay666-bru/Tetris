import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tetris/main.dart';

void main() {
  testWidgets('Prueba de carga del menu de Tetris', (
    WidgetTester tester,
  ) async {
    // Valores simulados para SharedPreferences (no hay disco en las pruebas)
    SharedPreferences.setMockInitialValues({});

    // Construye nuestra app (MyApp) y dispara un frame.
    await tester.pumpWidget(const MyApp());

    // Verifica que el título de tu juego 'TETRIS' aparezca en la pantalla de inicio
    expect(find.text('TETRIS'), findsOneWidget);

    // Verifica que los botones principales del menú estén presentes
    expect(find.text('INICIAR JUEGO'), findsOneWidget);
    expect(find.text('SCORES'), findsOneWidget);
  });
}
