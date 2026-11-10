import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/settings.dart';

class PatientProfile {
  const PatientProfile({
    this.name = '',
    this.birthYear,
    this.sex,
    this.conditions = const [],
    this.medications = const [],
    this.physician = '',
    this.emergencyContact = '',
  });

  final String name;
  final int? birthYear;
  final String? sex;
  final List<String> conditions;
  final List<String> medications;
  final String physician;
  final String emergencyContact;

  bool get isEmpty => name.isEmpty && birthYear == null;

  int? age(DateTime now) => birthYear == null ? null : now.year - birthYear!;

  /// Age-predicted maximum heart rate (Tanaka: 208 − 0.7 × age), a common
  /// basis for an upper alarm limit.
  int? predictedMaxHr(DateTime now) {
    final a = age(now);
    return a == null ? null : (208 - 0.7 * a).round();
  }

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return (parts.first[0] + (parts.length > 1 ? parts.last[0] : '')).toUpperCase();
  }

  PatientProfile copyWith({
    String? name,
    int? Function()? birthYear,
    String? Function()? sex,
    List<String>? conditions,
    List<String>? medications,
    String? physician,
    String? emergencyContact,
  }) =>
      PatientProfile(
        name: name ?? this.name,
        birthYear: birthYear != null ? birthYear() : this.birthYear,
        sex: sex != null ? sex() : this.sex,
        conditions: conditions ?? this.conditions,
        medications: medications ?? this.medications,
        physician: physician ?? this.physician,
        emergencyContact: emergencyContact ?? this.emergencyContact,
      );

  Map<String, Object?> toJson() => {
        'name': name,
        'birthYear': birthYear,
        'sex': sex,
        'conditions': conditions,
        'medications': medications,
        'physician': physician,
        'emergencyContact': emergencyContact,
      };

  factory PatientProfile.fromJson(Map<String, Object?> json) => PatientProfile(
        name: json['name'] as String? ?? '',
        birthYear: json['birthYear'] as int?,
        sex: json['sex'] as String?,
        conditions: [...?(json['conditions'] as List?)?.cast<String>()],
        medications: [...?(json['medications'] as List?)?.cast<String>()],
        physician: json['physician'] as String? ?? '',
        emergencyContact: json['emergencyContact'] as String? ?? '',
      );
}

final profileProvider = AsyncNotifierProvider<ProfileController, PatientProfile>(ProfileController.new);

/// The profile is personal health data, so it lives in the encrypted store.
class ProfileController extends AsyncNotifier<PatientProfile> {
  static const file = 'profile.json';

  @override
  Future<PatientProfile> build() async {
    final bytes = await ref.watch(blobStoreProvider).read(file);
    if (bytes == null) return const PatientProfile();
    return PatientProfile.fromJson(jsonDecode(utf8.decode(bytes)) as Map<String, Object?>);
  }

  Future<void> save(PatientProfile profile) async {
    state = AsyncData(profile);
    await ref.read(blobStoreProvider).write(file, utf8.encode(jsonEncode(profile.toJson())));
  }
}
