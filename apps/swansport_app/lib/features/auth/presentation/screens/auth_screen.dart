import 'package:flutter/material.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _obscurePassword = true;

  void _showRoleSelectionSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final bg = isDark ? SwanColors.darkSurface : SwanColors.surface;

        return Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 40,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 32,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color:
                        isDark ? const Color(0xFF2E3440) : SwanColors.outline,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Rol Seç',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Hesabınızda birden fazla yetki bulundu.',
                style: TextStyle(
                  fontSize: 13,
                  color: SwanColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 20),

              // Role Option 1 – Selected
              _RoleOptionTile(
                clubName: 'Kadıköy SK',
                roleName: 'Kulüp Antrenörü (U-16 Erkek)',
                isSelected: true,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushReplacementNamed(context, '/dashboard');
                },
              ),
              const SizedBox(height: 10),
              _RoleOptionTile(
                clubName: 'TBF İstanbul İl Temsilciliği',
                roleName: 'İl Temsilcisi Yetkilisi',
                isSelected: false,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushReplacementNamed(context, '/dashboard');
                },
              ),
              const SizedBox(height: 24),

              SwanButton.primary(
                label: 'Devam Et',
                width: double.infinity,
                height: 52,
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushReplacementNamed(context, '/dashboard');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? SwanColors.darkBackground : SwanColors.background,
      body: Stack(
        children: [
          // Subtle radial depth background
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.4,
                  colors: [
                    const Color(
                      0xFF008C95,
                    ).withValues(alpha: isDark ? 0.08 : 0.05),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Logo mark
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: SwanColors.primary,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: SwanColors.primary.withValues(alpha: 0.35),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'S',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 26,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Editorial heading
                      const Text(
                        'Hoş Geldiniz,',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: SwanColors.textSecondary,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'SwanSport',
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.2,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Profesyonel spor yönetim platformu.',
                        style: TextStyle(
                          fontSize: 13,
                          color: SwanColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 30),

                      // Login Card
                      _buildCard(
                        isDark: isDark,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildInputLabel('E-posta veya TCKN'),
                            const SizedBox(height: 8),
                            _buildTextField(
                              isDark: isDark,
                              hintText: 'ornek@kulup.org',
                              prefixIcon: Icons.alternate_email_rounded,
                            ),
                            const SizedBox(height: 16),
                            _buildInputLabel('Şifre'),
                            const SizedBox(height: 8),
                            _buildTextField(
                              isDark: isDark,
                              hintText: '••••••••••',
                              obscureText: _obscurePassword,
                              prefixIcon: Icons.lock_outline_rounded,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_rounded
                                      : Icons.visibility_rounded,
                                  size: 20,
                                  color: SwanColors.textSecondary,
                                ),
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () {},
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text(
                                  'Şifremi Unuttum',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: SwanColors.primary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Primary CTA
                            SwanButton.primary(
                              label: 'Giriş Yap',
                              width: double.infinity,
                              height: 52,
                              icon: Icons.arrow_forward_rounded,
                              onPressed: _showRoleSelectionSheet,
                            ),
                            const SizedBox(height: 12),

                            // Divider
                            Row(
                              children: [
                                Expanded(
                                  child: Divider(
                                    color: isDark
                                        ? const Color(0xFF2E3440)
                                        : SwanColors.outline,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  child: Text(
                                    'veya',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark
                                          ? SwanColors.darkText
                                              .withValues(alpha: 0.4)
                                          : SwanColors.textSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Divider(
                                    color: isDark
                                        ? const Color(0xFF2E3440)
                                        : SwanColors.outline,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Secondary CTA
                            SwanButton.secondary(
                              label: 'OTP ile Giriş Yap',
                              width: double.infinity,
                              icon: Icons.smartphone_rounded,
                              onPressed: _showRoleSelectionSheet,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required bool isDark, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? SwanColors.darkSurface : SwanColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF2E3440) : const Color(0xFFEAEFF2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildInputLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.1,
      ),
    );
  }

  Widget _buildTextField({
    required bool isDark,
    required String hintText,
    bool obscureText = false,
    IconData? prefixIcon,
    Widget? suffixIcon,
  }) {
    final fillColor =
        isDark ? SwanColors.darkSurfaceVariant : SwanColors.surfaceVariant;
    final borderColor = isDark ? const Color(0xFF2E3440) : SwanColors.outline;

    return TextField(
      obscureText: obscureText,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          color: isDark
              ? SwanColors.darkText.withValues(alpha: 0.35)
              : SwanColors.textSecondary.withValues(alpha: 0.7),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, size: 18, color: SwanColors.textSecondary)
            : null,
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: fillColor,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: SwanColors.primary, width: 1.5),
        ),
      ),
    );
  }
}

class _RoleOptionTile extends StatelessWidget {
  final String clubName;
  final String roleName;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleOptionTile({
    required this.clubName,
    required this.roleName,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF142426) : SwanColors.primaryContainer)
              : (isDark
                  ? SwanColors.darkSurfaceVariant
                  : SwanColors.surfaceVariant),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? SwanColors.primary.withValues(alpha: 0.5)
                : (isDark ? const Color(0xFF2E3440) : SwanColors.outline),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    clubName,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: isSelected ? SwanColors.primary : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    roleName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: SwanColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Padding(
                padding: EdgeInsets.only(left: 12),
                child: Icon(
                  Icons.check_circle_rounded,
                  color: SwanColors.primary,
                  size: 22,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
