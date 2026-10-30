import 'package:flutter/material.dart';

import '../app/pro_theme.dart';

/// SwanSport Pro standart sayfa başlığı.
class ProPageHeader extends StatelessWidget {
  const ProPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.action,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (leading != null) ...[
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: leading!,
            ),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: ProTheme.ink,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: ProTheme.muted,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (action != null) ...[
            const SizedBox(width: 12),
            action!,
          ],
        ],
      ),
    );
  }
}

/// Bölüm başlığı (Sayaç ve opsiyonel işlem butonuyla).
class ProSectionHeader extends StatelessWidget {
  const ProSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.count,
    this.action,
  });

  final String title;
  final String? subtitle;
  final int? count;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                          color: ProTheme.ink,
                        ),
                      ),
                    ),
                    if (count != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: ProTheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$count',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: ProTheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: ProTheme.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

/// Standart boş durum bileşeni.
class ProEmptyState extends StatelessWidget {
  const ProEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: ProTheme.surfaceRaised,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: ProTheme.line),
              ),
              child: Icon(icon, color: ProTheme.muted, size: 28),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: ProTheme.ink,
              ),
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: ProTheme.muted,
                  height: 1.4,
                ),
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: 20),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Standart hata durumu bileşeni.
class ProErrorState extends StatelessWidget {
  const ProErrorState({
    super.key,
    this.icon = Icons.error_outline_rounded,
    required this.message,
    this.onRetry,
  });

  final IconData icon;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFEF4444).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFEF4444).withValues(alpha: 0.25),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: const Color(0xFFEF4444), size: 32),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: ProTheme.ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Tekrar Dene'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Standart yüklenme durumu bileşeni.
class ProLoadingState extends StatelessWidget {
  const ProLoadingState({
    super.key,
    this.message = 'Yükleniyor…',
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(
                color: ProTheme.muted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Standart yetkisiz erişim (Fail-Closed) durumu bileşeni.
class ProUnauthorizedState extends StatelessWidget {
  const ProUnauthorizedState({
    super.key,
    required this.roleName,
    this.onBack,
    this.onChangeWorkspace,
  });

  final String roleName;
  final VoidCallback? onBack;
  final VoidCallback? onChangeWorkspace;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: ProTheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: ProTheme.line),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.lock_person_outlined,
                  color: Color(0xFFEF4444),
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Yetkisiz Erişim',
                style: TextStyle(
                  color: ProTheme.ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Bu işlem veya çalışma alanı için $roleName yetkisi gereklidir.',
                style: const TextStyle(
                  color: ProTheme.muted,
                  fontSize: 13,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  if (onBack != null)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      onPressed: onBack,
                      icon: const Icon(Icons.arrow_back_rounded, size: 18),
                      label: const Text('Geri Dön'),
                    ),
                  if (onChangeWorkspace != null)
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      onPressed: onChangeWorkspace,
                      icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                      label: const Text('Çalışma Alanı Değiştir'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Standart işlem başarısı geri bildirim çubuğu.
class ProSuccessBanner extends StatelessWidget {
  const ProSuccessBanner({
    super.key,
    required this.message,
    this.action,
  });

  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: 0.30),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_outline_rounded,
            color: Color(0xFF10B981),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF10B981),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (action != null) ...[
            const SizedBox(width: 8),
            action!,
          ],
        ],
      ),
    );
  }
}

/// Ağ gecikmesi veya onay bekleyen mutasyonlar için koruma banner'ı.
class ProUncertainStateBanner extends StatelessWidget {
  const ProUncertainStateBanner({
    super.key,
    this.message =
        'Ağ gecikmesi nedeniyle işlem sonucu doğrulanıyor… Lütfen tekrar tıklamayın.',
    this.onRetry,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.sync_problem_rounded,
              color: Color(0xFFF59E0B),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'İşlem sonucu doğrulanıyor',
                  style: TextStyle(
                    color: Color(0xFFF59E0B),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                    color: ProTheme.ink,
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
                if (onRetry != null) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      side: const BorderSide(color: Color(0xFFF59E0B)),
                      foregroundColor: const Color(0xFFF59E0B),
                    ),
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Durumu Kontrol Et'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Durum / öncelik rozeti (Renkle birlikte anlamsal ikon & metin içerir).
enum ProStatusTone { urgent, pending, scheduled, completed, info }

class ProStatusBadge extends StatelessWidget {
  const ProStatusBadge({
    super.key,
    required this.label,
    required this.tone,
  });

  final String label;
  final ProStatusTone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, border, fg, icon) = switch (tone) {
      ProStatusTone.urgent => (
          const Color(0xFFEF4444).withValues(alpha: 0.12),
          const Color(0xFFEF4444).withValues(alpha: 0.30),
          const Color(0xFFEF4444),
          Icons.priority_high_rounded,
        ),
      ProStatusTone.pending => (
          const Color(0xFFF59E0B).withValues(alpha: 0.12),
          const Color(0xFFF59E0B).withValues(alpha: 0.30),
          const Color(0xFFF59E0B),
          Icons.pending_actions_rounded,
        ),
      ProStatusTone.scheduled => (
          ProTheme.primary.withValues(alpha: 0.12),
          ProTheme.primary.withValues(alpha: 0.30),
          ProTheme.primary,
          Icons.schedule_rounded,
        ),
      ProStatusTone.completed => (
          const Color(0xFF10B981).withValues(alpha: 0.12),
          const Color(0xFF10B981).withValues(alpha: 0.30),
          const Color(0xFF10B981),
          Icons.check_circle_outline_rounded,
        ),
      ProStatusTone.info => (
          ProTheme.surfaceRaised,
          ProTheme.line,
          ProTheme.muted,
          Icons.info_outline_rounded,
        ),
    };

    return Semantics(
      container: true,
      excludeSemantics: true,
      label: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Yatay filtre barı (En az 48x48 dokunma alanı).
class ProFilterBar extends StatelessWidget {
  const ProFilterBar({
    super.key,
    required this.filters,
    required this.selected,
    required this.onChanged,
  });

  final List<String> filters;
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final filter in filters) ...[
            _FilterChip(
              label: filter,
              isSelected: filter == selected,
              onTap: () => onChanged(filter),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      child: Material(
        color: isSelected
            ? ProTheme.primary.withValues(alpha: 0.15)
            : ProTheme.surfaceRaised,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          hoverColor: ProTheme.primary.withValues(alpha: 0.08),
          focusColor: ProTheme.primary.withValues(alpha: 0.16),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? ProTheme.primary.withValues(alpha: 0.35)
                    : ProTheme.line,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? ProTheme.primary : ProTheme.muted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Kritik veya geri alınamaz işlemler için tehlike teyit diyaloğu.
Future<bool> showProDangerDialog({
  required BuildContext context,
  required String title,
  required String message,
  String confirmLabel = 'Onayla',
  String cancelLabel = 'Vazgeç',
}) async {
  return await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: ProTheme.surfaceRaised,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
              color: const Color(0xFFEF4444).withValues(alpha: 0.35),
            ),
          ),
          icon: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFFEF4444),
              size: 24,
            ),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: ProTheme.ink,
            ),
            textAlign: TextAlign.center,
          ),
          content: Text(
            message,
            style: const TextStyle(
              fontSize: 13.5,
              color: ProTheme.muted,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          actionsPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: Text(cancelLabel),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(48, 48),
                    ),
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: Text(confirmLabel),
                  ),
                ),
              ],
            ),
          ],
        ),
      ) ??
      false;
}
