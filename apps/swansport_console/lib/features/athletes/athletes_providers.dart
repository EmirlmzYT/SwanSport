import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../app/widgets/console_table.dart';

/// Sporcu tablosunun o anki sorgusu (sayfa, sıralama, arama).
final athleteQueryProvider =
    StateProvider<ConsoleTableQuery>((ref) => const ConsoleTableQuery(
          sortKey: 'first_name',
        ));

/// Durum süzgeci: null = hepsi.
final athleteStatusFilterProvider = StateProvider<String?>((ref) => null);

/// Tabloda seçili satırların kimlikleri.
///
/// Sayfa değişince silinmiyor: kullanıcı 1. sayfadan 10, 2. sayfadan 5 kişi
/// seçip hepsine birden işlem yapabilsin.
final athleteSelectionProvider = StateProvider<Set<String>>((ref) => {});

/// Görünen sayfanın sunucudan çekildiği an.
///
/// Toplu işlem öncesi çakışma kontrolünün referans noktası: "bu andan sonra
/// değişen var mı?" Sayfa her yenilendiğinde tazelenir.
final athletePageLoadedAtProvider = StateProvider<DateTime>(
  (ref) => DateTime.now(),
);

/// Görünen sayfa.
final athletePageProvider =
    FutureProvider.autoDispose<List<AthleteRow>>((ref) async {
  final club = await ref.watch(activeClubProvider.future);
  if (club == null) return const [];

  final q = ref.watch(athleteQueryProvider);
  final status = ref.watch(athleteStatusFilterProvider);

  final rows = await ref.watch(athleteServiceProvider).fetchAthletes(
        club.id,
        limit: q.pageSize,
        offset: q.offset,
        search: q.search,
        status: status,
        orderBy: q.sortKey ?? 'first_name',
        ascending: q.ascending,
      );

  // Veriyi aldığımız anı işaretle. Sağlayıcının içinde başka bir sağlayıcının
  // durumunu yazmak alışılmadık; burada bilinçli, çünkü "bu veri ne zaman
  // tazeydi" bilgisi verinin kendisiyle aynı anda doğuyor.
  ref.read(athletePageLoadedAtProvider.notifier).state = DateTime.now();

  return rows;
});

/// Süzgece uyan toplam kayıt — sayfalayıcı bunu gösteriyor.
final athleteCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final club = await ref.watch(activeClubProvider.future);
  if (club == null) return 0;

  final q = ref.watch(athleteQueryProvider);
  final status = ref.watch(athleteStatusFilterProvider);

  return ref.watch(athleteServiceProvider).countAthletes(
        club.id,
        search: q.search,
        status: status,
      );
});

/// Dışa aktarma için süzgecin tamamı — sayfalamasız.
///
/// Ayrı bir çağrı olması bilinçli: kullanıcı 200 kayıttan 50'sini görüyorsa,
/// indirdiği dosyada 200'ü de olmalı.
Future<List<AthleteRow>> fetchAllAthletesForExport(WidgetRef ref) async {
  final club = await ref.read(activeClubProvider.future);
  if (club == null) return const [];

  final q = ref.read(athleteQueryProvider);
  final status = ref.read(athleteStatusFilterProvider);

  return ref.read(athleteServiceProvider).fetchAthletes(
        club.id,
        search: q.search,
        status: status,
        orderBy: q.sortKey ?? 'first_name',
        ascending: q.ascending,
      );
}

/// Tek sporcunun tam dosyası (detay ekranı).
final athleteDetailProvider =
    FutureProvider.autoDispose.family<AthleteFull?, String>((ref, id) {
  return ref.watch(athleteServiceProvider).fetchAthlete(id);
});
