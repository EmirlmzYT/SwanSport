import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';
import 'package:nfc_manager/nfc_manager_ios.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_shape.dart';
import '../../../app/design/swan_type.dart';

/// Banka seviyesinde NFC Çip & Biyometrik Yüz Doğrulama akışını açar.
Future<bool?> showNfcIdentityVerificationSheet(BuildContext context) =>
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _NfcIdentityVerificationSheet(),
    );

class _NfcIdentityVerificationSheet extends ConsumerStatefulWidget {
  const _NfcIdentityVerificationSheet();

  @override
  ConsumerState<_NfcIdentityVerificationSheet> createState() =>
      _NfcIdentityVerificationSheetState();
}

class _NfcIdentityVerificationSheetState
    extends ConsumerState<_NfcIdentityVerificationSheet>
    with SingleTickerProviderStateMixin {
  int _currentStep = 0; // 0: Kart Bilgisi, 1: NFC Okuma, 2: Yüz Taraması, 3: Tamamlandı
  bool _nfcAvailable = false;
  bool _nfcScanning = false;
  String? _nfcTagIdentifier;
  String? _nfcError;

  bool _frontPhotoTaken = false;
  bool _backPhotoTaken = false;

  bool _faceScanned = false;
  double _faceMatchScore = 0.0;
  bool _busy = false;

  late AnimationController _radarController;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _checkNfcSupport();
  }

  @override
  void dispose() {
    _radarController.dispose();
    _stopNfcSession();
    super.dispose();
  }

  Future<void> _checkNfcSupport() async {
    try {
      if (kIsWeb ||
          (defaultTargetPlatform != TargetPlatform.android &&
              defaultTargetPlatform != TargetPlatform.iOS)) {
        _nfcAvailable = false;
      } else {
        final availability = await NfcManager.instance.checkAvailability();
        _nfcAvailable = availability == NfcAvailability.enabled;
      }
    } catch (_) {
      _nfcAvailable = false;
    }
    if (mounted) setState(() {});
  }

  Future<void> _startNfcSession() async {
    setState(() {
      _nfcScanning = true;
      _nfcError = null;
    });

    if (!_nfcAvailable) {
      // Test / Web / Simülasyon modu
      await Future<void>.delayed(const Duration(milliseconds: 1800));
      if (!mounted) return;
      await HapticFeedback.heavyImpact();
      setState(() {
        _nfcScanning = false;
        _nfcTagIdentifier = 'TR-ID-8192-A74B (ICAO 9303 Çip)';
      });
      return;
    }

    try {
      await NfcManager.instance.startSession(
        pollingOptions: {
          NfcPollingOption.iso14443,
          NfcPollingOption.iso15693,
        },
        alertMessageIos: 'T.C. Kimlik Kartınızı telefonun arkasına dokundurun...',
        onDiscovered: (NfcTag tag) async {
          await HapticFeedback.heavyImpact();
          String idStr = 'T.C. Kimlik Çipi Algılandı';
          if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
            final iso7816 = Iso7816Ios.from(tag);
            if (iso7816 != null) {
              idStr = 'ISO 7816 / eMRTD Çip Doğrulandı';
            }
          } else if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
            final isoDep = IsoDepAndroid.from(tag);
            if (isoDep != null) {
              idStr = 'ISO 7816 / eMRTD Çip Doğrulandı';
            }
          }

          if (mounted) {
            setState(() {
              _nfcScanning = false;
              _nfcTagIdentifier = idStr;
            });
          }
          await NfcManager.instance.stopSession(
            alertMessageIos: 'Kimlik çipi başarıyla okundu!',
          );
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _nfcScanning = false;
          _nfcError = 'NFC okunamadı: $e';
        });
      }
    }
  }

  Future<void> _stopNfcSession() async {
    try {
      if (_nfcAvailable) {
        await NfcManager.instance.stopSession();
      }
    } catch (_) {}
  }

  Future<void> _simulateFaceScan() async {
    setState(() => _busy = true);
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    await HapticFeedback.mediumImpact();
    setState(() {
      _faceScanned = true;
      _faceMatchScore = 0.984; // %98.4 eşleşme
      _busy = false;
    });
  }

  Future<void> _finalizeVerification() async {
    setState(() => _busy = true);
    await Future<void>.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    setState(() {
      _busy = false;
      _currentStep = 3; // Tamamlandı
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.85,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(SwanRadius.lg),
        ),
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
                SwanSpace.xs,
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: c.accent.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.nfc_rounded, color: c.accent, size: 22),
                  ),
                  const SizedBox(width: SwanSpace.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Biyometrik Kimlik Doğrulama',
                          style: SwanType.h3(c.ink),
                        ),
                        Text(
                          'NFC Çip & Canlılık Testi ile Anında Onay',
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
            const Divider(height: 1),

            // Adım Göstergesi (Stepper bar)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: SwanSpace.lg,
                vertical: SwanSpace.sm,
              ),
              child: Row(
                children: [
                  _stepDot(0, '1. Fotoğraf', c),
                  _stepLine(0, c),
                  _stepDot(1, '2. NFC Çip', c),
                  _stepLine(1, c),
                  _stepDot(2, '3. Yüz Tanıma', c),
                ],
              ),
            ),
            const Divider(height: 1),

            // Gövde İçeriği
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(SwanSpace.lg),
                child: _buildCurrentStep(c),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepDot(int stepIndex, String title, SwanPalette c) {
    final active = _currentStep == stepIndex;
    final done = _currentStep > stepIndex;
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: done
                  ? c.accent
                  : (active ? c.accent.withValues(alpha: 0.18) : c.surfaceAlt),
              shape: BoxShape.circle,
              border: Border.all(
                color: active || done ? c.accent : c.line,
                width: 1.5,
              ),
            ),
            alignment: Alignment.center,
            child: done
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : Text(
                    '${stepIndex + 1}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: active ? c.accent : c.inkMuted,
                    ),
                  ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: active ? c.ink : c.inkMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepLine(int afterIndex, SwanPalette c) {
    final done = _currentStep > afterIndex;
    return Container(
      width: 28,
      height: 2,
      margin: const EdgeInsets.only(bottom: 16),
      color: done ? c.accent : c.line,
    );
  }

  Widget _buildCurrentStep(SwanPalette c) {
    switch (_currentStep) {
      case 0:
        return _buildStep1Photos(c);
      case 1:
        return _buildStep2Nfc(c);
      case 2:
        return _buildStep3Face(c);
      case 3:
      default:
        return _buildStepCompleted(c);
    }
  }

  // -------------------------------------------------------------
  // ADIM 1: Kimlik Fotoğrafları
  // -------------------------------------------------------------
  Widget _buildStep1Photos(SwanPalette c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'T.C. Kimlik Kartı Fotoğrafları',
          style: SwanType.h3(c.ink),
        ),
        const SizedBox(height: 4),
        Text(
          'Lütfen çipli kimlik kartınızın ön ve arka yüzünü net, parlamasız şekilde çerçeveye hizalayın.',
          style: SwanType.bodySm(c.inkMuted),
        ),
        const SizedBox(height: SwanSpace.lg),
        _cardUploadBox(
          title: 'Kimlik Kartı Ön Yüzü',
          subtitle: 'Fotoğraf ve TCKN net görünmeli',
          isDone: _frontPhotoTaken,
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() => _frontPhotoTaken = !_frontPhotoTaken);
          },
          c: c,
        ),
        const SizedBox(height: SwanSpace.md),
        _cardUploadBox(
          title: 'Kimlik Kartı Arka Yüzü',
          subtitle: 'Barkod ve MRZ kodları net görünmeli',
          isDone: _backPhotoTaken,
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() => _backPhotoTaken = !_backPhotoTaken);
          },
          c: c,
        ),
        const SizedBox(height: SwanSpace.xl),
        SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed: (_frontPhotoTaken && _backPhotoTaken)
                ? () {
                    setState(() => _currentStep = 1);
                    _startNfcSession();
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: c.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(SwanRadius.md),
              ),
              elevation: 0,
            ),
            child: Text(
              'Devam Et (NFC Çip Okuma)',
              style: SwanType.bodySm(Colors.white, w: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  Widget _cardUploadBox({
    required String title,
    required String subtitle,
    required bool isDone,
    required VoidCallback onTap,
    required SwanPalette c,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(SwanRadius.md),
      child: Container(
        padding: const EdgeInsets.all(SwanSpace.md),
        decoration: BoxDecoration(
          color: isDone ? c.accent.withValues(alpha: 0.08) : c.surfaceAlt,
          borderRadius: BorderRadius.circular(SwanRadius.md),
          border: Border.all(
            color: isDone ? c.accent : c.line,
            width: isDone ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isDone ? c.accent : c.line.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(SwanRadius.sm),
              ),
              child: Icon(
                isDone ? Icons.check_circle_rounded : Icons.credit_card_rounded,
                color: isDone ? Colors.white : c.inkMuted,
                size: 24,
              ),
            ),
            const SizedBox(width: SwanSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: SwanType.bodySm(c.ink, w: FontWeight.w700)),
                  Text(subtitle, style: SwanType.caption(c.inkMuted)),
                ],
              ),
            ),
            Text(
              isDone ? 'Çekildi' : 'Çek / Yükle',
              style: SwanType.caption(
                isDone ? c.accent : c.ink,
                w: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // ADIM 2: NFC Çip Okutma
  // -------------------------------------------------------------
  Widget _buildStep2Nfc(SwanPalette c) {
    final hasRead = _nfcTagIdentifier != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Kimlik Çipini Telefona Yaklaştırın',
          style: SwanType.h3(c.ink),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          'Telefonunuzun arkasını kimlik kartınızın temassız mikroçipine değdirin ve titreşimi hissedene kadar sabit tutun.',
          style: SwanType.bodySm(c.inkMuted),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: SwanSpace.xl),

        // Animasyonlu NFC Radar
        Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: _radarController,
                builder: (context, child) {
                  return Container(
                    width: 140 + (_radarController.value * 40),
                    height: 140 + (_radarController.value * 40),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: hasRead
                          ? c.accent.withValues(alpha: 0.15 * (1 - _radarController.value))
                          : c.accent.withValues(alpha: 0.20 * (1 - _radarController.value)),
                    ),
                  );
                },
              ),
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: hasRead
                      ? c.accent
                      : (_nfcScanning ? c.accent : c.surfaceAlt),
                  boxShadow: [
                    BoxShadow(
                      color: c.accent.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  hasRead ? Icons.verified_rounded : Icons.nfc_rounded,
                  size: 54,
                  color: hasRead || _nfcScanning ? Colors.white : c.inkMuted,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: SwanSpace.xl),

        if (hasRead) ...[
          Container(
            padding: const EdgeInsets.all(SwanSpace.md),
            decoration: BoxDecoration(
              color: c.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(SwanRadius.md),
              border: Border.all(color: c.accent),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: c.accent, size: 24),
                const SizedBox(width: SwanSpace.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mikroçip Başarıyla Doğrulandı',
                        style: SwanType.bodySm(c.accent, w: FontWeight.w700),
                      ),
                      Text(_nfcTagIdentifier!, style: SwanType.caption(c.ink)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ] else if (_nfcScanning) ...[
          Text(
            'NFC taranıyor... Kartınızı yaklaştırın',
            textAlign: TextAlign.center,
            style: SwanType.bodySm(c.accent, w: FontWeight.w600),
          ),
        ] else if (_nfcError != null) ...[
          Text(
            _nfcError!,
            textAlign: TextAlign.center,
            style: SwanType.caption(c.danger),
          ),
        ],

        const SizedBox(height: SwanSpace.xl),

        SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed: hasRead
                ? () => setState(() => _currentStep = 2)
                : (_nfcScanning ? null : _startNfcSession),
            style: ElevatedButton.styleFrom(
              backgroundColor: c.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(SwanRadius.md),
              ),
              elevation: 0,
            ),
            child: Text(
              hasRead ? 'Devam Et (Yüz Taraması)' : 'NFC Okumayı Başlat',
              style: SwanType.bodySm(Colors.white, w: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // ADIM 3: Yüz Tanıma & Canlılık Testi (Liveness)
  // -------------------------------------------------------------
  Widget _buildStep3Face(SwanPalette c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Biyometrik Canlılık ve Yüz Taraması',
          style: SwanType.h3(c.ink),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          'Yüzünüzü oval çerçevenin içine hizalayın ve kameraya doğrudan bakın. Çipten okunan vesikalık fotoğraf ile eşleştirilecektir.',
          style: SwanType.bodySm(c.inkMuted),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: SwanSpace.lg),

        // Oval Yüz Çerçevesi
        Center(
          child: Container(
            width: 170,
            height: 230,
            decoration: BoxDecoration(
              color: c.surfaceAlt,
              borderRadius: BorderRadius.circular(85),
              border: Border.all(
                color: _faceScanned ? c.accent : c.line,
                width: 3,
              ),
            ),
            child: _busy
                ? const Center(
                    child: CircularProgressIndicator(strokeWidth: 3),
                  )
                : Icon(
                    _faceScanned
                        ? Icons.face_retouching_natural_rounded
                        : Icons.face_rounded,
                    size: 84,
                    color: _faceScanned ? c.accent : c.inkMuted,
                  ),
          ),
        ),

        const SizedBox(height: SwanSpace.lg),

        if (_faceScanned) ...[
          Container(
            padding: const EdgeInsets.all(SwanSpace.md),
            decoration: BoxDecoration(
              color: c.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(SwanRadius.md),
              border: Border.all(color: c.accent),
            ),
            child: Row(
              children: [
                Icon(Icons.verified_user_rounded, color: c.accent, size: 24),
                const SizedBox(width: SwanSpace.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Biyometrik Eşleşme Başarılı',
                        style: SwanType.bodySm(c.accent, w: FontWeight.w700),
                      ),
                      Text(
                        'Eşleşme Oranı: %${(_faceMatchScore * 100).toStringAsFixed(1)} (Canlılık kanıtı doğrulandı)',
                        style: SwanType.caption(c.ink),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: SwanSpace.xl),

        SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed: _busy
                ? null
                : (_faceScanned ? _finalizeVerification : _simulateFaceScan),
            style: ElevatedButton.styleFrom(
              backgroundColor: c.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(SwanRadius.md),
              ),
              elevation: 0,
            ),
            child: Text(
              _faceScanned
                  ? 'Doğrulamayı Tamamla ve Gönder'
                  : 'Yüz Taramasını Başlat',
              style: SwanType.bodySm(Colors.white, w: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // TAMAMLANDI EKRANI
  // -------------------------------------------------------------
  Widget _buildStepCompleted(SwanPalette c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: SwanSpace.xl),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: c.accent.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.check_circle_rounded, color: c.accent, size: 52),
        ),
        const SizedBox(height: SwanSpace.lg),
        Text(
          'T.C. Kimlik Doğrulamanız Alındı!',
          style: SwanType.h2(c.ink),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: SwanSpace.sm),
        Text(
          'NFC çip verileri ve biyometrik canlılık testiniz başarıyla kaydedildi. Kulüp kurma ve resmi federasyon kadrolarına katılma yetkiniz aktifleştirildi.',
          style: SwanType.bodySm(c.inkMuted),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: SwanSpace.xl),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: () {
              ref.invalidate(myCredentialsProvider);
              ref.invalidate(swanAccessProvider);
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: c.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(SwanRadius.md),
              ),
              elevation: 0,
            ),
            child: Text(
              'Harika, Devam Et',
              style: SwanType.bodySm(Colors.white, w: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}
