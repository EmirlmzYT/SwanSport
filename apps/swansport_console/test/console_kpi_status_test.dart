import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_console/app/console_kpi_status.dart';

void main() {
  test('active ratio is measured; empty roster is not 100 percent', () {
    expect(ConsoleKpiStatus.roster(100, 90).label, '%90 Aktif Kadro');
    expect(ConsoleKpiStatus.roster(100, 90).progress, .9);
    expect(ConsoleKpiStatus.roster(0, 0).progress, isNull);
    expect(ConsoleKpiStatus.roster(10, 11).progress, isNull);
  });
  test('marks never imply completed attendance', () {
    expect(ConsoleKpiStatus.attendance(4, 4).label, '4/4 oturumda kayıt');
    expect(ConsoleKpiStatus.attendance(4, 2).progress, .5);
    expect(ConsoleKpiStatus.attendance(0, 0).progress, isNull);
    expect(ConsoleKpiStatus.attendance(4, 5).progress, isNull);
  });
  test('risk absence is not unconditional eligibility certification', () {
    expect(ConsoleKpiStatus.risk(0).label, 'Kayıtlı kısıt yok');
    expect(ConsoleKpiStatus.risk(2).label, '2 uygunluk kısıtı');
  });
  test('finance status is based only on pending approvals', () {
    expect(ConsoleKpiStatus.finance(0).label, 'Bekleyen onay yok');
    expect(ConsoleKpiStatus.finance(5).label, '5 onay bekliyor');
  });
}
