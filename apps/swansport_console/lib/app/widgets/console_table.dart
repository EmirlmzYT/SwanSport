import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/console_theme.dart';

/// Bir tablo sütununun tanımı.
///
/// `sortKey` verilmişse sütun başlığı tıklanabilir olur ve sıralama
/// **sunucuya** gider — tarayıcıdaki sayfayı sıralamak, 200 kişilik kadronun
/// yalnızca görünen 50'sini sıralamak demek olurdu ki yanıltıcıdır.
class ConsoleColumn<T> {
  const ConsoleColumn({
    required this.label,
    required this.cell,
    this.sortKey,
    this.width,
    this.flex = 1,
    this.align = Alignment.centerLeft,
    this.csv,
    this.numeric = false,
  });

  final String label;

  /// Hücre içeriği.
  final Widget Function(T row) cell;

  /// Sunucu tarafı sıralama anahtarı (veritabanı sütun adı). null = sıralanamaz.
  final String? sortKey;

  /// Sabit genişlik; null ise [flex] kullanılır.
  final double? width;
  final int flex;
  final Alignment align;

  /// CSV'ye yazılacak düz metin. Verilmezse sütun dışa aktarmaya girmez.
  final String Function(T row)? csv;

  /// Rakam sütunu — hizalama ve tabular rakamlar için.
  final bool numeric;
}

/// Tablo durumu: hangi sayfa, hangi sıralama, hangi arama.
@immutable
class ConsoleTableQuery {
  const ConsoleTableQuery({
    this.page = 0,
    this.pageSize = 50,
    this.sortKey,
    this.ascending = true,
    this.search = '',
  });

  final int page;
  final int pageSize;
  final String? sortKey;
  final bool ascending;
  final String search;

  int get offset => page * pageSize;

  ConsoleTableQuery copyWith({
    int? page,
    int? pageSize,
    String? sortKey,
    bool? ascending,
    String? search,
  }) =>
      ConsoleTableQuery(
        page: page ?? this.page,
        pageSize: pageSize ?? this.pageSize,
        sortKey: sortKey ?? this.sortKey,
        ascending: ascending ?? this.ascending,
        search: search ?? this.search,
      );

  @override
  bool operator ==(Object other) =>
      other is ConsoleTableQuery &&
      other.page == page &&
      other.pageSize == pageSize &&
      other.sortKey == sortKey &&
      other.ascending == ascending &&
      other.search == search;

  @override
  int get hashCode => Object.hash(page, pageSize, sortKey, ascending, search);
}

/// Yoğun veri tablosu.
///
/// Konsolun omurgası. Sıralama, sayfalama ve arama **sunucuda** yapılır;
/// bu widget yalnızca gelen sayfayı çizer ve niyetleri yukarı bildirir.
class ConsoleTable<T> extends StatelessWidget {
  const ConsoleTable({
    required this.columns,
    required this.rows,
    required this.query,
    required this.totalCount,
    required this.onQueryChanged,
    required this.rowId,
    this.selected = const {},
    this.onSelectionChanged,
    this.onRowTap,
    this.loading = false,
    this.error,
    this.emptyMessage = 'Kayıt yok.',
    this.bulkActions = const [],
    super.key,
  });

  final List<ConsoleColumn<T>> columns;
  final List<T> rows;
  final ConsoleTableQuery query;

  /// Süzgece uyan toplam satır sayısı (yalnızca bu sayfa değil).
  final int totalCount;

  final ValueChanged<ConsoleTableQuery> onQueryChanged;

  /// Satırın kalıcı kimliği — seçim sayfa değişince de doğru satırı tutsun.
  final String Function(T row) rowId;

  final Set<String> selected;
  final ValueChanged<Set<String>>? onSelectionChanged;
  final void Function(T row)? onRowTap;

  final bool loading;
  final Object? error;
  final String emptyMessage;

  /// Seçim varken beliren işlemler.
  final List<ConsoleBulkAction> bulkActions;

  bool get _selectable => onSelectionChanged != null;

  int get _pageCount =>
      totalCount == 0 ? 1 : ((totalCount - 1) ~/ query.pageSize) + 1;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    return Column(
      children: [
        if (_selectable && selected.isNotEmpty)
          _BulkBar(
            count: selected.length,
            actions: bulkActions,
            onClear: () => onSelectionChanged!(const {}),
          ),
        _header(context),
        Divider(height: 1, color: t.colorScheme.outline),
        Expanded(child: _body(context)),
        Divider(height: 1, color: t.colorScheme.outline),
        _footer(context),
      ],
    );
  }

  // ------------------------------------------------------------------ başlık
  Widget _header(BuildContext context) {
    final t = Theme.of(context);

    return Container(
      height: ConsoleDensity.headerHeight,
      color: t.colorScheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: ConsoleDensity.lg),
      child: Row(
        children: [
          if (_selectable)
            SizedBox(
              width: 34,
              child: Checkbox(
                value: rows.isNotEmpty &&
                    rows.every((r) => selected.contains(rowId(r))),
                tristate: true,
                onChanged: (_) {
                  final ids = rows.map(rowId).toSet();
                  final allSelected = ids.every(selected.contains);
                  final next = Set<String>.from(selected);
                  if (allSelected) {
                    next.removeAll(ids);
                  } else {
                    next.addAll(ids);
                  }
                  onSelectionChanged!(next);
                },
              ),
            ),
          for (final c in columns) _headerCell(context, c),
        ],
      ),
    );
  }

  Widget _headerCell(BuildContext context, ConsoleColumn<T> c) {
    final t = Theme.of(context);
    final active = c.sortKey != null && c.sortKey == query.sortKey;

    final content = Row(
      mainAxisAlignment: c.numeric || c.align == Alignment.centerRight
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      children: [
        Flexible(
          child: Text(
            c.label.toUpperCase(),
            overflow: TextOverflow.ellipsis,
            style: t.textTheme.labelSmall?.copyWith(
              color: active ? t.colorScheme.primary : null,
              fontWeight: active ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ),
        if (active)
          Icon(
            query.ascending
                ? Icons.arrow_upward_rounded
                : Icons.arrow_downward_rounded,
            size: 13,
            color: t.colorScheme.primary,
          ),
      ],
    );

    final cell = c.sortKey == null
        ? content
        : InkWell(
            onTap: () => onQueryChanged(
              query.copyWith(
                sortKey: c.sortKey,
                // Aynı sütuna tekrar basmak yönü çevirir.
                ascending: active ? !query.ascending : true,
                page: 0,
              ),
            ),
            child: content,
          );

    return c.width != null
        ? SizedBox(width: c.width, child: cell)
        : Expanded(flex: c.flex, child: cell);
  }

  // ------------------------------------------------------------------ gövde
  Widget _body(BuildContext context) {
    final t = Theme.of(context);

    if (error != null) {
      return _Message(
        icon: Icons.error_outline_rounded,
        color: t.colorScheme.error,
        title: 'Veri alınamadı',
        detail: '$error',
      );
    }
    if (loading && rows.isEmpty) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (rows.isEmpty) {
      return _Message(
        icon: Icons.inbox_rounded,
        color: t.colorScheme.outline,
        title: emptyMessage,
        detail: query.search.isEmpty
            ? null
            : '"${query.search}" aramasıyla eşleşen kayıt yok.',
      );
    }

    return Stack(
      children: [
        ListView.separated(
          itemCount: rows.length,
          separatorBuilder: (_, __) =>
              Divider(height: 1, color: t.colorScheme.outline),
          itemBuilder: (context, i) => _row(context, rows[i]),
        ),
        // Sayfa değişirken eski satırlar görünür kalsın, ama devam eden bir iş
        // olduğu da belli olsun.
        if (loading)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(minHeight: 2),
          ),
      ],
    );
  }

  Widget _row(BuildContext context, T row) {
    final t = Theme.of(context);
    final id = rowId(row);
    final isSelected = selected.contains(id);

    return InkWell(
      onTap: onRowTap == null ? null : () => onRowTap!(row),
      child: Container(
        height: ConsoleDensity.rowHeight,
        color: isSelected
            ? t.colorScheme.primary.withValues(alpha: .06)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: ConsoleDensity.lg),
        child: Row(
          children: [
            if (_selectable)
              SizedBox(
                width: 34,
                child: Checkbox(
                  value: isSelected,
                  onChanged: (v) {
                    final next = Set<String>.from(selected);
                    if (v ?? false) {
                      next.add(id);
                    } else {
                      next.remove(id);
                    }
                    onSelectionChanged!(next);
                  },
                ),
              ),
            for (final c in columns)
              c.width != null
                  ? SizedBox(
                      width: c.width,
                      child: Align(alignment: c.align, child: c.cell(row)))
                  : Expanded(
                      flex: c.flex,
                      child: Align(alignment: c.align, child: c.cell(row))),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ altlık
  Widget _footer(BuildContext context) {
    final t = Theme.of(context);
    final from = totalCount == 0 ? 0 : query.offset + 1;
    final to = query.offset + rows.length;

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: ConsoleDensity.lg),
      color: t.colorScheme.surface,
      child: Row(
        children: [
          Text(
            totalCount == 0 ? '0 kayıt' : '$from–$to / $totalCount kayıt',
            style: t.textTheme.bodySmall,
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Önceki sayfa',
            icon: const Icon(Icons.chevron_left_rounded, size: 20),
            onPressed: query.page == 0
                ? null
                : () => onQueryChanged(query.copyWith(page: query.page - 1)),
          ),
          Text('${query.page + 1} / $_pageCount',
              style: t.textTheme.bodySmall),
          IconButton(
            tooltip: 'Sonraki sayfa',
            icon: const Icon(Icons.chevron_right_rounded, size: 20),
            onPressed: query.page + 1 >= _pageCount
                ? null
                : () => onQueryChanged(query.copyWith(page: query.page + 1)),
          ),
        ],
      ),
    );
  }
}

/// Seçim varken beliren toplu işlem.
class ConsoleBulkAction {
  const ConsoleBulkAction({
    required this.label,
    required this.icon,
    required this.onRun,
    this.destructive = false,
  });

  final String label;
  final IconData icon;
  final Future<void> Function() onRun;
  final bool destructive;
}

class _BulkBar extends StatelessWidget {
  const _BulkBar({
    required this.count,
    required this.actions,
    required this.onClear,
  });

  final int count;
  final List<ConsoleBulkAction> actions;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: ConsoleDensity.lg),
      color: t.colorScheme.primary.withValues(alpha: .10),
      child: Row(
        children: [
          Text('$count seçili',
              style: t.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(width: ConsoleDensity.lg),
          for (final a in actions) ...[
            TextButton.icon(
              onPressed: a.onRun,
              icon: Icon(a.icon, size: 17),
              label: Text(a.label),
              style: TextButton.styleFrom(
                foregroundColor:
                    a.destructive ? t.colorScheme.error : t.colorScheme.primary,
              ),
            ),
            const SizedBox(width: ConsoleDensity.xs),
          ],
          const Spacer(),
          TextButton(onPressed: onClear, child: const Text('Seçimi bırak')),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.color,
    required this.title,
    this.detail,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 26, color: color),
            const SizedBox(height: ConsoleDensity.md),
            Text(title,
                textAlign: TextAlign.center, style: t.textTheme.titleMedium),
            if (detail != null) ...[
              const SizedBox(height: ConsoleDensity.xs),
              SelectableText(
                detail!,
                textAlign: TextAlign.center,
                style: t.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Tablonun üstündeki araç çubuğu — arama, süzgeçler, dışa aktarma.
class ConsoleToolbar extends StatelessWidget {
  const ConsoleToolbar({
    required this.query,
    required this.onQueryChanged,
    this.searchHint = 'Ara…',
    this.filters = const [],
    this.onExport,
    this.trailing,
    super.key,
  });

  final ConsoleTableQuery query;
  final ValueChanged<ConsoleTableQuery> onQueryChanged;
  final String searchHint;
  final List<Widget> filters;
  final Future<void> Function()? onExport;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: ConsoleDensity.lg, vertical: ConsoleDensity.md),
      child: Row(
        children: [
          SizedBox(
            width: 280,
            child: _SearchField(
              hint: searchHint,
              initial: query.search,
              onSubmitted: (v) =>
                  onQueryChanged(query.copyWith(search: v, page: 0)),
            ),
          ),
          const SizedBox(width: ConsoleDensity.md),
          for (final f in filters) ...[
            f,
            const SizedBox(width: ConsoleDensity.sm),
          ],
          const Spacer(),
          if (trailing != null) ...[
            trailing!,
            const SizedBox(width: ConsoleDensity.sm),
          ],
          if (onExport != null)
            OutlinedButton.icon(
              onPressed: onExport,
              icon: const Icon(Icons.download_rounded, size: 17),
              label: const Text('CSV'),
            ),
        ],
      ),
    );
  }
}

class _SearchField extends StatefulWidget {
  const _SearchField({
    required this.hint,
    required this.initial,
    required this.onSubmitted,
  });

  final String hint;
  final String initial;
  final ValueChanged<String> onSubmitted;

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  late final TextEditingController _c =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _c,
      // Her tuşta sunucuya gitmiyoruz; enter'a basınca arıyor. Yoğun tabloda
      // her harf için sorgu atmak hem sunucuyu hem kullanıcıyı yorar.
      onSubmitted: widget.onSubmitted,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: widget.hint,
        prefixIcon: const Icon(Icons.search_rounded, size: 18),
        suffixIcon: _c.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close_rounded, size: 16),
                onPressed: () {
                  _c.clear();
                  widget.onSubmitted('');
                },
              ),
      ),
      inputFormatters: [LengthLimitingTextInputFormatter(80)],
    );
  }
}
