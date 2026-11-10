import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/display.dart';
import '../l10n/l10n.dart';
import '../sessions/sessions_provider.dart';
import '../sessions/sessions_screen.dart' show formatDuration;
import '../settings/settings.dart';
import '../theme.dart';
import 'profile.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final profile = ref.watch(profileProvider).value ?? const PatientProfile();
    final sessions = ref.watch(sessionsProvider).value ?? const [];
    final settings = ref.watch(settingsProvider).value ?? const AppSettings();
    final now = DateTime.now();

    final totalTime = sessions.fold(Duration.zero, (sum, s) => sum + s.duration);
    final allBpm = [for (final s in sessions) ...s.heartRate.map((p) => p.bpm)];
    final avg = allBpm.isEmpty ? null : (allBpm.reduce((a, b) => a + b) / allBpm.length).round();
    final symptoms = sessions.fold(0, (n, s) => n + s.symptomCount);
    final maxHr = profile.predictedMaxHr(now);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.tabProfile),
        actions: [
          IconButton(
            tooltip: l.editProfile,
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _edit(context, ref, profile),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          _Header(profile: profile, age: profile.age(now), onEdit: () => _edit(context, ref, profile)),
          const SizedBox(height: 12),
          // Two columns that grow with the text instead of a fixed-ratio grid.
          LayoutBuilder(builder: (context, c) {
            final w = (c.maxWidth - 10) / 2;
            return Wrap(spacing: 10, runSpacing: 10, children: [
              for (final tile in [
                StatTile(label: l.statRecordings, value: '${sessions.length}'),
                StatTile(label: l.statTimeMonitored, value: formatDuration(totalTime)),
                StatTile(label: l.statAverageHr, value: '${avg ?? '--'}', unit: l.bpm, color: AppColors.ecg),
                StatTile(
                  label: l.statSymptoms,
                  value: '$symptoms',
                  color: symptoms > 0 ? AppColors.info : AppColors.textPrimary,
                ),
              ])
                SizedBox(width: w, child: tile),
            ]);
          }),
          if (maxHr != null && settings.hrHigh != maxHr) ...[
            const SizedBox(height: 12),
            _Suggestion(
              text: l.maxHrSuggestion(maxHr),
              onApply: () => ref.read(settingsProvider.notifier).save(settings.copyWith(hrHigh: maxHr)),
            ),
          ],
          const SizedBox(height: 12),
          _InfoCard(
            icon: Icons.medical_information_outlined,
            title: l.conditions,
            empty: l.noneRecorded,
            chips: [for (final c in profile.conditions) conditionName(l, c)],
            color: AppColors.warning,
          ),
          const SizedBox(height: 12),
          _InfoCard(
            icon: Icons.medication_outlined,
            title: l.medication,
            empty: l.noneRecorded,
            chips: profile.medications,
            color: AppColors.info,
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(children: [
              _ContactTile(icon: Icons.local_hospital_outlined, label: l.physician, value: profile.physician),
              const Divider(indent: 16, endIndent: 16),
              _ContactTile(icon: Icons.emergency_outlined, label: l.emergencyContact, value: profile.emergencyContact),
            ]),
          ),
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, PatientProfile profile) async {
    final result = await Navigator.of(context).push<PatientProfile>(
      MaterialPageRoute(fullscreenDialog: true, builder: (_) => _EditProfile(profile: profile)),
    );
    if (result != null) await ref.read(profileProvider.notifier).save(result);
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.profile, required this.age, required this.onEdit});
  final PatientProfile profile;
  final int? age;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final subtitle = [
      if (age != null) l.ageYears(age!),
      if (profile.sex != null) sexName(l, profile.sex!),
    ].join(' · ');
    return Card(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [AppColors.ecg.withValues(alpha: 0.18), AppColors.info.withValues(alpha: 0.08)],
          ),
        ),
        child: Row(children: [
          ExcludeSemantics(
            child: Container(
              width: 72,
              height: 72,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [AppColors.ecg, AppColors.info]),
              ),
              child: Text(profile.initials,
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.black)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: profile.isEmpty
                ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(l.setupProfile, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(l.setupProfileText, style: const TextStyle(color: AppColors.textSecondary)),
                    TextButton(onPressed: onEdit, child: Text(l.addDetails)),
                  ])
                : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(profile.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                    if (subtitle.isNotEmpty) Text(subtitle, style: const TextStyle(color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    StatusPill(label: l.encryptedOnDevice, icon: Icons.lock, color: AppColors.info),
                  ]),
          ),
        ]),
      ),
    );
  }
}

class _Suggestion extends StatelessWidget {
  const _Suggestion({required this.text, required this.onApply});
  final String text;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        decoration: BoxDecoration(
          color: AppColors.info.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.info.withValues(alpha: 0.4)),
        ),
        child: Row(children: [
          const Icon(Icons.tips_and_updates_outlined, color: AppColors.info),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
          TextButton(onPressed: onApply, child: Text(context.l10n.apply)),
        ]),
      );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.empty,
    required this.chips,
    required this.color,
  });
  final IconData icon;
  final String title;
  final String empty;
  final List<String> chips;
  final Color color;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 10),
              Semantics(
                header: true,
                child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ]),
            const SizedBox(height: 12),
            if (chips.isEmpty)
              Text(empty, style: const TextStyle(color: AppColors.textSecondary))
            else
              Wrap(spacing: 8, runSpacing: 8, children: [for (final c in chips) StatusPill(label: c, color: color)]),
          ]),
        ),
      );
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon, color: AppColors.alarm),
        title: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        subtitle: Text(value.isEmpty ? context.l10n.notSet : value,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
      );
}

class _EditProfile extends StatefulWidget {
  const _EditProfile({required this.profile});
  final PatientProfile profile;

  @override
  State<_EditProfile> createState() => _EditProfileState();
}

class _EditProfileState extends State<_EditProfile> {
  late final _name = TextEditingController(text: widget.profile.name);
  late final _year = TextEditingController(text: widget.profile.birthYear?.toString() ?? '');
  late final _physician = TextEditingController(text: widget.profile.physician);
  late final _emergency = TextEditingController(text: widget.profile.emergencyContact);
  late String? _sex = widget.profile.sex;
  late final _conditions = [...widget.profile.conditions];
  late final _medications = [...widget.profile.medications];

  /// Stored by their English key and shown translated.
  static const _commonConditions = ['Hypertension', 'Atrial fibrillation', 'Diabetes', 'Heart failure', 'Asthma'];

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.editProfile),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(
              context,
              PatientProfile(
                name: _name.text.trim(),
                birthYear: int.tryParse(_year.text),
                sex: _sex,
                conditions: _conditions,
                medications: _medications,
                physician: _physician.text.trim(),
                emergencyContact: _emergency.text.trim(),
              ),
            ),
            child: Text(l.save),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            autofillHints: const [AutofillHints.name],
            decoration: InputDecoration(labelText: l.fullName),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _year,
            decoration: InputDecoration(labelText: l.yearOfBirth),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          Text(l.sexLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            for (final (key, label) in [('Female', l.sexFemale), ('Male', l.sexMale), ('Other', l.sexOther)])
              ChoiceChip(
                label: Text(label),
                selected: _sex == key,
                onSelected: (on) => setState(() => _sex = on ? key : null),
              ),
          ]),
          const SizedBox(height: 20),
          Text(l.conditions, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 4, children: [
            for (final c in {..._commonConditions, ..._conditions})
              FilterChip(
                label: Text(conditionName(l, c)),
                selected: _conditions.contains(c),
                onSelected: (on) => setState(() => on ? _conditions.add(c) : _conditions.remove(c)),
              ),
          ]),
          const SizedBox(height: 20),
          _ChipEditor(title: l.medication, hint: l.medicationHint, items: _medications, onChanged: () => setState(() {})),
          const SizedBox(height: 20),
          TextField(controller: _physician, decoration: InputDecoration(labelText: l.physician)),
          const SizedBox(height: 12),
          TextField(
            controller: _emergency,
            keyboardType: TextInputType.text,
            decoration: InputDecoration(labelText: l.emergencyContactHint),
          ),
        ],
      ),
    );
  }
}

class _ChipEditor extends StatefulWidget {
  const _ChipEditor({required this.title, required this.hint, required this.items, required this.onChanged});
  final String title;
  final String hint;
  final List<String> items;
  final VoidCallback onChanged;

  @override
  State<_ChipEditor> createState() => _ChipEditorState();
}

class _ChipEditorState extends State<_ChipEditor> {
  final _input = TextEditingController();

  void _add() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    widget.items.add(text);
    _input.clear();
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 4, children: [
          for (final item in widget.items)
            InputChip(
              label: Text(item),
              onDeleted: () {
                widget.items.remove(item);
                widget.onChanged();
              },
            ),
        ]),
        const SizedBox(height: 8),
        TextField(
          controller: _input,
          decoration: InputDecoration(
            hintText: widget.hint,
            suffixIcon: IconButton(tooltip: context.l10n.addItem, icon: const Icon(Icons.add), onPressed: _add),
          ),
          onSubmitted: (_) => _add(),
        ),
      ]);
}
