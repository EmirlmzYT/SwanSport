import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_scope.dart';

/// ---------------------------------------------------------------------------
/// Sosyal katman — akış, gönderi, beğeni, yorum, takip, profil.
/// ---------------------------------------------------------------------------

const String kPostMediaBucket = 'post-media';

/// Seçilmiş bir görselin baytları ve dosya adı.
///
/// `swansport_data` arayüze bağlanmıyor (değişmez 2): burada `XFile` ya da
/// `ImageProvider` yok, yalnızca bayt ve ad. Seçiciyi tüketen uygulama
/// çalıştırıyor.
class PickedMedia {
  const PickedMedia({required this.bytes, required this.name});

  final Uint8List bytes;
  final String name;
}

class PostRow {
  const PostRow({
    required this.id,
    required this.body,
    required this.createdAt,
    required this.authorId,
    this.imageUrl,
    this.kind = 'post',
    this.clubId,
    this.clubName,
    this.authorName,
    this.authorAvatarUrl,
    this.likeCount = 0,
    this.commentCount = 0,
    this.likedByMe = false,
  });

  final String id;
  final String body;
  final DateTime createdAt;
  final String authorId;
  final String? imageUrl;
  final String kind; // post | news
  final String? clubId;
  final String? clubName;
  final String? authorName;
  final String? authorAvatarUrl;
  final int likeCount;
  final int commentCount;
  final bool likedByMe;

  /// Kulüp adına paylaşıldıysa kulüp adı, yoksa kişi adı gösterilir.
  String get displayName => clubName ?? authorName ?? 'SwanSport';
  bool get isClubPost => clubId != null;
  bool get isNews => kind == 'news';

  String get initials {
    final n = displayName.trim();
    if (n.isEmpty) return '?';
    final parts = n.split(RegExp(r'\s+'));
    final a = parts.first.isNotEmpty ? parts.first[0] : '';
    final b = parts.length > 1 && parts[1].isNotEmpty ? parts[1][0] : '';
    final res = '$a$b'.toUpperCase();
    return res.isEmpty ? '?' : res;
  }

  PostRow copyWith({int? likeCount, bool? likedByMe, int? commentCount}) =>
      PostRow(
        id: id,
        body: body,
        createdAt: createdAt,
        authorId: authorId,
        imageUrl: imageUrl,
        kind: kind,
        clubId: clubId,
        clubName: clubName,
        authorName: authorName,
        authorAvatarUrl: authorAvatarUrl,
        likeCount: likeCount ?? this.likeCount,
        commentCount: commentCount ?? this.commentCount,
        likedByMe: likedByMe ?? this.likedByMe,
      );
}

class CommentRow {
  const CommentRow({
    required this.id,
    required this.body,
    required this.createdAt,
    required this.profileId,
    this.authorName,
    this.authorAvatarUrl,
  });

  final String id;
  final String body;
  final DateTime createdAt;
  final String profileId;
  final String? authorName;
  final String? authorAvatarUrl;

  String get initials {
    final n = (authorName ?? '?').trim();
    if (n.isEmpty) return '?';
    return n[0].toUpperCase();
  }
}

/// Sosyal profil (kişi veya kulüp) — profil sayfası için.
class SocialProfile {
  const SocialProfile({
    required this.id,
    required this.name,
    required this.isClub,
    this.username,
    this.bio,
    this.avatarUrl,
    this.roleLabel,
    this.postCount = 0,
    this.followerCount = 0,
    this.followingCount = 0,
    this.isFollowedByMe = false,
    this.isMe = false,
    this.credentials = const [],
    this.cityCode,
  });

  final String id;
  final String name;
  final bool isClub;
  final String? username;
  final String? bio;
  final String? avatarUrl;
  final String? roleLabel;
  final int postCount;
  final int followerCount;
  final int followingCount;
  final bool isFollowedByMe;
  final bool isMe;

  /// Kişinin ili (plaka kodu) — şehir topluluğu buna göre belirlenir.
  final String? cityCode;

  /// Onaylanmış kimlikler (ör. "2. Kademe Antrenör") — doğrulama rozetleri.
  final List<String> credentials;

  bool get isVerified => credentials.isNotEmpty;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    final a = parts.first.isNotEmpty ? parts.first[0] : '';
    final b = parts.length > 1 && parts[1].isNotEmpty ? parts[1][0] : '';
    final res = '$a$b'.toUpperCase();
    return res.isEmpty ? '?' : res;
  }
}

/// Takip önerisi / arama sonucu — kulüp, antrenör, sporcu veya kişi.
class SuggestionRow {
  const SuggestionRow({
    required this.id,
    required this.name,
    required this.kind,
    this.subtitle,
    this.avatarUrl,
  });

  final String id;
  final String name;

  /// 'club' | 'coach' | 'athlete' | 'person'
  final String kind;
  final String? subtitle;
  final String? avatarUrl;

  bool get isClub => kind == 'club';
  String get targetType => isClub ? 'club' : 'profile';

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    final a = parts.first.isNotEmpty ? parts.first[0] : '';
    final b = parts.length > 1 && parts[1].isNotEmpty ? parts[1][0] : '';
    final res = '$a$b'.toUpperCase();
    return res.isEmpty ? '?' : res;
  }
}

/// Antrenör rozeti — branş onaylı belgeden gelir: "Yüzme · 2. Kademe Antrenör".
String _coachLabel(Map<String, dynamic> m) {
  final level = '${m['coach_level'] ?? '?'}. Kademe Antrenör';
  final sport = (m['sports'] is Map)
      ? (m['sports'] as Map)['name'] as String?
      : null;
  return (sport == null || sport.isEmpty) ? level : '$sport · $level';
}

class SocialService {
  SocialService(this._c);
  final SupabaseClient _c;

  String? get _uid => _c.auth.currentUser?.id;

  /// NOT: `posts` ile `profiles` arasında birden fazla ilişki var (yazar FK'sı
  /// ve post_likes üzerinden dolaylı yol). PostgREST'e hangisini istediğimizi
  /// açıkça söylemek için FK adını belirtiyoruz.
  static const String _postSelect =
      'id, body, image_path, kind, created_at, club_id, author_profile_id, '
      'profiles!posts_author_profile_id_fkey(full_name, avatar_path, username), '
      'clubs(name, logo_path)';

  /// Kişinin aktif bir kulüp üyeliği var mı?
  Future<bool> _hasActiveClub(String profileId) async {
    final row = await _c
        .from('club_memberships')
        .select('club_id')
        .eq('profile_id', profileId)
        .eq('status', 'active')
        .limit(1)
        .maybeSingle();
    return row != null;
  }

  /// Verilen kişilerden hangilerinin aktif kulüp üyeliği var?
  Future<Set<String>> _profilesWithClub(List<String> ids) async {
    if (ids.isEmpty) return <String>{};
    final rows = await _c
        .from('club_memberships')
        .select('profile_id')
        .inFilter('profile_id', ids)
        .eq('status', 'active');
    return {
      for (final r in rows as List) ((r as Map)['profile_id']) as String,
    };
  }

  /// Sporcu etiketi kurala göre türetilir: kulübü varsa lisanslı, yoksa ferdi.
  String _athleteLabel({required bool hasClub}) =>
      hasClub ? 'Lisanslı Sporcu' : 'Ferdi Sporcu';

  String? _publicUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    return _c.storage.from(kPostMediaBucket).getPublicUrl(path);
  }

  PostRow _toPost(Map<String, dynamic> m, Map<String, int> likes,
      Map<String, int> comments, Set<String> myLikes) {
    final prof = m['profiles'];
    final club = m['clubs'];
    final id = m['id'] as String;
    return PostRow(
      id: id,
      body: (m['body'] as String?) ?? '',
      createdAt:
          DateTime.tryParse('${m['created_at']}')?.toLocal() ?? DateTime.now(),
      authorId: m['author_profile_id'] as String,
      imageUrl: _publicUrl(m['image_path'] as String?),
      kind: (m['kind'] as String?) ?? 'post',
      clubId: m['club_id'] as String?,
      clubName: club is Map ? club['name'] as String? : null,
      authorName: prof is Map ? prof['full_name'] as String? : null,
      authorAvatarUrl:
          prof is Map ? _publicUrl(prof['avatar_path'] as String?) : null,
      likeCount: likes[id] ?? 0,
      commentCount: comments[id] ?? 0,
      likedByMe: myLikes.contains(id),
    );
  }

  /// Verilen gönderiler için beğeni/yorum sayıları ve "ben beğendim mi".
  Future<(Map<String, int>, Map<String, int>, Set<String>)> _stats(
      List<String> postIds) async {
    if (postIds.isEmpty) {
      return (<String, int>{}, <String, int>{}, <String>{});
    }
    final likeRows =
        await _c.from('post_likes').select('post_id, profile_id').inFilter(
              'post_id',
              postIds,
            );
    final commentRows =
        await _c.from('post_comments').select('post_id').inFilter(
              'post_id',
              postIds,
            );
    final likes = <String, int>{};
    final myLikes = <String>{};
    final uid = _uid;
    for (final r in likeRows as List) {
      final m = (r as Map).cast<String, dynamic>();
      final pid = m['post_id'] as String;
      likes[pid] = (likes[pid] ?? 0) + 1;
      if (uid != null && m['profile_id'] == uid) myLikes.add(pid);
    }
    final comments = <String, int>{};
    for (final r in commentRows as List) {
      final pid = ((r as Map)['post_id']) as String;
      comments[pid] = (comments[pid] ?? 0) + 1;
    }
    return (likes, comments, myLikes);
  }

  Future<List<PostRow>> _hydrate(List<dynamic> rows) async {
    final maps = rows
        .map((r) => (r as Map).cast<String, dynamic>())
        .toList(growable: false);
    final ids = maps.map((m) => m['id'] as String).toList();
    final (likes, comments, myLikes) = await _stats(ids);
    return maps.map((m) => _toPost(m, likes, comments, myLikes)).toList();
  }

  /// Ana akış: takip edilen kulüp/kişilerin gönderileri.
  /// Hiç takip yoksa (veya sonuç boşsa) keşfet akışına düşer.
  Future<List<PostRow>> feed({int limit = 50}) async {
    final uid = _uid;
    if (uid == null) return const [];

    final followRows = await _c
        .from('follows')
        .select('target_type, target_id')
        .eq('follower_id', uid);

    final clubIds = <String>[];
    final profileIds = <String>[uid]; // kendi gönderilerin de aksında
    for (final r in followRows as List) {
      final m = (r as Map).cast<String, dynamic>();
      if (m['target_type'] == 'club') {
        clubIds.add(m['target_id'] as String);
      } else {
        profileIds.add(m['target_id'] as String);
      }
    }

    // Kendi kulüplerin de takip ediliyor sayılır.
    final myClubs = await _c
        .from('club_memberships')
        .select('club_id')
        .eq('profile_id', uid)
        .eq('status', 'active');
    for (final r in myClubs as List) {
      final cid = ((r as Map)['club_id']) as String?;
      if (cid != null && !clubIds.contains(cid)) clubIds.add(cid);
    }

    // Takip akışı yalnızca takip edilenleri (ve kendini) gösterir; boşsa boş
    // döner — ekran o zaman takip önerileri sunar.
    final orParts = <String>[
      if (clubIds.isNotEmpty) 'club_id.in.(${clubIds.join(",")})',
      'author_profile_id.in.(${profileIds.join(",")})',
    ];
    final rows = await _c
        .from('posts')
        .select(_postSelect)
        .or(orParts.join(','))
        .order('created_at', ascending: false)
        .limit(limit);
    return _hydrate(rows as List);
  }

  /// Takip önerileri: onaylı kulüpler ve doğrulanmış kişiler.
  /// Zaten takip edilenler ve kişinin kendisi listeden çıkarılır.
  Future<List<SuggestionRow>> suggestions({int limit = 12}) async {
    final uid = _uid;
    if (uid == null) return const [];

    final followRows = await _c
        .from('follows')
        .select('target_type, target_id')
        .eq('follower_id', uid);
    final followedClubs = <String>{};
    final followedProfiles = <String>{};
    for (final r in followRows as List) {
      final m = (r as Map).cast<String, dynamic>();
      final id = m['target_id'] as String;
      if (m['target_type'] == 'club') {
        followedClubs.add(id);
      } else {
        followedProfiles.add(id);
      }
    }

    final out = <SuggestionRow>[];

    // Onaylı kulüpler
    final clubRows = await _c
        .from('clubs')
        .select('id, name, city, logo_path')
        .eq('status', 'active')
        .limit(limit);
    for (final r in clubRows as List) {
      final m = (r as Map).cast<String, dynamic>();
      final id = m['id'] as String;
      if (followedClubs.contains(id)) continue;
      out.add(SuggestionRow(
        id: id,
        name: (m['name'] as String?) ?? 'Kulüp',
        kind: 'club',
        subtitle: (m['city'] as String?) ?? 'Kulüp',
        avatarUrl: _publicUrl(m['logo_path'] as String?),
      ));
    }

    // Doğrulanmış kişiler (onaylı kimliği olanlar)
    final credRows = await _c
        .from('profile_credentials')
        .select('profile_id, kind, coach_level, sports(name)')
        .eq('status', 'approved')
        .limit(60);
    final labelById = <String, String>{};
    final kindById = <String, String>{};
    for (final r in credRows as List) {
      final m = (r as Map).cast<String, dynamic>();
      final pid = m['profile_id'] as String?;
      if (pid == null || pid == uid || followedProfiles.contains(pid)) continue;
      if (labelById.containsKey(pid)) continue;
      final kind = m['kind'] as String?;
      // Sporcu etiketi kulüp üyeliğinden türetilir; aşağıda doldurulur.
      labelById[pid] = kind == 'coach'
          ? _coachLabel(m)
          : '';
      kindById[pid] = kind == 'coach' ? 'coach' : 'athlete';
    }
    if (labelById.isNotEmpty) {
      final withClub = await _profilesWithClub(labelById.keys.toList());
      for (final pid in labelById.keys) {
        if (kindById[pid] == 'athlete') {
          labelById[pid] = _athleteLabel(hasClub: withClub.contains(pid));
        }
      }
      final profRows = await _c
          .from('profiles')
          .select('id, full_name, avatar_path')
          .inFilter('id', labelById.keys.toList());
      for (final r in profRows as List) {
        final m = (r as Map).cast<String, dynamic>();
        final id = m['id'] as String;
        final name = ((m['full_name'] as String?) ?? '').trim();
        out.add(SuggestionRow(
          id: id,
          name: name.isEmpty ? 'Kullanıcı' : name,
          kind: kindById[id] ?? 'person',
          subtitle: labelById[id],
          avatarUrl: _publicUrl(m['avatar_path'] as String?),
        ));
      }
    }

    return out.take(limit).toList();
  }

  /// Keşfet: tüm gönderiler (en yeni).
  Future<List<PostRow>> discover({int limit = 50}) async {
    final rows = await _c
        .from('posts')
        .select(_postSelect)
        .order('created_at', ascending: false)
        .limit(limit);
    return _hydrate(rows as List);
  }

  Future<List<PostRow>> postsByAuthor(String profileId) async {
    final rows = await _c
        .from('posts')
        .select(_postSelect)
        .eq('author_profile_id', profileId)
        .isFilter('club_id', null)
        .order('created_at', ascending: false);
    return _hydrate(rows as List);
  }

  Future<List<PostRow>> postsByClub(String clubId) async {
    final rows = await _c
        .from('posts')
        .select(_postSelect)
        .eq('club_id', clubId)
        .order('created_at', ascending: false);
    return _hydrate(rows as List);
  }

  /// Gönderi oluştur. [clubId] verilirse kulüp adına paylaşılır.
  /// Gönderi oluşturur ve kimliğini döner.
  ///
  /// [images] en fazla **8** görsel; ilki `posts.image_path`'e de yazılıyor
  /// ki eski akış kartları (tek görsel bekleyen kod) çalışmaya devam etsin.
  /// Gerisi `post_media`'ya sırasıyla giriyor.
  ///
  /// [visibility] verilmezse sunucu karar veriyor: reşit olmayan hesaplarda
  /// tetikleyici `public` yerine `followers` yazıyor.
  Future<String> createPost({
    required String body,
    String? clubId,
    Uint8List? imageBytes,
    String? imageName,
    String kind = 'post',
    List<PickedMedia> images = const [],
    String? visibility,
    String? teamId,
  }) async {
    final uid = _uid;
    if (uid == null) throw StateError('Oturum bulunamadı');

    // Tek görsellik eski çağrı biçimi hâlâ destekleniyor.
    final all = <PickedMedia>[
      if (imageBytes != null && imageName != null)
        PickedMedia(bytes: imageBytes, name: imageName),
      ...images,
    ];
    if (all.length > 8) {
      throw ArgumentError('Bir gönderiye en fazla 8 fotoğraf eklenebilir');
    }

    final paths = <String>[];
    for (var i = 0; i < all.length; i++) {
      final m = all[i];
      final dot = m.name.lastIndexOf('.');
      final ext = dot >= 0 ? m.name.substring(dot + 1).toLowerCase() : 'jpg';
      final path = '$uid/${DateTime.now().millisecondsSinceEpoch}_$i.$ext';
      await _c.storage.from(kPostMediaBucket).uploadBinary(
            path,
            m.bytes,
            fileOptions: const FileOptions(upsert: true),
          );
      paths.add(path);
    }

    final row = await _c
        .from('posts')
        .insert({
          'author_profile_id': uid,
          if (clubId != null) 'club_id': clubId,
          'body': body,
          if (paths.isNotEmpty) 'image_path': paths.first,
          'kind': kind,
          if (visibility != null) 'visibility': visibility,
          if (teamId != null) 'team_id': teamId,
        })
        .select('id')
        .single();

    final id = row['id'] as String;

    // İkinci görselden itibaren galeri. Sekiz sınırı hem burada hem
    // veritabanı tetikleyicisinde var (0062).
    if (paths.length > 1) {
      await _c.from('post_media').insert([
        for (var i = 0; i < paths.length; i++)
          {'post_id': id, 'media_path': paths[i], 'sort_order': i},
      ]);
    }

    return id;
  }

  Future<void> deletePost(String postId) async {
    await _c.from('posts').delete().eq('id', postId);
  }

  // ----------------------------- beğeni --------------------------------
  Future<void> setLike(String postId, bool liked) async {
    final uid = _uid;
    if (uid == null) return;
    if (liked) {
      await _c
          .from('post_likes')
          .upsert({'post_id': postId, 'profile_id': uid});
    } else {
      await _c
          .from('post_likes')
          .delete()
          .eq('post_id', postId)
          .eq('profile_id', uid);
    }
  }

  // ----------------------------- yorum ---------------------------------
  Future<List<CommentRow>> comments(String postId) async {
    final rows = await _c
        .from('post_comments')
        .select('id, body, created_at, profile_id, '
            'profiles!post_comments_profile_id_fkey(full_name, avatar_path)')
        .eq('post_id', postId)
        .order('created_at');
    return (rows as List).map((r) {
      final m = (r as Map).cast<String, dynamic>();
      final p = m['profiles'];
      return CommentRow(
        id: m['id'] as String,
        body: (m['body'] as String?) ?? '',
        createdAt: DateTime.tryParse('${m['created_at']}')?.toLocal() ??
            DateTime.now(),
        profileId: m['profile_id'] as String,
        authorName: p is Map ? p['full_name'] as String? : null,
        authorAvatarUrl:
            p is Map ? _publicUrl(p['avatar_path'] as String?) : null,
      );
    }).toList();
  }

  Future<void> addComment(String postId, String body) async {
    final uid = _uid;
    if (uid == null) return;
    await _c.from('post_comments').insert({
      'post_id': postId,
      'profile_id': uid,
      'body': body,
    });
  }

  Future<void> deleteComment(String id) async {
    await _c.from('post_comments').delete().eq('id', id);
  }

  // ----------------------------- takip ---------------------------------
  Future<void> setFollow(String targetType, String targetId, bool follow) async {
    final uid = _uid;
    if (uid == null) return;
    if (follow) {
      await _c.from('follows').upsert({
        'follower_id': uid,
        'target_type': targetType,
        'target_id': targetId,
      });
    } else {
      await _c
          .from('follows')
          .delete()
          .eq('follower_id', uid)
          .eq('target_type', targetType)
          .eq('target_id', targetId);
    }
  }

  // ----------------------------- profil --------------------------------
  Future<SocialProfile?> profile(String profileId) async {
    final uid = _uid;
    final row = await _c
        .from('profiles')
        .select('id, full_name, username, bio, avatar_path, city_code')
        .eq('id', profileId)
        .maybeSingle();
    if (row == null) return null;

    final creds = await _c
        .from('profile_credentials')
        .select('kind, coach_level, status, sports(name)')
        .eq('profile_id', profileId)
        .eq('status', 'approved');

    // Sporcunun "lisanslı" mı "ferdi" mi olduğu seçime değil, bir kulübe bağlı
    // olup olmamasına bağlıdır: kulübü varsa lisanslı, yoksa ferdi sporcudur.
    final hasClub = await _hasActiveClub(profileId);

    final labels = <String>[];
    for (final r in creds as List) {
      final m = (r as Map).cast<String, dynamic>();
      final kind = m['kind'] as String?;
      if (kind == 'coach') {
        labels.add(_coachLabel(m));
      } else {
        labels.add(hasClub ? 'Lisanslı Sporcu' : 'Ferdi Sporcu');
      }
    }

    final posts = await _c
        .from('posts')
        .select('id')
        .eq('author_profile_id', profileId)
        .isFilter('club_id', null);

    final followers = await _c
        .from('follows')
        .select('follower_id')
        .eq('target_type', 'profile')
        .eq('target_id', profileId);

    final following =
        await _c.from('follows').select('target_id').eq('follower_id', profileId);

    var followed = false;
    if (uid != null && uid != profileId) {
      final f = await _c
          .from('follows')
          .select('target_id')
          .eq('follower_id', uid)
          .eq('target_type', 'profile')
          .eq('target_id', profileId)
          .maybeSingle();
      followed = f != null;
    }

    // Kulüp rolü (varsa)
    String? roleLabel;
    final mem = await _c
        .from('club_memberships')
        .select('role, clubs(name)')
        .eq('profile_id', profileId)
        .eq('status', 'active')
        .limit(1)
        .maybeSingle();
    if (mem != null) {
      final club = mem['clubs'];
      final role = switch (mem['role'] as String?) {
        'club_admin' => 'Yönetici',
        'coach' => 'Antrenör',
        'athlete' => 'Sporcu',
        'parent' => 'Veli',
        _ => 'Üye',
      };
      final cn = club is Map ? club['name'] as String? : null;
      roleLabel = cn != null ? '$role · $cn' : role;
    }

    return SocialProfile(
      id: profileId,
      name: ((row['full_name'] as String?) ?? '').trim().isEmpty
          ? 'Kullanıcı'
          : row['full_name'] as String,
      isClub: false,
      username: row['username'] as String?,
      bio: row['bio'] as String?,
      avatarUrl: _publicUrl(row['avatar_path'] as String?),
      roleLabel: roleLabel,
      cityCode: row['city_code'] as String?,
      postCount: (posts as List).length,
      followerCount: (followers as List).length,
      followingCount: (following as List).length,
      isFollowedByMe: followed,
      isMe: uid == profileId,
      credentials: labels,
    );
  }

  Future<SocialProfile?> clubProfile(String clubId) async {
    final uid = _uid;
    final row = await _c
        .from('clubs')
        .select('id, name, city, bio, logo_path, status')
        .eq('id', clubId)
        .maybeSingle();
    if (row == null) return null;

    final posts =
        await _c.from('posts').select('id').eq('club_id', clubId);
    final followers = await _c
        .from('follows')
        .select('follower_id')
        .eq('target_type', 'club')
        .eq('target_id', clubId);

    var followed = false;
    if (uid != null) {
      final f = await _c
          .from('follows')
          .select('target_id')
          .eq('follower_id', uid)
          .eq('target_type', 'club')
          .eq('target_id', clubId)
          .maybeSingle();
      followed = f != null;
    }

    return SocialProfile(
      id: clubId,
      name: (row['name'] as String?) ?? 'Kulüp',
      isClub: true,
      bio: row['bio'] as String?,
      avatarUrl: _publicUrl(row['logo_path'] as String?),
      roleLabel: row['city'] as String?,
      postCount: (posts as List).length,
      followerCount: (followers as List).length,
      isFollowedByMe: followed,
      credentials:
          (row['status'] as String?) == 'active' ? const ['Onaylı Kulüp'] : const [],
    );
  }

  /// Profil bilgilerini güncelle (biyografi, kullanıcı adı, avatar, şehir).
  Future<void> updateProfile({
    String? fullName,
    String? username,
    String? bio,
    Uint8List? avatarBytes,
    String? avatarName,
    String? cityCode,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    String? path;
    if (avatarBytes != null && avatarName != null) {
      final dot = avatarName.lastIndexOf('.');
      final ext =
          dot >= 0 ? avatarName.substring(dot + 1).toLowerCase() : 'jpg';
      path = '$uid/avatar_${DateTime.now().millisecondsSinceEpoch}.$ext';
      await _c.storage.from(kPostMediaBucket).uploadBinary(
            path,
            avatarBytes,
            fileOptions: const FileOptions(upsert: true),
          );
    }
    await _c.from('profiles').update({
      if (fullName != null && fullName.trim().isNotEmpty)
        'full_name': fullName.trim(),
      if (username != null) 'username': username.trim().isEmpty ? null : username.trim(),
      if (bio != null) 'bio': bio.trim().isEmpty ? null : bio.trim(),
      if (path != null) 'avatar_path': path,
      if (cityCode != null) 'city_code': cityCode.isEmpty ? null : cityCode,
    }).eq('id', uid);
  }

  /// Bir profili takip edenler.
  Future<List<SuggestionRow>> followers(String profileId) async {
    final rows = await _c
        .from('follows')
        .select('follower_id')
        .eq('target_type', 'profile')
        .eq('target_id', profileId);
    final ids = (rows as List)
        .map((r) => ((r as Map)['follower_id']) as String)
        .toList();
    return _peopleByIds(ids);
  }

  /// Bir profilin takip ettikleri (kişiler + kulüpler).
  Future<List<SuggestionRow>> following(String profileId) async {
    final rows = await _c
        .from('follows')
        .select('target_type, target_id')
        .eq('follower_id', profileId);

    final profileIds = <String>[];
    final clubIds = <String>[];
    for (final r in rows as List) {
      final m = (r as Map).cast<String, dynamic>();
      if (m['target_type'] == 'club') {
        clubIds.add(m['target_id'] as String);
      } else {
        profileIds.add(m['target_id'] as String);
      }
    }

    final out = <SuggestionRow>[];
    if (clubIds.isNotEmpty) {
      final clubs = await _c
          .from('clubs')
          .select('id, name, city, logo_path')
          .inFilter('id', clubIds);
      for (final r in clubs as List) {
        final m = (r as Map).cast<String, dynamic>();
        out.add(SuggestionRow(
          id: m['id'] as String,
          name: (m['name'] as String?) ?? 'Kulüp',
          kind: 'club',
          subtitle: (m['city'] as String?) ?? 'Kulüp',
          avatarUrl: _publicUrl(m['logo_path'] as String?),
        ));
      }
    }
    out.addAll(await _peopleByIds(profileIds));
    return out;
  }

  /// Kimlik etiketleriyle birlikte kişi listesi.
  Future<List<SuggestionRow>> _peopleByIds(List<String> ids) async {
    if (ids.isEmpty) return const [];
    final profs = await _c
        .from('profiles')
        .select('id, full_name, username, avatar_path')
        .inFilter('id', ids);

    final creds = await _c
        .from('profile_credentials')
        .select('profile_id, kind, coach_level, sports(name)')
        .inFilter('profile_id', ids)
        .eq('status', 'approved');

    final labelById = <String, String>{};
    final kindById = <String, String>{};
    for (final r in creds as List) {
      final m = (r as Map).cast<String, dynamic>();
      final pid = m['profile_id'] as String;
      if (labelById.containsKey(pid)) continue;
      final k = m['kind'] as String?;
      labelById[pid] =
          k == 'coach' ? _coachLabel(m) : '';
      kindById[pid] = k == 'coach' ? 'coach' : 'athlete';
    }
    final withClub = await _profilesWithClub(
        kindById.entries.where((e) => e.value == 'athlete').map((e) => e.key).toList());
    for (final e in kindById.entries) {
      if (e.value == 'athlete') {
        labelById[e.key] = _athleteLabel(hasClub: withClub.contains(e.key));
      }
    }

    return (profs as List).map((r) {
      final m = (r as Map).cast<String, dynamic>();
      final id = m['id'] as String;
      final name = ((m['full_name'] as String?) ?? '').trim();
      final username = m['username'] as String?;
      return SuggestionRow(
        id: id,
        name: name.isEmpty ? 'Kullanıcı' : name,
        kind: kindById[id] ?? 'person',
        subtitle: labelById[id]?.isNotEmpty == true
            ? labelById[id]
            : (username != null && username.isNotEmpty ? '@$username' : 'Üye'),
        avatarUrl: _publicUrl(m['avatar_path'] as String?),
      );
    }).toList();
  }

  /// Kulübün aktif üyeleri (rolleriyle).
  Future<List<({String id, String name, String role, String? avatarUrl})>>
      clubMembers(String clubId) async {
    final rows = await _c
        .from('club_memberships')
        .select('role, profile_id, profiles(full_name, avatar_path)')
        .eq('club_id', clubId)
        .eq('status', 'active');
    return (rows as List).map((r) {
      final m = (r as Map).cast<String, dynamic>();
      final p = m['profiles'];
      final name = p is Map ? ((p['full_name'] as String?) ?? '').trim() : '';
      return (
        id: m['profile_id'] as String,
        name: name.isEmpty ? 'Üye' : name,
        role: switch (m['role'] as String?) {
          'club_admin' => 'Yönetici',
          'coach' => 'Antrenör',
          'athlete' => 'Sporcu',
          'parent' => 'Veli',
          _ => 'Üye',
        },
        avatarUrl:
            p is Map ? _publicUrl(p['avatar_path'] as String?) : null,
      );
    }).toList();
  }

  /// Antrenörün kulüp geçmişi (kademe ve katılım tarihiyle).
  Future<List<({String clubId, String clubName, int? level, DateTime? since})>>
      coachClubs(String profileId) async {
    final rows = await _c
        .from('club_memberships')
        .select('club_id, coach_level, created_at, clubs(name)')
        .eq('profile_id', profileId)
        .eq('status', 'active')
        .inFilter('role', ['coach', 'club_admin']);
    return (rows as List).map((r) {
      final m = (r as Map).cast<String, dynamic>();
      final c = m['clubs'];
      return (
        clubId: m['club_id'] as String,
        clubName: (c is Map ? c['name'] as String? : null) ?? 'Kulüp',
        level: m['coach_level'] as int?,
        since: DateTime.tryParse('${m['created_at']}'),
      );
    }).toList();
  }

  /// Gönderi metnini günceller (yalnızca sahibi — RLS denetler).
  Future<void> updatePost(String postId, String body) async {
    await _c.from('posts').update({'body': body.trim()}).eq('id', postId);
  }

  /// Kulüp, antrenör ve sporcu araması.
  ///
  /// Boş sorguda kulüpler + doğrulanmış kişiler listelenir (keşfe açılış).
  Future<List<SuggestionRow>> search(String query) async {
    // PostgREST'in `or(...)` sözdizimini bozabilecek karakterleri ayıkla.
    final q = query.trim().replaceAll(RegExp(r'[,()*%]'), '');
    final out = <SuggestionRow>[];

    // --- Kulüpler ---
    var clubQuery = _c.from('clubs').select('id, name, city, logo_path');
    if (q.isNotEmpty) clubQuery = clubQuery.ilike('name', '%$q%');
    final clubRows = await clubQuery.limit(20);
    for (final r in clubRows as List) {
      final m = (r as Map).cast<String, dynamic>();
      out.add(SuggestionRow(
        id: m['id'] as String,
        name: (m['name'] as String?) ?? 'Kulüp',
        kind: 'club',
        subtitle: (m['city'] as String?) ?? 'Kulüp',
        avatarUrl: _publicUrl(m['logo_path'] as String?),
      ));
    }

    // --- Kişiler ---
    var profQuery =
        _c.from('profiles').select('id, full_name, username, avatar_path');
    if (q.isNotEmpty) {
      profQuery = profQuery.or('full_name.ilike.%$q%,username.ilike.%$q%');
    }
    final profRows = await profQuery.limit(30);
    final people = (profRows as List)
        .map((r) => (r as Map).cast<String, dynamic>())
        .toList();

    if (people.isNotEmpty) {
      // Kişileri kademe/lisans bilgisiyle etiketle (antrenör mü sporcu mu).
      final ids = people.map((m) => m['id'] as String).toList();
      final credRows = await _c
          .from('profile_credentials')
          .select('profile_id, kind, coach_level, sports(name)')
          .inFilter('profile_id', ids)
          .eq('status', 'approved');
      final labelById = <String, String>{};
      final kindById = <String, String>{};
      for (final r in credRows as List) {
        final m = (r as Map).cast<String, dynamic>();
        final pid = m['profile_id'] as String;
        if (labelById.containsKey(pid)) continue;
        final k = m['kind'] as String?;
        labelById[pid] = k == 'coach'
            ? _coachLabel(m)
            : '';
        kindById[pid] = k == 'coach' ? 'coach' : 'athlete';
      }

      // Sporcularda etiket kulüp üyeliğine göre belirlenir.
      final withClub = await _profilesWithClub(
          kindById.entries.where((e) => e.value == 'athlete').map((e) => e.key).toList());
      for (final e in kindById.entries) {
        if (e.value == 'athlete') {
          labelById[e.key] = _athleteLabel(hasClub: withClub.contains(e.key));
        }
      }

      for (final m in people) {
        final id = m['id'] as String;
        final name = ((m['full_name'] as String?) ?? '').trim();
        final username = m['username'] as String?;
        out.add(SuggestionRow(
          id: id,
          name: name.isEmpty ? 'Kullanıcı' : name,
          kind: kindById[id] ?? 'person',
          subtitle: labelById[id] ??
              (username != null && username.isNotEmpty ? '@$username' : 'Üye'),
          avatarUrl: _publicUrl(m['avatar_path'] as String?),
        ));
      }
    }

    return out;
  }
}

// =============================== Provider'lar ==============================

final socialServiceProvider = Provider<SocialService>((ref) {
  return SocialService(ref.watch(supabaseClientProvider));
});

/// Ana akış.
final feedProvider = FutureProvider.autoDispose<List<PostRow>>((ref) {
  if (!ref.watch(isSupabaseEnabledProvider)) return Future.value(const []);
  return ref.watch(socialServiceProvider).feed();
});

/// Keşfet akışı.
final discoverProvider = FutureProvider.autoDispose<List<PostRow>>((ref) {
  if (!ref.watch(isSupabaseEnabledProvider)) return Future.value(const []);
  return ref.watch(socialServiceProvider).discover();
});

/// Takip önerileri (akış boşken gösterilir).
final suggestionsProvider =
    FutureProvider.autoDispose<List<SuggestionRow>>((ref) {
  if (!ref.watch(isSupabaseEnabledProvider)) return Future.value(const []);
  return ref.watch(socialServiceProvider).suggestions();
});

/// Bir profilin sosyal bilgileri.
final socialProfileProvider =
    FutureProvider.autoDispose.family<SocialProfile?, String>((ref, id) {
  if (!ref.watch(isSupabaseEnabledProvider)) return Future.value(null);
  return ref.watch(socialServiceProvider).profile(id);
});

/// Bir kulübün sosyal bilgileri.
final clubSocialProfileProvider =
    FutureProvider.autoDispose.family<SocialProfile?, String>((ref, id) {
  if (!ref.watch(isSupabaseEnabledProvider)) return Future.value(null);
  return ref.watch(socialServiceProvider).clubProfile(id);
});

/// Bir kişinin gönderileri.
final authorPostsProvider =
    FutureProvider.autoDispose.family<List<PostRow>, String>((ref, id) {
  if (!ref.watch(isSupabaseEnabledProvider)) return Future.value(const []);
  return ref.watch(socialServiceProvider).postsByAuthor(id);
});

/// Bir kulübün gönderileri.
final clubPostsProvider =
    FutureProvider.autoDispose.family<List<PostRow>, String>((ref, id) {
  if (!ref.watch(isSupabaseEnabledProvider)) return Future.value(const []);
  return ref.watch(socialServiceProvider).postsByClub(id);
});

/// Bir profili takip edenler.
final followersProvider =
    FutureProvider.autoDispose.family<List<SuggestionRow>, String>((ref, id) {
  if (!ref.watch(isSupabaseEnabledProvider)) return Future.value(const []);
  return ref.watch(socialServiceProvider).followers(id);
});

/// Bir profilin takip ettikleri.
final followingProvider =
    FutureProvider.autoDispose.family<List<SuggestionRow>, String>((ref, id) {
  if (!ref.watch(isSupabaseEnabledProvider)) return Future.value(const []);
  return ref.watch(socialServiceProvider).following(id);
});

/// Kulübün aktif üyeleri.
final clubMembersProvider = FutureProvider.autoDispose
    .family<List<({String id, String name, String role, String? avatarUrl})>,
        String>((ref, id) {
  if (!ref.watch(isSupabaseEnabledProvider)) return Future.value(const []);
  return ref.watch(socialServiceProvider).clubMembers(id);
});

/// Antrenörün kulüpleri.
final coachClubsProvider = FutureProvider.autoDispose.family<
    List<({String clubId, String clubName, int? level, DateTime? since})>,
    String>((ref, id) {
  if (!ref.watch(isSupabaseEnabledProvider)) return Future.value(const []);
  return ref.watch(socialServiceProvider).coachClubs(id);
});

/// Bir gönderinin yorumları.
final postCommentsProvider =
    FutureProvider.autoDispose.family<List<CommentRow>, String>((ref, id) {
  if (!ref.watch(isSupabaseEnabledProvider)) return Future.value(const []);
  return ref.watch(socialServiceProvider).comments(id);
});
