import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_core/swansport_core.dart';
import 'package:swansport_data/swansport_data.dart';

import '../design/swan_palette.dart';
import '../design/swan_shape.dart';
import '../design/swan_type.dart';

/// Tüm uygulama ekosisteminde standart şehir seçici dialog/sheet'i.
/// 81 ili plakasıyla birlikte listeler ve anlık arama sunar.
Future<CityRow?> showSwanCityPicker(
  BuildContext context, {
  String? selectedCity,
  String? selectedCode,
}) =>
    showModalBottomSheet<CityRow?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SwanCityPickerSheet(
        selectedCity: selectedCity,
        selectedCode: selectedCode,
      ),
    );

class _SwanCityPickerSheet extends ConsumerStatefulWidget {
  const _SwanCityPickerSheet({
    this.selectedCity,
    this.selectedCode,
  });

  final String? selectedCity;
  final String? selectedCode;

  @override
  ConsumerState<_SwanCityPickerSheet> createState() =>
      _SwanCityPickerSheetState();
}

class _SwanCityPickerSheetState extends ConsumerState<_SwanCityPickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  static const _popularCities = [
    ('34', 'İstanbul'),
    ('06', 'Ankara'),
    ('35', 'İzmir'),
    ('16', 'Bursa'),
    ('07', 'Antalya'),
    ('01', 'Adana'),
    ('42', 'Konya'),
    ('27', 'Gaziantep'),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    final cities = ref.watch(citiesProvider).valueOrNull ?? kTurkeyCities;

    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? cities
        : cities.where((city) {
            final nameMatch = trContains(city.name, q);
            final codeMatch = city.code.contains(q);
            return nameMatch || codeMatch;
          }).toList();

    return Container(
      height: MediaQuery.sizeOf(context).height * 0.75,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(SwanRadius.lg),
        ),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: SwanSpace.sm),
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: c.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                SwanSpace.lg,
                SwanSpace.md,
                SwanSpace.lg,
                SwanSpace.sm,
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: c.accent.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.location_city_rounded,
                      color: c.accent,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: SwanSpace.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Şehir Seçiniz', style: SwanType.h3(c.ink)),
                        Text(
                          '81 il listesinden arayın veya seçin',
                          style: SwanType.caption(c.inkMuted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: c.inkMuted),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Arama kutusu
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: SwanSpace.lg),
              child: TextField(
                controller: _searchController,
                autofocus: false,
                onChanged: (v) => setState(() => _query = v),
                style: SwanType.bodySm(c.ink),
                decoration: InputDecoration(
                  hintText: 'Şehir adı veya plaka ara (örn: 34, İzmir)...',
                  hintStyle: SwanType.bodySm(c.inkMuted),
                  prefixIcon:
                      Icon(Icons.search_rounded, size: 20, color: c.inkMuted),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: c.surfaceAlt,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: SwanSpace.md,
                    vertical: SwanSpace.sm,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(SwanRadius.md),
                    borderSide: BorderSide(color: c.line),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(SwanRadius.md),
                    borderSide: BorderSide(color: c.line),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(SwanRadius.md),
                    borderSide: BorderSide(color: c.accent, width: 1.5),
                  ),
                ),
              ),
            ),

            // Popüler şehirler hızlı seçim
            if (_query.isEmpty) ...[
              const SizedBox(height: SwanSpace.sm),
              SizedBox(
                height: 34,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: SwanSpace.lg),
                  children: [
                    for (final pop in _popularCities)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ActionChip(
                          avatar: Text(
                            pop.$1,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: c.inkMuted,
                            ),
                          ),
                          label: Text(
                            pop.$2,
                            style: SwanType.caption(c.ink, w: FontWeight.w600),
                          ),
                          backgroundColor: c.surfaceAlt,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: c.line),
                          ),
                          onPressed: () {
                            final match = cities
                                .where((ci) => ci.code == pop.$1)
                                .firstOrNull;
                            if (match != null) {
                              Navigator.pop(context, match);
                            } else {
                              Navigator.pop(
                                context,
                                CityRow(code: pop.$1, name: pop.$2),
                              );
                            }
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: SwanSpace.xs),
            const Divider(height: 1),

            // Şehir Listesi
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.location_off_rounded,
                              size: 32, color: c.inkMuted),
                          const SizedBox(height: SwanSpace.xs),
                          Text('Şehir bulunamadı',
                              style: SwanType.caption(c.inkMuted)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (ctx, index) {
                        final city = filtered[index];
                        final isSelected = (widget.selectedCode != null &&
                                widget.selectedCode == city.code) ||
                            (widget.selectedCity != null &&
                                widget.selectedCity!.toLowerCase() ==
                                    city.name.toLowerCase());

                        return ListTile(
                          dense: true,
                          leading: Container(
                            width: 32,
                            height: 24,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? c.accent.withValues(alpha: 0.15)
                                  : c.surfaceAlt,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: isSelected ? c.accent : c.line,
                              ),
                            ),
                            child: Text(
                              city.code,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? c.accent : c.inkMuted,
                              ),
                            ),
                          ),
                          title: Text(
                            city.name,
                            style: SwanType.bodySm(
                              isSelected ? c.accent : c.ink,
                              w: isSelected ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                          trailing: isSelected
                              ? Icon(Icons.check_circle_rounded,
                                  color: c.accent, size: 20)
                              : null,
                          onTap: () => Navigator.pop(context, city),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Formlarda tek satırda şehir seçtiren standart widget.
class SwanCityFormField extends StatelessWidget {
  const SwanCityFormField({
    super.key,
    required this.selectedCity,
    this.selectedCode,
    required this.onChanged,
    this.label = 'Şehir',
    this.hint = 'Şehir seçiniz',
  });

  final String? selectedCity;
  final String? selectedCode;
  final ValueChanged<CityRow?> onChanged;
  final String label;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    final hasSelection =
        selectedCity != null && selectedCity!.trim().isNotEmpty;

    return InkWell(
      borderRadius: BorderRadius.circular(SwanRadius.md),
      onTap: () async {
        final picked = await showSwanCityPicker(
          context,
          selectedCity: selectedCity,
          selectedCode: selectedCode,
        );
        if (picked != null) {
          onChanged(picked);
        }
      },
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: SwanSpace.md),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(SwanRadius.md),
          border: Border.all(color: c.line),
        ),
        child: Row(
          children: [
            Icon(
              Icons.location_on_rounded,
              color: hasSelection ? c.accent : c.inkMuted,
              size: 20,
            ),
            const SizedBox(width: SwanSpace.sm),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: c.inkMuted,
                    ),
                  ),
                  Text(
                    hasSelection ? selectedCity! : hint,
                    style: SwanType.bodySm(
                      hasSelection ? c.ink : c.inkMuted,
                      w: hasSelection ? FontWeight.w600 : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (hasSelection)
              GestureDetector(
                onTap: () => onChanged(null),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.clear, size: 16, color: c.inkMuted),
                ),
              )
            else
              Icon(Icons.keyboard_arrow_down_rounded,
                  color: c.inkMuted, size: 22),
          ],
        ),
      ),
    );
  }
}
