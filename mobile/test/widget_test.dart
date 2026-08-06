import 'package:flutter_test/flutter_test.dart';
import 'package:form_up/app_router.dart';
import 'package:form_up/main.dart';

void main() {
  testWidgets('App boots to login screen', (WidgetTester tester) async {
    await tester.pumpWidget(MyApp(delegate: AppRouterDelegate()));

    expect(find.text('Masuk'), findsWidgets);
    expect(find.text('Lupa Kata Sandi?'), findsOneWidget);
  });
}
