import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_scope.dart';

/// Spor malzemeleri pazaryeri.
///
/// **Mevcut `listings` tablosunu kullanıyor**, ikinci bir ilan sistemi
/// kurmuyor (0050). Sporcu/iş/organizasyon ilanları etkilenmiyor: onlarda
/// `market_status` null ve buradaki hiçbir sorgu onları görmüyor.
///
/// İlk sürümde ödeme yok. Alıcı ve satıcı mevcut DM sistemiyle anlaşıyor;
/// bu servis ilan, görsel, favori, rapor ve durum yönetimini taşıyor.

/// Ürün durumu. Sıralama kötüden iyiye değil, **yeniden eskiye**: arayüzde
/// bu sırayla gösteriliyor ve kullanıcı "en iyi hangisi" diye düşünmüyor.
enum ItemCondition { isNew, likeNew, veryGood, good, used }

extension ItemConditionX on ItemCondition {
  String get code => switch (this) {
        ItemCondition.isNew => 'new',
        ItemCondition.likeNew => 'like_new',
        ItemCondition.veryGood => 'very_good',
        ItemCondition.good => 'good',
        ItemCondition.used => 'used',
      };

  String get label => switch (this) {
        ItemCondition.isNew => 'Sıfır',
        ItemCondition.likeNew => 'Sıfır gibi',
        ItemCondition.veryGood => 'Çok iyi',
        ItemCondition.good => 'İyi',
        ItemCondition.used => 'Kullanılmış',
      };

  static ItemCondition? fromCode(String? c) => switch (c) {
        'new' => ItemCondition.isNew,
        'like_new' => ItemCondition.likeNew,
        'very_good' => ItemCondition.veryGood,
        'good' => ItemCondition.good,
        'used' => ItemCondition.used,
        _ => null,
      };
}

/// Teslim tercihi.
enum DeliveryKind { hand, shipping, both }

extension DeliveryKindX on DeliveryKind {
  String get code => switch (this) {
        DeliveryKind.hand => 'hand_delivery',
        DeliveryKind.shipping => 'shipping',
        DeliveryKind.both => 'both',
      };

  String get label => switch (this) {
        DeliveryKind.hand => 'Elden teslim',
        DeliveryKind.shipping => 'Kargo',
        DeliveryKind.both => 'Elden veya kargo',
      };

  static DeliveryKind fromCode(String? c) => switch (c) {
        'shipping' => DeliveryKind.shipping,
        'both' => DeliveryKind.both,
        _ => DeliveryKind.hand,
      };
}

/// İlanın yaşam döngüsü.
enum MarketStatus {
  draft,
  active,
  reserved,
  sold,
  removedByOwner,
  underReview,
  hiddenByModeration,
}

extension MarketStatusX on MarketStatus {
  String get code => switch (this) {
        MarketStatus.draft => 'draft',
        MarketStatus.active => 'active',
        MarketStatus.reserved => 'reserved',
        MarketStatus.sold => 'sold',
        MarketStatus.removedByOwner => 'removed_by_owner',
        MarketStatus.underReview => 'under_review',
        MarketStatus.hiddenByModeration => 'hidden_by_moderation',
      };

  String get label => switch (this) {
        MarketStatus.draft => 'Taslak',
        MarketStatus.active => 'Yayında',
        MarketStatus.reserved => 'Rezerve',
        MarketStatus.sold => 'Satıldı',
        MarketStatus.removedByOwner => 'Kaldırıldı',
        MarketStatus.underReview => 'İncelemede',
        MarketStatus.hiddenByModeration => 'Gizlendi',
      };

  /// Alıcı bu ilanla ilgilenebilir mi.
  bool get isBuyable => this == MarketStatus.active;

  static MarketStatus fromCode(String? c) => switch (c) {
        'active' => MarketStatus.active,
        'reserved' => MarketStatus.reserved,
        'sold' => MarketStatus.sold,
        'removed_by_owner' => MarketStatus.removedByOwner,
        'under_review' => MarketStatus.underReview,
        'hidden_by_moderation' => MarketStatus.hiddenByModeration,
        _ => MarketStatus.draft,
      };
}

/// Arama sonucundaki bir ilan.
class MarketItem {
  const MarketItem({
    required this.id,
    required this.title,
    required this.status,
    this.price,
    this.condition,
    this.sellerType,
    this.storeId,
    this.storeName,
    this.cityCode,
    this.district,
    this.delivery = DeliveryKind.hand,
    this.imagePath,
    required this.createdAt,
  });

  factory MarketItem.fromMap(Map<String, dynamic> m) => MarketItem(
        id: m['id'] as String,
        title: (m['title'] as String?) ?? '',
        price: (m['price'] as num?)?.toDouble(),
        condition: ItemConditionX.fromCode(m['item_condition'] as String?),
        sellerType: m['seller_type'] as String?,
        storeId: m['store_id'] as String?,
        storeName: m['store_name'] as String?,
        cityCode: m['city_code'] as String?,
        district: m['district'] as String?,
        delivery: DeliveryKindX.fromCode(m['delivery'] as String?),
        status: MarketStatusX.fromCode(m['market_status'] as String?),
        imagePath: m['image_path'] as String?,
        createdAt: DateTime.tryParse('${m['created_at']}')?.toLocal() ??
            DateTime.now(),
      );

  final String id;
  final String title;
  final double? price;
  final ItemCondition? condition;
  final String? sellerType;
  final String? storeId;
  final String? storeName;
  final String? cityCode;
  final String? district;
  final DeliveryKind delivery;
  final MarketStatus status;
  final String? imagePath;
  final DateTime createdAt;

  bool get isStore => sellerType == 'verified_store';

  /// Konum satırı — ilçe varsa onunla, yoksa yalnızca şehir.
  String get placeLabel =>
      [district, cityCode].where((e) => (e ?? '').isNotEmpty).join(', ');
}

/// Mağaza.
class StoreRow {
  const StoreRow({
    required this.id,
    required this.name,
    required this.status,
    this.logoPath,
    this.description,
    this.cityCode,
    this.district,
    this.reviewNote,
  });

  factory StoreRow.fromMap(Map<String, dynamic> m) => StoreRow(
        id: m['id'] as String,
        name: (m['name'] as String?) ?? '',
        status: (m['status'] as String?) ?? 'pending',
        logoPath: m['logo_path'] as String?,
        description: m['description'] as String?,
        cityCode: m['city_code'] as String?,
        district: m['district'] as String?,
        reviewNote: m['review_note'] as String?,
      );

  final String id;
  final String name;

  /// pending | approved | rejected | suspended
  final String status;
  final String? logoPath;
  final String? description;
  final String? cityCode;
  final String? district;

  /// Yöneticinin karar notu — reddedilen başvuruda kullanıcı sebebini görsün.
  final String? reviewNote;

  bool get isApproved => status == 'approved';

  String get statusLabel => switch (status) {
        'approved' => 'Onaylı',
        'rejected' => 'Reddedildi',
        'suspended' => 'Askıya alındı',
        _ => 'İnceleniyor',
      };
}

/// Rapor sebebi.
enum ReportReason {
  counterfeit,
  wrongDescription,
  prohibited,
  spam,
  inappropriate,
  other,
}

extension ReportReasonX on ReportReason {
  String get code => switch (this) {
        ReportReason.counterfeit => 'counterfeit',
        ReportReason.wrongDescription => 'wrong_description',
        ReportReason.prohibited => 'prohibited',
        ReportReason.spam => 'spam',
        ReportReason.inappropriate => 'inappropriate',
        ReportReason.other => 'other',
      };

  String get label => switch (this) {
        ReportReason.counterfeit => 'Sahte ürün',
        ReportReason.wrongDescription => 'Yanlış açıklama',
        ReportReason.prohibited => 'Yasaklı ürün',
        ReportReason.spam => 'Spam',
        ReportReason.inappropriate => 'Uygunsuz içerik',
        ReportReason.other => 'Diğer',
      };
}

/// Arama filtreleri — tek nesne, çünkü hepsi birlikte değişiyor ve ekran
/// bunları tek bir durumda tutuyor.
class MarketFilter {
  const MarketFilter({
    this.query,
    this.sport,
    this.category,
    this.city,
    this.district,
    this.condition,
    this.delivery,
    this.sellerType,
    this.brand,
    this.minPrice,
    this.maxPrice,
    this.sort = 'new',
  });

  final String? query;
  final String? sport;
  final String? category;
  final String? city;
  final String? district;
  final ItemCondition? condition;
  final DeliveryKind? delivery;
  final String? sellerType;
  final String? brand;
  final double? minPrice;
  final double? maxPrice;

  /// new | price_asc | price_desc
  final String sort;

  bool get isEmpty =>
      (query ?? '').isEmpty &&
      sport == null &&
      category == null &&
      city == null &&
      district == null &&
      condition == null &&
      delivery == null &&
      sellerType == null &&
      (brand ?? '').isEmpty &&
      minPrice == null &&
      maxPrice == null;

  MarketFilter copyWith({
    Object? query = _keep,
    Object? sport = _keep,
    Object? category = _keep,
    Object? city = _keep,
    Object? district = _keep,
    Object? condition = _keep,
    Object? delivery = _keep,
    Object? sellerType = _keep,
    Object? brand = _keep,
    Object? minPrice = _keep,
    Object? maxPrice = _keep,
    String? sort,
  }) =>
      MarketFilter(
        query: query == _keep ? this.query : query as String?,
        sport: sport == _keep ? this.sport : sport as String?,
        category: category == _keep ? this.category : category as String?,
        city: city == _keep ? this.city : city as String?,
        district: district == _keep ? this.district : district as String?,
        condition:
            condition == _keep ? this.condition : condition as ItemCondition?,
        delivery: delivery == _keep ? this.delivery : delivery as DeliveryKind?,
        sellerType:
            sellerType == _keep ? this.sellerType : sellerType as String?,
        brand: brand == _keep ? this.brand : brand as String?,
        minPrice: minPrice == _keep ? this.minPrice : minPrice as double?,
        maxPrice: maxPrice == _keep ? this.maxPrice : maxPrice as double?,
        sort: sort ?? this.sort,
      );

  /// `copyWith`'te "değiştirme" ile "null yap" ayrımı için nöbetçi değer.
  /// Olmadan bir filtreyi temizlemek mümkün değildi.
  static const _keep = Object();
}

class MarketplaceService {
  MarketplaceService(this._c);
  final SupabaseClient _c;

  String? get _uid => _c.auth.currentUser?.id;

  /// İlan arama. Sayfalama imleçle: `offset` arada yeni ilan eklenince
  /// sayfa sınırında ilan atlatıyor ya da tekrarlatıyor.
  Future<List<MarketItem>> search(
    MarketFilter f, {
    MarketItem? after,
    int limit = 20,
  }) async {
    final rows = await _c.rpc<dynamic>('search_market_listings', params: {
      'p_query': f.query,
      'p_sport': f.sport,
      'p_category': f.category,
      'p_city': f.city,
      'p_district': f.district,
      'p_condition': f.condition?.code,
      'p_delivery': f.delivery?.code,
      'p_seller': f.sellerType,
      'p_brand': f.brand,
      'p_min_price': f.minPrice,
      'p_max_price': f.maxPrice,
      'p_sort': f.sort,
      'p_after_at': after?.createdAt.toUtc().toIso8601String(),
      'p_after_id': after?.id,
      'p_limit': limit,
    });
    return ((rows as List?) ?? const [])
        .map((r) => MarketItem.fromMap(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  /// Tek ilanın tam ayrıntısı — arama sonucu taşımadığı alanlar için.
  Future<Map<String, dynamic>?> detail(String id) async {
    final rows = await _c
        .from('listings')
        .select('*, stores(name, logo_path, status)')
        .eq('id', id)
        .limit(1);
    final list = rows as List;
    return list.isEmpty ? null : Map<String, dynamic>.from(list.first as Map);
  }

  /// Storage yolundan görüntülenebilir adres.
  ///
  /// Veritabanında **yol** tutuluyor, URL değil (0050): bucket ya da alan adı
  /// değişince saklanmış URL'lerin hepsi kırılırdı. Adres gerektiğinde
  /// üretiliyor.
  ///
  /// `post-media` kovası kullanılıyor — gönderi görselleri de orada ve
  /// pazaryeri için ikinci bir genel kova açmak, aynı erişim kurallarını iki
  /// yerde tutmak demekti.
  String imageUrl(String path) =>
      path.startsWith('http') ? path : _c.storage.from('post-media').getPublicUrl(path);

  Future<List<String>> images(String listingId) async {
    final rows = await _c
        .from('listing_images')
        .select('image_path')
        .eq('listing_id', listingId)
        .order('sort_order');
    return (rows as List)
        .map((r) => ((r as Map)['image_path'] as String?) ?? '')
        .where((p) => p.isNotEmpty)
        .toList();
  }

  Future<String> create({
    required String title,
    String? body,
    String? storeId,
    String? sport,
    String? category,
    String? subcategory,
    String? brand,
    String? model,
    String? size,
    String? color,
    ItemCondition condition = ItemCondition.used,
    String? defectNote,
    double? price,
    bool negotiable = false,
    int stock = 1,
    DeliveryKind delivery = DeliveryKind.hand,
    String? city,
    String? district,
    bool publish = true,
  }) async {
    final id = await _c.rpc<dynamic>('create_market_listing', params: {
      'p_title': title,
      'p_body': body,
      'p_store': storeId,
      'p_sport': sport,
      'p_category': category,
      'p_subcategory': subcategory,
      'p_brand': brand,
      'p_model': model,
      'p_size': size,
      'p_color': color,
      'p_condition': condition.code,
      'p_defect_note': defectNote,
      'p_price': price,
      'p_negotiable': negotiable,
      'p_stock': stock,
      'p_delivery': delivery.code,
      'p_city': city,
      'p_district': district,
      'p_publish': publish,
    });
    return '$id';
  }

  /// Görsel kaydı. Yükleme Storage'a ayrıca yapılıyor; burada yalnızca yol
  /// tutuluyor — URL saklamak, bucket ya da alan adı değişince bütün
  /// görselleri kırardı.
  Future<void> addImage(String listingId, String path, int order) =>
      _c.from('listing_images').insert({
        'listing_id': listingId,
        'image_path': path,
        'sort_order': order,
      });

  Future<void> setStatus(String listingId, MarketStatus status) =>
      _c.rpc<void>('set_market_listing_status',
          params: {'p_listing': listingId, 'p_status': status.code});

  // ----------------------------------------------------------- favoriler
  Future<Set<String>> myFavorites() async {
    final uid = _uid;
    if (uid == null) return {};
    final rows = await _c
        .from('marketplace_favorites')
        .select('listing_id')
        .eq('profile_id', uid);
    return (rows as List)
        .map((r) => (r as Map)['listing_id'] as String)
        .toSet();
  }

  Future<void> setFavorite(String listingId, bool on) async {
    final uid = _uid;
    if (uid == null) return;
    if (on) {
      await _c.from('marketplace_favorites').upsert({
        'profile_id': uid,
        'listing_id': listingId,
      });
    } else {
      await _c
          .from('marketplace_favorites')
          .delete()
          .eq('profile_id', uid)
          .eq('listing_id', listingId);
    }
  }

  // ------------------------------------------------------------ raporlar
  Future<void> report(String listingId, ReportReason reason,
      {String? note}) async {
    final uid = _uid;
    if (uid == null) return;
    await _c.from('marketplace_reports').insert({
      'listing_id': listingId,
      'reporter_id': uid,
      'reason': reason.code,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    });
  }

  // ------------------------------------------------------------ mağazalar
  Future<List<StoreRow>> myStores() async {
    final uid = _uid;
    if (uid == null) return const [];
    final rows = await _c
        .from('store_memberships')
        .select('stores(*)')
        .eq('profile_id', uid);
    return (rows as List)
        .map((r) => (r as Map)['stores'])
        .whereType<Map>()
        .map((m) => StoreRow.fromMap(Map<String, dynamic>.from(m)))
        .toList();
  }

  /// Mağaza başvurusu. Durum her zaman `pending` başlıyor; RLS de bunu
  /// zorluyor, istemciye güvenilmiyor.
  Future<String> applyForStore({
    required String name,
    String? description,
    String? city,
    String? district,
    String? note,
  }) async {
    final uid = _uid;
    if (uid == null) throw StateError('Giriş yapılmamış');

    final rows = await _c
        .from('stores')
        .insert({
          'name': name.trim(),
          'description': description,
          'city_code': city,
          'district': district,
          'application_note': note,
          'status': 'pending',
        })
        .select('id')
        .limit(1);

    final id = ((rows as List).first as Map)['id'] as String;
    // Başvuran mağazanın sahibi olur.
    await _c.from('store_memberships').insert({
      'store_id': id,
      'profile_id': uid,
      'role': 'owner',
    });
    return id;
  }
}

// =============================== Provider'lar ==============================

final marketplaceServiceProvider = Provider<MarketplaceService>((ref) {
  return MarketplaceService(ref.watch(supabaseClientProvider));
});

/// Arama sonucu. Filtre değişince yeniden çalışıyor.
final marketSearchProvider = FutureProvider.autoDispose
    .family<List<MarketItem>, MarketFilter>((ref, filter) {
  if (!ref.watch(isSupabaseEnabledProvider)) {
    return Future.value(const <MarketItem>[]);
  }
  return ref.watch(marketplaceServiceProvider).search(filter);
});

final marketFavoritesProvider =
    FutureProvider.autoDispose<Set<String>>((ref) {
  if (!ref.watch(isSupabaseEnabledProvider)) return Future.value(<String>{});
  return ref.watch(marketplaceServiceProvider).myFavorites();
});

final myStoresProvider = FutureProvider.autoDispose<List<StoreRow>>((ref) {
  if (!ref.watch(isSupabaseEnabledProvider)) {
    return Future.value(const <StoreRow>[]);
  }
  return ref.watch(marketplaceServiceProvider).myStores();
});

final marketImagesProvider =
    FutureProvider.autoDispose.family<List<String>, String>((ref, id) {
  if (!ref.watch(isSupabaseEnabledProvider)) {
    return Future.value(const <String>[]);
  }
  return ref.watch(marketplaceServiceProvider).images(id);
});

final marketDetailProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, String>((ref, id) {
  if (!ref.watch(isSupabaseEnabledProvider)) return Future.value(null);
  return ref.watch(marketplaceServiceProvider).detail(id);
});
