import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_models/swansport_models.dart';

import '../application/performance_controller.dart';
import '../domain/performance_analytics.dart';
import 'performance_route_args.dart';

enum _EditorKind { testSession, developmentPlan, selfAssessment, reviewSession }

class TestSessionEditorScreen extends StatelessWidget {
  final TestSessionEditorArgs args;
  const TestSessionEditorScreen({required this.args, super.key});

  @override
  Widget build(BuildContext context) => _WorkflowEditor(
        kind: _EditorKind.testSession,
        recordId: args.sessionId,
      );
}

class DevelopmentPlanEditorScreen extends StatelessWidget {
  final DevelopmentPlanEditorArgs args;
  const DevelopmentPlanEditorScreen({required this.args, super.key});

  @override
  Widget build(BuildContext context) => _WorkflowEditor(
        kind: _EditorKind.developmentPlan,
        recordId: args.planId,
      );
}

class SelfAssessmentEditorScreen extends StatelessWidget {
  final SelfAssessmentEditorArgs args;
  const SelfAssessmentEditorScreen({required this.args, super.key});

  @override
  Widget build(BuildContext context) => _WorkflowEditor(
        kind: _EditorKind.selfAssessment,
        recordId: args.assessmentId,
      );
}

class ReviewSessionEditorScreen extends StatelessWidget {
  final ReviewSessionEditorArgs args;
  const ReviewSessionEditorScreen({required this.args, super.key});

  @override
  Widget build(BuildContext context) => _WorkflowEditor(
        kind: _EditorKind.reviewSession,
        recordId: args.reviewId,
      );
}

class _WorkflowEditor extends ConsumerStatefulWidget {
  final _EditorKind kind;
  final SwanId? recordId;
  const _WorkflowEditor({required this.kind, required this.recordId});

  @override
  ConsumerState<_WorkflowEditor> createState() => _WorkflowEditorState();
}

class _WorkflowEditorState extends ConsumerState<_WorkflowEditor> {
  final _formKey = GlobalKey<FormState>();
  final _primary = TextEditingController();
  final _secondary = TextEditingController();
  final _third = TextEditingController();
  final _fourth = TextEditingController();
  bool _dirty = false;
  bool _initialized = false;
  bool _athleteAssigned = true;
  TestEntryState _entryState = TestEntryState.valid;
  int _rating = 3;

  @override
  void dispose() {
    _primary.dispose();
    _secondary.dispose();
    _third.dispose();
    _fourth.dispose();
    super.dispose();
  }

  void _initialize(PerformanceCenterState state) {
    if (_initialized) return;
    _initialized = true;
    switch (widget.kind) {
      case _EditorKind.testSession:
        final found = state.testSessions.where((e) => e.id == widget.recordId);
        if (found.isNotEmpty) {
          final value = found.single;
          _primary.text = value.title;
          _secondary.text = value.battery.join(', ');
          _third.text = value.notes;
          _fourth.text = value.entries.isEmpty
              ? ''
              : value.entries.first.result?.toString() ?? '';
          _athleteAssigned = value.athletes.isNotEmpty;
        }
      case _EditorKind.developmentPlan:
        final found = state.plans.where((e) => e.id == widget.recordId);
        if (found.isNotEmpty) {
          final value = found.single;
          _primary.text = value.title;
          _secondary.text = value.focusAreas.join(', ');
          _third.text = value.coachingActions.join(', ');
          _fourth.text = value.reviewCadence;
        }
      case _EditorKind.selfAssessment:
        final found =
            state.selfAssessments.where((e) => e.id == widget.recordId);
        if (found.isNotEmpty) {
          final value = found.single;
          _primary.text = value.context;
          _secondary.text = value.perceivedProgress;
          _third.text = value.challenges;
          _rating = value.ratings.values.first;
        }
      case _EditorKind.reviewSession:
        final found =
            state.reviewSessions.where((e) => e.id == widget.recordId);
        if (found.isNotEmpty) {
          final value = found.single;
          _primary.text = value.coach;
          _secondary.text = value.decisions.join(', ');
          _third.text = value.agreedActions.join(', ');
          _fourth.text = value.actionOwners.values.join(', ');
        }
    }
  }

  bool _canEdit(PerformanceCenterState state) => switch (widget.kind) {
        _EditorKind.testSession => state.permissions.canManageTests,
        _EditorKind.developmentPlan => state.permissions.canManageGoals,
        _EditorKind.selfAssessment =>
          state.currentRole == PerformanceRole.athlete,
        _EditorKind.reviewSession => state.permissions.canAssessSkills,
      };

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(performanceControllerProvider);
    if (state.loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (widget.recordId != null && !_recordExists(state)) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Düzenlenecek kayıt bulunamadı.',
            key: Key('workflow-missing-record'),
          ),
        ),
      );
    }
    _initialize(state);
    if (!_canEdit(state)) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Bu iş akışını düzenleme yetkiniz yok.',
            key: Key('workflow-permission-denied'),
          ),
        ),
      );
    }
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop && _dirty) await _confirmCancel();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(_title)),
        body: Form(
          key: _formKey,
          onChanged: () => setState(() => _dirty = true),
          child: ListView(
            key: Key('workflow-editor-${widget.kind.name}'),
            padding: const EdgeInsets.all(20),
            children: [
              Semantics(
                header: true,
                child: Text(
                  widget.recordId == null ? 'Yeni Kayıt' : 'Kaydı Düzenle',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              const SizedBox(height: 12),
              ..._fields,
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    key: const Key('workflow-cancel'),
                    onPressed: _confirmCancel,
                    child: const Text('İptal'),
                  ),
                  FilledButton(
                    key: const Key('workflow-save'),
                    onPressed: _save,
                    child: const Text('Kaydet'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _recordExists(PerformanceCenterState state) => switch (widget.kind) {
        _EditorKind.testSession =>
          state.testSessions.any((e) => e.id == widget.recordId),
        _EditorKind.developmentPlan =>
          state.plans.any((e) => e.id == widget.recordId),
        _EditorKind.selfAssessment =>
          state.selfAssessments.any((e) => e.id == widget.recordId),
        _EditorKind.reviewSession =>
          state.reviewSessions.any((e) => e.id == widget.recordId),
      };

  String get _title => switch (widget.kind) {
        _EditorKind.testSession => 'Test Oturumu Editörü',
        _EditorKind.developmentPlan => 'Gelişim Planı Editörü',
        _EditorKind.selfAssessment => 'Özel Öz Değerlendirme',
        _EditorKind.reviewSession => 'İnceleme Oturumu Editörü',
      };

  List<Widget> get _fields => switch (widget.kind) {
        _EditorKind.testSession => [
            _field(_primary, 'Oturum başlığı'),
            _field(_secondary, 'Test bataryası (virgülle ayırın)'),
            CheckboxListTile(
              key: const Key('test-athlete-assignment'),
              value: _athleteAssigned,
              onChanged: (value) =>
                  setState(() => _athleteAssigned = value ?? false),
              title: const Text('Arda Yılmaz oturuma atandı'),
            ),
            _field(_fourth, '30m Depar sonucu', numeric: true, optional: true),
            DropdownButtonFormField<TestEntryState>(
              key: const Key('test-result-state'),
              initialValue: _entryState,
              decoration: const InputDecoration(labelText: 'Sonuç durumu'),
              items: TestEntryState.values
                  .map(
                    (state) => DropdownMenuItem(
                      value: state,
                      child: Text(state.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) =>
                  setState(() => _entryState = value ?? _entryState),
            ),
            _field(_third, 'Eksik/geçersiz sonuç notu', optional: true),
          ],
        _EditorKind.developmentPlan => [
            _field(_primary, 'Plan başlığı'),
            _field(_secondary, 'Odak alanları (virgülle ayırın)'),
            _field(_third, 'Koçluk eylemleri (virgülle ayırın)'),
            _field(_fourth, 'İnceleme sıklığı'),
            const CheckboxListTile(
              value: true,
              onChanged: null,
              title: Text('Aktif hedef ve kilometre taşı bağlantısı'),
              subtitle: Text('goal_1 • milestone_1'),
            ),
          ],
        _EditorKind.selfAssessment => [
            const Text(
              'Bu bilgiler sporcu bildirimi olarak etiketlenir; akranlara, aramaya veya dışa aktarmaya açılmaz.',
            ),
            _field(_primary, 'Bağlam'),
            _field(_secondary, 'Algılanan ilerleme'),
            _field(_third, 'Mevcut zorluklar', optional: true),
            Slider(
              value: _rating.toDouble(),
              min: 1,
              max: 5,
              divisions: 4,
              label: 'Öz değerlendirme $_rating / 5',
              onChanged: (value) => setState(() => _rating = value.round()),
            ),
            const ListTile(
              title: Text('İnceleme durumu'),
              subtitle: Text('Taslak • henüz koç incelemesine gönderilmedi'),
            ),
          ],
        _EditorKind.reviewSession => [
            _field(_primary, 'Koç'),
            _field(_secondary, 'İnsan kararları (virgülle ayırın)'),
            _field(_third, 'Takip eylemleri (virgülle ayırın)'),
            _field(_fourth, 'Eylem sahipleri (virgülle ayırın)'),
            const ListTile(
              title: Text('Takip tarihi'),
              subtitle: Text('Bir sonraki ay • kullanıcı tarafından planlandı'),
            ),
          ],
      };

  Widget _field(
    TextEditingController controller,
    String label, {
    bool numeric = false,
    bool optional = false,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: controller,
          keyboardType: numeric ? TextInputType.number : TextInputType.text,
          decoration: InputDecoration(labelText: label),
          minLines: 1,
          maxLines:
              label.contains('karar') || label.contains('ilerleme') ? 3 : 1,
          validator: (value) {
            if (!optional && (value == null || value.trim().isEmpty)) {
              return '$label zorunludur';
            }
            if (numeric &&
                value != null &&
                value.isNotEmpty &&
                double.tryParse(value) == null) {
              return 'Geçerli bir sayı girin';
            }
            return null;
          },
        ),
      );

  List<String> _split(String value) =>
      value.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final controller = ref.read(performanceControllerProvider.notifier);
    final state = ref.read(performanceControllerProvider);
    final now = DateTime.now();
    final id = widget.recordId ??
        SwanId('${widget.kind.name}_${now.microsecondsSinceEpoch}');
    final success = switch (widget.kind) {
      _EditorKind.testSession => controller.saveTestSession(
          PerformanceTestSession(
            id: id,
            title: _primary.text.trim(),
            sport: 'Futbol',
            battery: _split(_secondary.text),
            date: now.add(const Duration(days: 7)),
            location: 'Kadıköy Performans Sahası',
            teamId: const SwanId('team_u18'),
            athletes: _athleteAssigned ? const [SwanId('athlete_1')] : const [],
            assessor: state.currentRole.name,
            status: TestSessionStatus.draft,
            validResults: _entryState == TestEntryState.valid ? 1 : 0,
            missingResults: _entryState == TestEntryState.missing ? 1 : 0,
            invalidResults: _entryState == TestEntryState.invalid ? 1 : 0,
            notes: _third.text.trim(),
            createdAt: now,
            updatedAt: now,
            entries: [
              PerformanceTestEntry(
                athleteId: const SwanId('athlete_1'),
                testName: _split(_secondary.text).first,
                result: double.tryParse(_fourth.text),
                unit: 'sn',
                state: _entryState,
                note: _third.text.trim(),
              ),
            ],
          ),
        ),
      _EditorKind.developmentPlan => controller.saveDevelopmentPlan(
          DevelopmentPlan(
            id: id,
            athleteId: const SwanId('athlete_1'),
            title: _primary.text.trim(),
            owner: state.currentRole.name,
            startDate: now,
            endDate: now.add(const Duration(days: 90)),
            focusAreas: _split(_secondary.text),
            linkedGoals: const [SwanId('goal_1')],
            coachingActions: _split(_third.text),
            progress: 0,
            status: PlanStatus.draft,
            notes: 'Tıbbi rehabilitasyon içermez.',
            milestones: state.milestones,
            reviewCadence: _fourth.text.trim(),
          ),
        ),
      _EditorKind.selfAssessment => controller.saveSelfAssessment(
          AthleteSelfAssessment(
            id: id,
            athleteId: const SwanId('athlete_1'),
            context: _primary.text.trim(),
            ratings: {'Öz değerlendirme': _rating},
            perceivedProgress: _secondary.text.trim(),
            challenges: _third.text.trim(),
            status: WorkflowStatus.draft,
          ),
        ),
      _EditorKind.reviewSession => controller.saveReviewSession(
          AthleteReviewSession(
            id: id,
            athleteId: const SwanId('athlete_1'),
            coach: _primary.text.trim(),
            date: now,
            reviewedMetrics: const ['30m Depar', 'Aktif hedefler'],
            decisions: _split(_secondary.text),
            agreedActions: _split(_third.text),
            nextReviewDate: now.add(const Duration(days: 30)),
            status: ReviewStatus.scheduled,
            actionOwners: {
              for (final owner in _split(_fourth.text)) owner: owner,
            },
          ),
        ),
    };
    if (!mounted) return;
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kayıt doğrulanamadı veya yetki reddedildi.'),
        ),
      );
      return;
    }
    setState(() => _dirty = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Kayıt başarıyla kaydedildi.')),
    );
  }

  Future<void> _confirmCancel() async {
    if (!_dirty) {
      await Navigator.maybePop(context);
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kaydedilmemiş değişiklikler'),
        content: const Text('Değişiklikleri iptal etmek istiyor musunuz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Düzenlemeye Dön'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Değişiklikleri At'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) Navigator.pop(context);
  }
}
