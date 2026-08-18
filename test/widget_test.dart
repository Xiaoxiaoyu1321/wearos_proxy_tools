import 'package:flutter_test/flutter_test.dart';

import 'package:wearos_proxy_tools/main.dart';

void main() {
  testWidgets('Proxy tools app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProxyToolsApp());
    await tester.pump();

    expect(find.text('代理设置'), findsOneWidget);
    expect(find.text('设置代理'), findsOneWidget);
    expect(find.text('清除代理'), findsOneWidget);
  });
}
