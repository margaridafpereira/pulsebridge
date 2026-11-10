// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'PulseBridge';

  @override
  String get tabMonitor => 'Monitor';

  @override
  String get tabRecordings => 'Recordings';

  @override
  String get tabProfile => 'Profile';

  @override
  String get tabSettings => 'Settings';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get apply => 'Apply';

  @override
  String get connect => 'Connect';

  @override
  String get disconnect => 'Disconnect';

  @override
  String get send => 'Send';

  @override
  String get clear => 'Clear';

  @override
  String get notSet => 'Not set';

  @override
  String get none => 'None';

  @override
  String get bpm => 'bpm';

  @override
  String percentValue(int value) {
    return '$value percent';
  }

  @override
  String recordingSaved(String duration) {
    return 'Recording saved (encrypted) · $duration';
  }

  @override
  String get notMonitoring => 'NOT MONITORING';

  @override
  String get linkReconnecting => 'Device link reconnecting';

  @override
  String get linkLostBanner => 'Device link lost';

  @override
  String get electrodeOff => 'Electrode off';

  @override
  String get checkLeads => 'Check lead placement';

  @override
  String get batteryLowTitle => 'Device battery low';

  @override
  String get batteryLowText => 'Charge the device soon';

  @override
  String batteryLevel(int percent) {
    return 'Device battery $percent percent';
  }

  @override
  String get connectTitle => 'Connect to device';

  @override
  String get connectSubtitle =>
      'ECG monitor over TCP (simulator). For a Bluetooth sensor, switch the device type in Settings.';

  @override
  String get host => 'Host';

  @override
  String get port => 'Port';

  @override
  String get linkLive => 'Live';

  @override
  String get linkLinking => 'Linking';

  @override
  String get linkLost => 'Lost';

  @override
  String get linkOffline => 'Offline';

  @override
  String get heartRateLabel => 'HEART RATE';

  @override
  String get fromEcg => '· from ECG';

  @override
  String get fromSensor => '· from sensor';

  @override
  String hrHigh(int limit) {
    return 'HIGH > $limit';
  }

  @override
  String hrLow(int limit) {
    return 'LOW < $limit';
  }

  @override
  String heartRateSemantics(int bpm) {
    return 'Heart rate $bpm beats per minute';
  }

  @override
  String get heartRateUnknown => 'Heart rate unknown';

  @override
  String get statMin => 'MIN';

  @override
  String get statAvg => 'AVG';

  @override
  String get statMax => 'MAX';

  @override
  String get last5min => 'last 5 min';

  @override
  String trendSemantics(int low, int high) {
    return 'Heart-rate trend, from $low to $high beats per minute';
  }

  @override
  String get ecgLabel => 'ECG';

  @override
  String get ecgScale => 'Lead II · 25 mm/s · 10 mm/mV';

  @override
  String get ecgSemantics => 'Live ECG trace';

  @override
  String get ecgSemanticsDimmed => 'ECG trace, not live: device link lost';

  @override
  String get noEcgTitle => 'Heart-rate sensor';

  @override
  String get noEcgText =>
      'This sensor sends heart rate and beat intervals, not an ECG. Rhythm screening still works on the beat intervals.';

  @override
  String rec(String duration) {
    return 'REC $duration';
  }

  @override
  String recSemantics(String duration) {
    return 'Recording for $duration';
  }

  @override
  String get rrIrregular => 'Irregular RR';

  @override
  String get rrRegular => 'Regular RR';

  @override
  String prematureBeats(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count premature beats',
      one: '1 premature beat',
    );
    return '$_temp0';
  }

  @override
  String get noDataLost => 'No data lost';

  @override
  String samplesLost(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count samples lost',
      one: '1 sample lost',
    );
    return '$_temp0';
  }

  @override
  String get stopRecording => 'Stop recording';

  @override
  String get startRecording => 'Start recording';

  @override
  String get markSymptom => 'Mark a symptom';

  @override
  String markSymptomCount(int count) {
    return 'Mark a symptom · $count logged';
  }

  @override
  String get symptomQuestion => 'What are you feeling?';

  @override
  String get symptomHint => 'It is marked on the ECG at this exact moment.';

  @override
  String symptomMarked(String symptom) {
    return '$symptom marked on the ECG';
  }

  @override
  String get connectDevice => 'Connect a device';

  @override
  String get symptomPalpitations => 'Palpitations';

  @override
  String get symptomDizziness => 'Dizziness';

  @override
  String get symptomChestPain => 'Chest pain';

  @override
  String get symptomShortnessOfBreath => 'Shortness of breath';

  @override
  String get symptomFatigue => 'Fatigue';

  @override
  String get symptomExercise => 'Exercise';

  @override
  String get bleTitle => 'Bluetooth heart-rate sensor';

  @override
  String get bleSubtitle =>
      'Chest strap, watch or any sensor with the standard Heart Rate Service. Heart rate only, no ECG.';

  @override
  String bleLastUsed(String address) {
    return 'Last used · $address';
  }

  @override
  String get bleNoBluetooth => 'This phone has no Bluetooth LE.';

  @override
  String get blePermission =>
      'PulseBridge needs the \"Nearby devices\" permission to find sensors.';

  @override
  String get bleOff => 'Bluetooth is off. Turn it on and scan again.';

  @override
  String bleScanFailed(String error) {
    return 'Scan failed: $error';
  }

  @override
  String get bleSearching => 'Looking for sensors…';

  @override
  String get bleNoneFound =>
      'No sensors found. Wear the strap (it wakes on skin contact) or, on another phone, open nRF Connect → Advertiser and add the Heart Rate service.';

  @override
  String get bleUnnamed => 'Unnamed device';

  @override
  String bleHrSensor(String address) {
    return 'Heart-rate sensor · $address';
  }

  @override
  String get bleScanAgain => 'Scan again';

  @override
  String bleSignal(int bars) {
    return 'Signal $bars of 4';
  }

  @override
  String get recordingsError => 'Could not read recordings';

  @override
  String get noRecordings => 'No recordings yet';

  @override
  String get noRecordingsText =>
      'Start a recording on the Monitor tab. Every session is stored encrypted on this device.';

  @override
  String get encryptionNote => 'AES-256-GCM · key held in the Android Keystore';

  @override
  String get lock => 'Lock';

  @override
  String get avgBpm => 'avg bpm';

  @override
  String bpmRange(int low, int high) {
    return '$low–$high bpm';
  }

  @override
  String prematureShort(int count) {
    return '$count premature';
  }

  @override
  String alarmsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count alarms',
      one: '1 alarm',
    );
    return '$_temp0';
  }

  @override
  String lostPercent(String amount) {
    return '$amount% lost';
  }

  @override
  String get deleteTitle => 'Delete recording?';

  @override
  String get deleteText =>
      'The ECG and all data of this session are removed from the device.';

  @override
  String openRecording(String date, String duration, int bpm) {
    return 'Recording of $date, $duration, average $bpm bpm';
  }

  @override
  String get pdfReport => 'PDF report';

  @override
  String get fhirExport => 'FHIR export';

  @override
  String get statAverage => 'Average';

  @override
  String get statMinShort => 'Min';

  @override
  String get statMaxShort => 'Max';

  @override
  String get statDuration => 'Duration';

  @override
  String get statPremature => 'Premature';

  @override
  String get statDataLost => 'Data lost';

  @override
  String get sectionHeartRate => 'Heart rate';

  @override
  String hrBand(int low, int high) {
    return '$low–$high bpm band';
  }

  @override
  String get sectionEcgReview => 'ECG review';

  @override
  String ecgDecryptError(String error) {
    return 'Could not decrypt the ECG: $error';
  }

  @override
  String get noEcgRecording =>
      'No ECG in this recording: it came from a heart-rate sensor.';

  @override
  String get sectionEvents => 'Events';

  @override
  String get tapToSeeEcg => 'tap to see the ECG';

  @override
  String stripRange(String from, String to, String length) {
    return '$from – $to of $length';
  }

  @override
  String stripSemantics(String from, String to) {
    return 'ECG strip from $from to $to';
  }

  @override
  String get eventRecordingStarted => 'Recording started';

  @override
  String get eventRecordingStopped => 'Recording stopped';

  @override
  String get eventDeviceConnected => 'Device connected';

  @override
  String get eventReconnecting => 'Reconnecting';

  @override
  String get eventLinkLost => 'Link lost';

  @override
  String eventLinkLostReason(String reason) {
    return 'Link lost: $reason';
  }

  @override
  String get eventElectrodeOffCleared => 'Electrode back on';

  @override
  String get eventLowBattery => 'Low battery';

  @override
  String get eventLowBatteryCleared => 'Battery recovered';

  @override
  String get eventPremature => 'Premature beat';

  @override
  String eventHrOutside(int bpm, int low, int high) {
    return 'Heart rate $bpm bpm outside $low–$high';
  }

  @override
  String get reportTitle => 'Report for the physician';

  @override
  String get reportPdfTitle => 'ECG recording report';

  @override
  String recordedOn(String date) {
    return 'Recorded $date';
  }

  @override
  String get disclaimer =>
      'Portfolio project, not a medical device. Rhythm indicators are screening aids, not a diagnosis.';

  @override
  String pageOf(int page, int total) {
    return 'Page $page of $total';
  }

  @override
  String get patient => 'Patient';

  @override
  String get recording => 'Recording';

  @override
  String get name => 'Name';

  @override
  String get ageSex => 'Age · sex';

  @override
  String ageBorn(int age, int year) {
    return '$age years (born $year)';
  }

  @override
  String get noProfile => 'No patient profile recorded';

  @override
  String get profileLabel => 'Profile';

  @override
  String get start => 'Start';

  @override
  String get device => 'Device';

  @override
  String deviceDesc(String id, int rate) {
    return '$id · $rate Hz, single lead';
  }

  @override
  String get alarmLimits => 'Alarm limits';

  @override
  String get signalLost => 'Signal lost';

  @override
  String signalLostValue(String amount, int lost, int total) {
    return '$amount % ($lost of $total samples)';
  }

  @override
  String get averageHr => 'Average HR';

  @override
  String get minHr => 'Min HR';

  @override
  String get maxHr => 'Max HR';

  @override
  String get prematureBeatsLabel => 'Premature beats';

  @override
  String get symptomsLabel => 'Symptoms';

  @override
  String get alarmsLabel => 'Alarms';

  @override
  String findingPremature(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count premature beats flagged (RR below 80 % of the recent median).',
      one: '1 premature beat flagged (RR below 80 % of the recent median).',
    );
    return '$_temp0';
  }

  @override
  String get findingNoPremature => 'No premature beats flagged.';

  @override
  String findingAlarms(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count device or heart-rate alarms during the recording.',
      one: '1 device or heart-rate alarm during the recording.',
    );
    return '$_temp0';
  }

  @override
  String findingSymptoms(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count symptoms reported by the patient; the ECG at each one is shown below.',
      one: '1 symptom reported by the patient; the ECG at it is shown below.',
    );
    return '$_temp0';
  }

  @override
  String get notEnoughHr => 'Not enough heart-rate readings to plot.';

  @override
  String get ecgScaleNote =>
      'Lead II · 25 mm/s · 10 mm/mV · raw signal, baseline removed per strip. Grey bands mark lost samples.';

  @override
  String get symptomTag => 'SYMPTOM';

  @override
  String get alarmTag => 'ALARM';

  @override
  String get startOfRecording => 'Start of recording';

  @override
  String atTime(String time) {
    return 'at $time';
  }

  @override
  String get eventLog => 'Event log';

  @override
  String get time => 'Time';

  @override
  String get type => 'Type';

  @override
  String get event => 'Event';

  @override
  String get noEvents => 'No events.';

  @override
  String get kindAlarm => 'Alarm';

  @override
  String get kindLink => 'Link';

  @override
  String get kindSymptom => 'Symptom';

  @override
  String get kindInfo => 'Info';

  @override
  String get kindRhythm => 'Rhythm';

  @override
  String prematureNotListed(int count) {
    return '$count individual premature-beat markers are not listed.';
  }

  @override
  String fhirBuildError(String error) {
    return 'Could not build the export: $error';
  }

  @override
  String get size => 'Size';

  @override
  String get fhirCodes =>
      'Codes: LOINC (heart rate, EKG study, symptom), SNOMED CT (symptoms), ISO/IEEE 11073 MDC (ECG lead II), UCUM units.';

  @override
  String get shareFile => 'Share as file';

  @override
  String get fhirSendNoServer => 'Send to FHIR server (set one in Settings)';

  @override
  String fhirSendTo(String server) {
    return 'Send to $server';
  }

  @override
  String get preview => 'Preview';

  @override
  String get fhirSendTitle => 'Send health data?';

  @override
  String fhirSendText(String server) {
    return 'This recording and the patient profile will be sent to\n$server';
  }

  @override
  String fhirAccepted(int count) {
    return 'Accepted · $count resources created';
  }

  @override
  String fhirNotSent(String error) {
    return 'Not sent: $error';
  }

  @override
  String get fhirShareSubject => 'ECG recording (FHIR)';

  @override
  String get firmwareTitle => 'Device firmware';

  @override
  String get fwInstalled => 'INSTALLED';

  @override
  String get fwAvailable => 'AVAILABLE';

  @override
  String get fwChanges =>
      'What changes in 1.1.0: faster lead-off detection and lower power use while streaming.';

  @override
  String get fwConnectFirst => 'Connect to the ECG device on the Monitor tab.';

  @override
  String get fwStopRecording =>
      'Stop the recording first. An update never interrupts monitoring.';

  @override
  String get fwCancel => 'Cancel update';

  @override
  String get fwUpToDate => 'Up to date';

  @override
  String fwInstall(String version) {
    return 'Install $version';
  }

  @override
  String get fwSending => 'Sending';

  @override
  String get fwWaitingLink => 'Link lost, will resume';

  @override
  String get fwVerifying => 'Device is checking the image';

  @override
  String get fwRestarting => 'Device is restarting';

  @override
  String get fwDone => 'Updated';

  @override
  String get fwFailed => 'Update failed';

  @override
  String get fwCancelled => 'Cancelled';

  @override
  String fwProgressKb(String sentKb, String totalKb) {
    return '$sentKb of $totalKb KB';
  }

  @override
  String get fwKeptOld =>
      'The device kept its current firmware and works as before.';

  @override
  String get fwStepSend => 'Send';

  @override
  String get fwStepVerify => 'Verify';

  @override
  String get fwStepRestart => 'Restart';

  @override
  String get fwStepConfirm => 'Confirm';

  @override
  String get fwHowTitle => 'How the update stays safe';

  @override
  String get fwHow1 =>
      'Sent in 512-byte pieces; each is confirmed before the next.';

  @override
  String get fwHow2 => 'If the link drops, it resumes where it stopped.';

  @override
  String get fwHow3 =>
      'The device checks the whole image (size, CRC-32, header) before installing anything.';

  @override
  String get fwHow4 => 'A failed check leaves the current firmware running.';

  @override
  String get fwHow5 =>
      'Done only when the device restarts reporting the new version.';

  @override
  String get fwProgressSemantics => 'Firmware update progress';

  @override
  String get editProfile => 'Edit profile';

  @override
  String get statRecordings => 'Recordings';

  @override
  String get statTimeMonitored => 'Time monitored';

  @override
  String get statAverageHr => 'Average HR';

  @override
  String get statSymptoms => 'Symptoms logged';

  @override
  String maxHrSuggestion(int maxHr) {
    return 'Age-predicted maximum heart rate is $maxHr bpm. Use it as the upper alarm limit?';
  }

  @override
  String get conditions => 'Conditions';

  @override
  String get medication => 'Medication';

  @override
  String get noneRecorded => 'None recorded';

  @override
  String get physician => 'Physician';

  @override
  String get emergencyContact => 'Emergency contact';

  @override
  String ageYears(int age) {
    return '$age years';
  }

  @override
  String get setupProfile => 'Set up your profile';

  @override
  String get setupProfileText => 'Your age personalises the heart-rate limits.';

  @override
  String get addDetails => 'Add details';

  @override
  String get encryptedOnDevice => 'Encrypted on device';

  @override
  String get fullName => 'Full name';

  @override
  String get yearOfBirth => 'Year of birth';

  @override
  String get sexLabel => 'Sex';

  @override
  String get sexFemale => 'Female';

  @override
  String get sexMale => 'Male';

  @override
  String get sexOther => 'Other';

  @override
  String get medicationHint => 'e.g. Bisoprolol 2.5 mg';

  @override
  String get addItem => 'Add';

  @override
  String get emergencyContactHint => 'Emergency contact (name and phone)';

  @override
  String get condHypertension => 'Hypertension';

  @override
  String get condAtrialFibrillation => 'Atrial fibrillation';

  @override
  String get condDiabetes => 'Diabetes';

  @override
  String get condHeartFailure => 'Heart failure';

  @override
  String get condAsthma => 'Asthma';

  @override
  String get hrLimitsTitle => 'Heart-rate alarm limits';

  @override
  String get limitLow => 'LOW';

  @override
  String get limitHigh => 'HIGH';

  @override
  String get hrLimitsText =>
      'The monitor turns red and logs an alarm when the heart rate leaves this band.';

  @override
  String hrLimitsSemantics(int low, int high) {
    return 'Heart-rate alarm limits, low $low, high $high beats per minute';
  }

  @override
  String get deviceTitle => 'Device';

  @override
  String get ecgSimulator => 'ECG simulator';

  @override
  String get bluetooth => 'Bluetooth';

  @override
  String get simulatorText =>
      'ECG, heart rate and alarms over TCP. Change host and port when connecting.';

  @override
  String firmwareSubtitle(String installed, String available) {
    return 'Installed $installed · available $available';
  }

  @override
  String get sensor => 'Sensor';

  @override
  String get noneYet => 'None yet';

  @override
  String get forgetSensor => 'Forget this sensor';

  @override
  String get bluetoothText =>
      'Any sensor with the standard Bluetooth Heart Rate Service: chest straps such as Polar H10, or nRF Connect on another phone. Heart rate and beat intervals, no ECG.';

  @override
  String get typeAppliesNext =>
      'Changing the type applies to the next connection.';

  @override
  String get server => 'Server';

  @override
  String get setServer => 'Set server';

  @override
  String get fhirSettingsText =>
      'Recordings can be exported as HL7 FHIR R4 (a file, or sent to this server over https). Public test servers are visible to anyone: never send real patient data there.';

  @override
  String get fhirServerTitle => 'FHIR server';

  @override
  String get baseUrl => 'Base URL';

  @override
  String get useHttps => 'Use an https:// address';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'System';

  @override
  String get privacyTitle => 'Privacy';

  @override
  String get storage => 'Storage';

  @override
  String get key => 'Key';

  @override
  String get privacyText =>
      'Recordings, profile and settings stay in the app\'s private storage. The key cannot be exported, so copied files are unreadable. Only a report or FHIR export you choose to share leaves the device.';

  @override
  String get aboutTitle => 'About';

  @override
  String get version => 'Version';

  @override
  String get aboutText =>
      'PulseBridge is a portfolio project, not a medical device. Rhythm indicators are screening aids and not a diagnosis.';

  @override
  String get clinicianAccess => 'Clinician access';

  @override
  String get createPinHint =>
      'Open the Recordings tab to create the clinician PIN.';

  @override
  String get unlocked => 'Unlocked';

  @override
  String get locked => 'Locked';

  @override
  String get fingerprintUnlock => 'Unlock with fingerprint';

  @override
  String get noFingerprint => 'No fingerprint enrolled on this device';

  @override
  String get pinFallback => 'The PIN still works as a fallback';

  @override
  String get unlockToChange => 'Unlock the Recordings tab to change this';

  @override
  String get fingerprintNotConfirmed => 'Fingerprint not confirmed';

  @override
  String get changePin => 'Change PIN';

  @override
  String get lockNow => 'Lock now';

  @override
  String get lockInfo =>
      'The area also locks 30 s after the app goes to the background. Five wrong PINs pause entry, for longer each time.';

  @override
  String lockError(String error) {
    return 'Could not read the lock: $error';
  }

  @override
  String get lockedTitle => 'Clinical area locked';

  @override
  String get lockedSubtitle =>
      'Recordings contain health data. Enter the clinician PIN.';

  @override
  String get fingerprintFailed => 'Fingerprint not recognised. Use the PIN.';

  @override
  String wrongPinAttempts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Wrong PIN · $count attempts before a pause',
      one: 'Wrong PIN · 1 attempt before a pause',
    );
    return '$_temp0';
  }

  @override
  String get tooManyPins => 'Too many wrong PINs';

  @override
  String tryAgainIn(String time) {
    return 'Too many wrong PINs. Try again in $time';
  }

  @override
  String get protectTitle => 'Protect the clinical area';

  @override
  String get protectSubtitle =>
      'Choose a 6-digit PIN. It will be needed to open recordings and export reports.';

  @override
  String get confirmPin => 'Confirm the PIN';

  @override
  String get confirmPinSubtitle => 'Enter the same 6 digits again.';

  @override
  String get pinMismatch => 'The PINs didn\'t match. Start again.';

  @override
  String get currentPin => 'Current PIN';

  @override
  String get newPin => 'New PIN';

  @override
  String get confirmNewPin => 'Confirm new PIN';

  @override
  String get currentPinSubtitle => 'Enter the PIN in use now.';

  @override
  String get newPinSubtitle => 'Choose 6 new digits.';

  @override
  String get confirmNewPinSubtitle => 'Enter the new PIN again.';

  @override
  String get wrongPin => 'Wrong PIN';

  @override
  String get newPinMismatch =>
      'The PINs didn\'t match. Choose the new PIN again.';

  @override
  String get pinChanged => 'PIN changed';

  @override
  String get useFingerprint => 'Use fingerprint';

  @override
  String get deleteDigit => 'Delete';

  @override
  String pinDigits(int count) {
    return '$count of 6 digits entered';
  }

  @override
  String get biometricReason => 'Unlock the clinical area';

  @override
  String get biometricEnableReason => 'Confirm to enable fingerprint unlock';
}
