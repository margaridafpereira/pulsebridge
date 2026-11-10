import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('pt'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'PulseBridge'**
  String get appTitle;

  /// No description provided for @tabMonitor.
  ///
  /// In en, this message translates to:
  /// **'Monitor'**
  String get tabMonitor;

  /// No description provided for @tabRecordings.
  ///
  /// In en, this message translates to:
  /// **'Recordings'**
  String get tabRecordings;

  /// No description provided for @tabProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get tabProfile;

  /// No description provided for @tabSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get tabSettings;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @connect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connect;

  /// No description provided for @disconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get disconnect;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @notSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get notSet;

  /// No description provided for @none.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get none;

  /// No description provided for @bpm.
  ///
  /// In en, this message translates to:
  /// **'bpm'**
  String get bpm;

  /// No description provided for @percentValue.
  ///
  /// In en, this message translates to:
  /// **'{value} percent'**
  String percentValue(int value);

  /// No description provided for @recordingSaved.
  ///
  /// In en, this message translates to:
  /// **'Recording saved (encrypted) · {duration}'**
  String recordingSaved(String duration);

  /// No description provided for @notMonitoring.
  ///
  /// In en, this message translates to:
  /// **'NOT MONITORING'**
  String get notMonitoring;

  /// No description provided for @linkReconnecting.
  ///
  /// In en, this message translates to:
  /// **'Device link reconnecting'**
  String get linkReconnecting;

  /// No description provided for @linkLostBanner.
  ///
  /// In en, this message translates to:
  /// **'Device link lost'**
  String get linkLostBanner;

  /// No description provided for @electrodeOff.
  ///
  /// In en, this message translates to:
  /// **'Electrode off'**
  String get electrodeOff;

  /// No description provided for @checkLeads.
  ///
  /// In en, this message translates to:
  /// **'Check lead placement'**
  String get checkLeads;

  /// No description provided for @batteryLowTitle.
  ///
  /// In en, this message translates to:
  /// **'Device battery low'**
  String get batteryLowTitle;

  /// No description provided for @batteryLowText.
  ///
  /// In en, this message translates to:
  /// **'Charge the device soon'**
  String get batteryLowText;

  /// No description provided for @batteryLevel.
  ///
  /// In en, this message translates to:
  /// **'Device battery {percent} percent'**
  String batteryLevel(int percent);

  /// No description provided for @connectTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect to device'**
  String get connectTitle;

  /// No description provided for @connectSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ECG monitor over TCP (simulator). For a Bluetooth sensor, switch the device type in Settings.'**
  String get connectSubtitle;

  /// No description provided for @host.
  ///
  /// In en, this message translates to:
  /// **'Host'**
  String get host;

  /// No description provided for @port.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get port;

  /// No description provided for @linkLive.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get linkLive;

  /// No description provided for @linkLinking.
  ///
  /// In en, this message translates to:
  /// **'Linking'**
  String get linkLinking;

  /// No description provided for @linkLost.
  ///
  /// In en, this message translates to:
  /// **'Lost'**
  String get linkLost;

  /// No description provided for @linkOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get linkOffline;

  /// No description provided for @heartRateLabel.
  ///
  /// In en, this message translates to:
  /// **'HEART RATE'**
  String get heartRateLabel;

  /// No description provided for @fromEcg.
  ///
  /// In en, this message translates to:
  /// **'· from ECG'**
  String get fromEcg;

  /// No description provided for @fromSensor.
  ///
  /// In en, this message translates to:
  /// **'· from sensor'**
  String get fromSensor;

  /// No description provided for @hrHigh.
  ///
  /// In en, this message translates to:
  /// **'HIGH > {limit}'**
  String hrHigh(int limit);

  /// No description provided for @hrLow.
  ///
  /// In en, this message translates to:
  /// **'LOW < {limit}'**
  String hrLow(int limit);

  /// No description provided for @heartRateSemantics.
  ///
  /// In en, this message translates to:
  /// **'Heart rate {bpm} beats per minute'**
  String heartRateSemantics(int bpm);

  /// No description provided for @heartRateUnknown.
  ///
  /// In en, this message translates to:
  /// **'Heart rate unknown'**
  String get heartRateUnknown;

  /// No description provided for @statMin.
  ///
  /// In en, this message translates to:
  /// **'MIN'**
  String get statMin;

  /// No description provided for @statAvg.
  ///
  /// In en, this message translates to:
  /// **'AVG'**
  String get statAvg;

  /// No description provided for @statMax.
  ///
  /// In en, this message translates to:
  /// **'MAX'**
  String get statMax;

  /// No description provided for @last5min.
  ///
  /// In en, this message translates to:
  /// **'last 5 min'**
  String get last5min;

  /// No description provided for @trendSemantics.
  ///
  /// In en, this message translates to:
  /// **'Heart-rate trend, from {low} to {high} beats per minute'**
  String trendSemantics(int low, int high);

  /// No description provided for @ecgLabel.
  ///
  /// In en, this message translates to:
  /// **'ECG'**
  String get ecgLabel;

  /// No description provided for @ecgScale.
  ///
  /// In en, this message translates to:
  /// **'Lead II · 25 mm/s · 10 mm/mV'**
  String get ecgScale;

  /// No description provided for @ecgSemantics.
  ///
  /// In en, this message translates to:
  /// **'Live ECG trace'**
  String get ecgSemantics;

  /// No description provided for @ecgSemanticsDimmed.
  ///
  /// In en, this message translates to:
  /// **'ECG trace, not live: device link lost'**
  String get ecgSemanticsDimmed;

  /// No description provided for @noEcgTitle.
  ///
  /// In en, this message translates to:
  /// **'Heart-rate sensor'**
  String get noEcgTitle;

  /// No description provided for @noEcgText.
  ///
  /// In en, this message translates to:
  /// **'This sensor sends heart rate and beat intervals, not an ECG. Rhythm screening still works on the beat intervals.'**
  String get noEcgText;

  /// No description provided for @rec.
  ///
  /// In en, this message translates to:
  /// **'REC {duration}'**
  String rec(String duration);

  /// No description provided for @recSemantics.
  ///
  /// In en, this message translates to:
  /// **'Recording for {duration}'**
  String recSemantics(String duration);

  /// No description provided for @rrIrregular.
  ///
  /// In en, this message translates to:
  /// **'Irregular RR'**
  String get rrIrregular;

  /// No description provided for @rrRegular.
  ///
  /// In en, this message translates to:
  /// **'Regular RR'**
  String get rrRegular;

  /// No description provided for @prematureBeats.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 premature beat} other{{count} premature beats}}'**
  String prematureBeats(int count);

  /// No description provided for @noDataLost.
  ///
  /// In en, this message translates to:
  /// **'No data lost'**
  String get noDataLost;

  /// No description provided for @samplesLost.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 sample lost} other{{count} samples lost}}'**
  String samplesLost(int count);

  /// No description provided for @stopRecording.
  ///
  /// In en, this message translates to:
  /// **'Stop recording'**
  String get stopRecording;

  /// No description provided for @startRecording.
  ///
  /// In en, this message translates to:
  /// **'Start recording'**
  String get startRecording;

  /// No description provided for @markSymptom.
  ///
  /// In en, this message translates to:
  /// **'Mark a symptom'**
  String get markSymptom;

  /// No description provided for @markSymptomCount.
  ///
  /// In en, this message translates to:
  /// **'Mark a symptom · {count} logged'**
  String markSymptomCount(int count);

  /// No description provided for @symptomQuestion.
  ///
  /// In en, this message translates to:
  /// **'What are you feeling?'**
  String get symptomQuestion;

  /// No description provided for @symptomHint.
  ///
  /// In en, this message translates to:
  /// **'It is marked on the ECG at this exact moment.'**
  String get symptomHint;

  /// No description provided for @symptomMarked.
  ///
  /// In en, this message translates to:
  /// **'{symptom} marked on the ECG'**
  String symptomMarked(String symptom);

  /// No description provided for @connectDevice.
  ///
  /// In en, this message translates to:
  /// **'Connect a device'**
  String get connectDevice;

  /// No description provided for @symptomPalpitations.
  ///
  /// In en, this message translates to:
  /// **'Palpitations'**
  String get symptomPalpitations;

  /// No description provided for @symptomDizziness.
  ///
  /// In en, this message translates to:
  /// **'Dizziness'**
  String get symptomDizziness;

  /// No description provided for @symptomChestPain.
  ///
  /// In en, this message translates to:
  /// **'Chest pain'**
  String get symptomChestPain;

  /// No description provided for @symptomShortnessOfBreath.
  ///
  /// In en, this message translates to:
  /// **'Shortness of breath'**
  String get symptomShortnessOfBreath;

  /// No description provided for @symptomFatigue.
  ///
  /// In en, this message translates to:
  /// **'Fatigue'**
  String get symptomFatigue;

  /// No description provided for @symptomExercise.
  ///
  /// In en, this message translates to:
  /// **'Exercise'**
  String get symptomExercise;

  /// No description provided for @bleTitle.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth heart-rate sensor'**
  String get bleTitle;

  /// No description provided for @bleSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Chest strap, watch or any sensor with the standard Heart Rate Service. Heart rate only, no ECG.'**
  String get bleSubtitle;

  /// No description provided for @bleLastUsed.
  ///
  /// In en, this message translates to:
  /// **'Last used · {address}'**
  String bleLastUsed(String address);

  /// No description provided for @bleNoBluetooth.
  ///
  /// In en, this message translates to:
  /// **'This phone has no Bluetooth LE.'**
  String get bleNoBluetooth;

  /// No description provided for @blePermission.
  ///
  /// In en, this message translates to:
  /// **'PulseBridge needs the \"Nearby devices\" permission to find sensors.'**
  String get blePermission;

  /// No description provided for @bleOff.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth is off. Turn it on and scan again.'**
  String get bleOff;

  /// No description provided for @bleScanFailed.
  ///
  /// In en, this message translates to:
  /// **'Scan failed: {error}'**
  String bleScanFailed(String error);

  /// No description provided for @bleSearching.
  ///
  /// In en, this message translates to:
  /// **'Looking for sensors…'**
  String get bleSearching;

  /// No description provided for @bleNoneFound.
  ///
  /// In en, this message translates to:
  /// **'No sensors found. Wear the strap (it wakes on skin contact) or, on another phone, open nRF Connect → Advertiser and add the Heart Rate service.'**
  String get bleNoneFound;

  /// No description provided for @bleUnnamed.
  ///
  /// In en, this message translates to:
  /// **'Unnamed device'**
  String get bleUnnamed;

  /// No description provided for @bleHrSensor.
  ///
  /// In en, this message translates to:
  /// **'Heart-rate sensor · {address}'**
  String bleHrSensor(String address);

  /// No description provided for @bleScanAgain.
  ///
  /// In en, this message translates to:
  /// **'Scan again'**
  String get bleScanAgain;

  /// No description provided for @bleSignal.
  ///
  /// In en, this message translates to:
  /// **'Signal {bars} of 4'**
  String bleSignal(int bars);

  /// No description provided for @recordingsError.
  ///
  /// In en, this message translates to:
  /// **'Could not read recordings'**
  String get recordingsError;

  /// No description provided for @noRecordings.
  ///
  /// In en, this message translates to:
  /// **'No recordings yet'**
  String get noRecordings;

  /// No description provided for @noRecordingsText.
  ///
  /// In en, this message translates to:
  /// **'Start a recording on the Monitor tab. Every session is stored encrypted on this device.'**
  String get noRecordingsText;

  /// No description provided for @encryptionNote.
  ///
  /// In en, this message translates to:
  /// **'AES-256-GCM · key held in the Android Keystore'**
  String get encryptionNote;

  /// No description provided for @lock.
  ///
  /// In en, this message translates to:
  /// **'Lock'**
  String get lock;

  /// No description provided for @avgBpm.
  ///
  /// In en, this message translates to:
  /// **'avg bpm'**
  String get avgBpm;

  /// No description provided for @bpmRange.
  ///
  /// In en, this message translates to:
  /// **'{low}–{high} bpm'**
  String bpmRange(int low, int high);

  /// No description provided for @prematureShort.
  ///
  /// In en, this message translates to:
  /// **'{count} premature'**
  String prematureShort(int count);

  /// No description provided for @alarmsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 alarm} other{{count} alarms}}'**
  String alarmsCount(int count);

  /// No description provided for @lostPercent.
  ///
  /// In en, this message translates to:
  /// **'{amount}% lost'**
  String lostPercent(String amount);

  /// No description provided for @deleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete recording?'**
  String get deleteTitle;

  /// No description provided for @deleteText.
  ///
  /// In en, this message translates to:
  /// **'The ECG and all data of this session are removed from the device.'**
  String get deleteText;

  /// No description provided for @openRecording.
  ///
  /// In en, this message translates to:
  /// **'Recording of {date}, {duration}, average {bpm} bpm'**
  String openRecording(String date, String duration, int bpm);

  /// No description provided for @pdfReport.
  ///
  /// In en, this message translates to:
  /// **'PDF report'**
  String get pdfReport;

  /// No description provided for @fhirExport.
  ///
  /// In en, this message translates to:
  /// **'FHIR export'**
  String get fhirExport;

  /// No description provided for @statAverage.
  ///
  /// In en, this message translates to:
  /// **'Average'**
  String get statAverage;

  /// No description provided for @statMinShort.
  ///
  /// In en, this message translates to:
  /// **'Min'**
  String get statMinShort;

  /// No description provided for @statMaxShort.
  ///
  /// In en, this message translates to:
  /// **'Max'**
  String get statMaxShort;

  /// No description provided for @statDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get statDuration;

  /// No description provided for @statPremature.
  ///
  /// In en, this message translates to:
  /// **'Premature'**
  String get statPremature;

  /// No description provided for @statDataLost.
  ///
  /// In en, this message translates to:
  /// **'Data lost'**
  String get statDataLost;

  /// No description provided for @sectionHeartRate.
  ///
  /// In en, this message translates to:
  /// **'Heart rate'**
  String get sectionHeartRate;

  /// No description provided for @hrBand.
  ///
  /// In en, this message translates to:
  /// **'{low}–{high} bpm band'**
  String hrBand(int low, int high);

  /// No description provided for @sectionEcgReview.
  ///
  /// In en, this message translates to:
  /// **'ECG review'**
  String get sectionEcgReview;

  /// No description provided for @ecgDecryptError.
  ///
  /// In en, this message translates to:
  /// **'Could not decrypt the ECG: {error}'**
  String ecgDecryptError(String error);

  /// No description provided for @noEcgRecording.
  ///
  /// In en, this message translates to:
  /// **'No ECG in this recording: it came from a heart-rate sensor.'**
  String get noEcgRecording;

  /// No description provided for @sectionEvents.
  ///
  /// In en, this message translates to:
  /// **'Events'**
  String get sectionEvents;

  /// No description provided for @tapToSeeEcg.
  ///
  /// In en, this message translates to:
  /// **'tap to see the ECG'**
  String get tapToSeeEcg;

  /// No description provided for @stripRange.
  ///
  /// In en, this message translates to:
  /// **'{from} – {to} of {length}'**
  String stripRange(String from, String to, String length);

  /// No description provided for @stripSemantics.
  ///
  /// In en, this message translates to:
  /// **'ECG strip from {from} to {to}'**
  String stripSemantics(String from, String to);

  /// No description provided for @eventRecordingStarted.
  ///
  /// In en, this message translates to:
  /// **'Recording started'**
  String get eventRecordingStarted;

  /// No description provided for @eventRecordingStopped.
  ///
  /// In en, this message translates to:
  /// **'Recording stopped'**
  String get eventRecordingStopped;

  /// No description provided for @eventDeviceConnected.
  ///
  /// In en, this message translates to:
  /// **'Device connected'**
  String get eventDeviceConnected;

  /// No description provided for @eventReconnecting.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting'**
  String get eventReconnecting;

  /// No description provided for @eventLinkLost.
  ///
  /// In en, this message translates to:
  /// **'Link lost'**
  String get eventLinkLost;

  /// No description provided for @eventLinkLostReason.
  ///
  /// In en, this message translates to:
  /// **'Link lost: {reason}'**
  String eventLinkLostReason(String reason);

  /// No description provided for @eventElectrodeOffCleared.
  ///
  /// In en, this message translates to:
  /// **'Electrode back on'**
  String get eventElectrodeOffCleared;

  /// No description provided for @eventLowBattery.
  ///
  /// In en, this message translates to:
  /// **'Low battery'**
  String get eventLowBattery;

  /// No description provided for @eventLowBatteryCleared.
  ///
  /// In en, this message translates to:
  /// **'Battery recovered'**
  String get eventLowBatteryCleared;

  /// No description provided for @eventPremature.
  ///
  /// In en, this message translates to:
  /// **'Premature beat'**
  String get eventPremature;

  /// No description provided for @eventHrOutside.
  ///
  /// In en, this message translates to:
  /// **'Heart rate {bpm} bpm outside {low}–{high}'**
  String eventHrOutside(int bpm, int low, int high);

  /// No description provided for @reportTitle.
  ///
  /// In en, this message translates to:
  /// **'Report for the physician'**
  String get reportTitle;

  /// No description provided for @reportPdfTitle.
  ///
  /// In en, this message translates to:
  /// **'ECG recording report'**
  String get reportPdfTitle;

  /// No description provided for @recordedOn.
  ///
  /// In en, this message translates to:
  /// **'Recorded {date}'**
  String recordedOn(String date);

  /// No description provided for @disclaimer.
  ///
  /// In en, this message translates to:
  /// **'Portfolio project, not a medical device. Rhythm indicators are screening aids, not a diagnosis.'**
  String get disclaimer;

  /// No description provided for @pageOf.
  ///
  /// In en, this message translates to:
  /// **'Page {page} of {total}'**
  String pageOf(int page, int total);

  /// No description provided for @patient.
  ///
  /// In en, this message translates to:
  /// **'Patient'**
  String get patient;

  /// No description provided for @recording.
  ///
  /// In en, this message translates to:
  /// **'Recording'**
  String get recording;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @ageSex.
  ///
  /// In en, this message translates to:
  /// **'Age · sex'**
  String get ageSex;

  /// No description provided for @ageBorn.
  ///
  /// In en, this message translates to:
  /// **'{age} years (born {year})'**
  String ageBorn(int age, int year);

  /// No description provided for @noProfile.
  ///
  /// In en, this message translates to:
  /// **'No patient profile recorded'**
  String get noProfile;

  /// No description provided for @profileLabel.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileLabel;

  /// No description provided for @start.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

  /// No description provided for @device.
  ///
  /// In en, this message translates to:
  /// **'Device'**
  String get device;

  /// No description provided for @deviceDesc.
  ///
  /// In en, this message translates to:
  /// **'{id} · {rate} Hz, single lead'**
  String deviceDesc(String id, int rate);

  /// No description provided for @alarmLimits.
  ///
  /// In en, this message translates to:
  /// **'Alarm limits'**
  String get alarmLimits;

  /// No description provided for @signalLost.
  ///
  /// In en, this message translates to:
  /// **'Signal lost'**
  String get signalLost;

  /// No description provided for @signalLostValue.
  ///
  /// In en, this message translates to:
  /// **'{amount} % ({lost} of {total} samples)'**
  String signalLostValue(String amount, int lost, int total);

  /// No description provided for @averageHr.
  ///
  /// In en, this message translates to:
  /// **'Average HR'**
  String get averageHr;

  /// No description provided for @minHr.
  ///
  /// In en, this message translates to:
  /// **'Min HR'**
  String get minHr;

  /// No description provided for @maxHr.
  ///
  /// In en, this message translates to:
  /// **'Max HR'**
  String get maxHr;

  /// No description provided for @prematureBeatsLabel.
  ///
  /// In en, this message translates to:
  /// **'Premature beats'**
  String get prematureBeatsLabel;

  /// No description provided for @symptomsLabel.
  ///
  /// In en, this message translates to:
  /// **'Symptoms'**
  String get symptomsLabel;

  /// No description provided for @alarmsLabel.
  ///
  /// In en, this message translates to:
  /// **'Alarms'**
  String get alarmsLabel;

  /// No description provided for @findingPremature.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 premature beat flagged (RR below 80 % of the recent median).} other{{count} premature beats flagged (RR below 80 % of the recent median).}}'**
  String findingPremature(int count);

  /// No description provided for @findingNoPremature.
  ///
  /// In en, this message translates to:
  /// **'No premature beats flagged.'**
  String get findingNoPremature;

  /// No description provided for @findingAlarms.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 device or heart-rate alarm during the recording.} other{{count} device or heart-rate alarms during the recording.}}'**
  String findingAlarms(int count);

  /// No description provided for @findingSymptoms.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 symptom reported by the patient; the ECG at it is shown below.} other{{count} symptoms reported by the patient; the ECG at each one is shown below.}}'**
  String findingSymptoms(int count);

  /// No description provided for @notEnoughHr.
  ///
  /// In en, this message translates to:
  /// **'Not enough heart-rate readings to plot.'**
  String get notEnoughHr;

  /// No description provided for @ecgScaleNote.
  ///
  /// In en, this message translates to:
  /// **'Lead II · 25 mm/s · 10 mm/mV · raw signal, baseline removed per strip. Grey bands mark lost samples.'**
  String get ecgScaleNote;

  /// No description provided for @symptomTag.
  ///
  /// In en, this message translates to:
  /// **'SYMPTOM'**
  String get symptomTag;

  /// No description provided for @alarmTag.
  ///
  /// In en, this message translates to:
  /// **'ALARM'**
  String get alarmTag;

  /// No description provided for @startOfRecording.
  ///
  /// In en, this message translates to:
  /// **'Start of recording'**
  String get startOfRecording;

  /// No description provided for @atTime.
  ///
  /// In en, this message translates to:
  /// **'at {time}'**
  String atTime(String time);

  /// No description provided for @eventLog.
  ///
  /// In en, this message translates to:
  /// **'Event log'**
  String get eventLog;

  /// No description provided for @time.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get time;

  /// No description provided for @type.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get type;

  /// No description provided for @event.
  ///
  /// In en, this message translates to:
  /// **'Event'**
  String get event;

  /// No description provided for @noEvents.
  ///
  /// In en, this message translates to:
  /// **'No events.'**
  String get noEvents;

  /// No description provided for @kindAlarm.
  ///
  /// In en, this message translates to:
  /// **'Alarm'**
  String get kindAlarm;

  /// No description provided for @kindLink.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get kindLink;

  /// No description provided for @kindSymptom.
  ///
  /// In en, this message translates to:
  /// **'Symptom'**
  String get kindSymptom;

  /// No description provided for @kindInfo.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get kindInfo;

  /// No description provided for @kindRhythm.
  ///
  /// In en, this message translates to:
  /// **'Rhythm'**
  String get kindRhythm;

  /// No description provided for @prematureNotListed.
  ///
  /// In en, this message translates to:
  /// **'{count} individual premature-beat markers are not listed.'**
  String prematureNotListed(int count);

  /// No description provided for @fhirBuildError.
  ///
  /// In en, this message translates to:
  /// **'Could not build the export: {error}'**
  String fhirBuildError(String error);

  /// No description provided for @size.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get size;

  /// No description provided for @fhirCodes.
  ///
  /// In en, this message translates to:
  /// **'Codes: LOINC (heart rate, EKG study, symptom), SNOMED CT (symptoms), ISO/IEEE 11073 MDC (ECG lead II), UCUM units.'**
  String get fhirCodes;

  /// No description provided for @shareFile.
  ///
  /// In en, this message translates to:
  /// **'Share as file'**
  String get shareFile;

  /// No description provided for @fhirSendNoServer.
  ///
  /// In en, this message translates to:
  /// **'Send to FHIR server (set one in Settings)'**
  String get fhirSendNoServer;

  /// No description provided for @fhirSendTo.
  ///
  /// In en, this message translates to:
  /// **'Send to {server}'**
  String fhirSendTo(String server);

  /// No description provided for @preview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get preview;

  /// No description provided for @fhirSendTitle.
  ///
  /// In en, this message translates to:
  /// **'Send health data?'**
  String get fhirSendTitle;

  /// No description provided for @fhirSendText.
  ///
  /// In en, this message translates to:
  /// **'This recording and the patient profile will be sent to\n{server}'**
  String fhirSendText(String server);

  /// No description provided for @fhirAccepted.
  ///
  /// In en, this message translates to:
  /// **'Accepted · {count} resources created'**
  String fhirAccepted(int count);

  /// No description provided for @fhirNotSent.
  ///
  /// In en, this message translates to:
  /// **'Not sent: {error}'**
  String fhirNotSent(String error);

  /// No description provided for @fhirShareSubject.
  ///
  /// In en, this message translates to:
  /// **'ECG recording (FHIR)'**
  String get fhirShareSubject;

  /// No description provided for @firmwareTitle.
  ///
  /// In en, this message translates to:
  /// **'Device firmware'**
  String get firmwareTitle;

  /// No description provided for @fwInstalled.
  ///
  /// In en, this message translates to:
  /// **'INSTALLED'**
  String get fwInstalled;

  /// No description provided for @fwAvailable.
  ///
  /// In en, this message translates to:
  /// **'AVAILABLE'**
  String get fwAvailable;

  /// No description provided for @fwChanges.
  ///
  /// In en, this message translates to:
  /// **'What changes in 1.1.0: faster lead-off detection and lower power use while streaming.'**
  String get fwChanges;

  /// No description provided for @fwConnectFirst.
  ///
  /// In en, this message translates to:
  /// **'Connect to the ECG device on the Monitor tab.'**
  String get fwConnectFirst;

  /// No description provided for @fwStopRecording.
  ///
  /// In en, this message translates to:
  /// **'Stop the recording first. An update never interrupts monitoring.'**
  String get fwStopRecording;

  /// No description provided for @fwCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel update'**
  String get fwCancel;

  /// No description provided for @fwUpToDate.
  ///
  /// In en, this message translates to:
  /// **'Up to date'**
  String get fwUpToDate;

  /// No description provided for @fwInstall.
  ///
  /// In en, this message translates to:
  /// **'Install {version}'**
  String fwInstall(String version);

  /// No description provided for @fwSending.
  ///
  /// In en, this message translates to:
  /// **'Sending'**
  String get fwSending;

  /// No description provided for @fwWaitingLink.
  ///
  /// In en, this message translates to:
  /// **'Link lost, will resume'**
  String get fwWaitingLink;

  /// No description provided for @fwVerifying.
  ///
  /// In en, this message translates to:
  /// **'Device is checking the image'**
  String get fwVerifying;

  /// No description provided for @fwRestarting.
  ///
  /// In en, this message translates to:
  /// **'Device is restarting'**
  String get fwRestarting;

  /// No description provided for @fwDone.
  ///
  /// In en, this message translates to:
  /// **'Updated'**
  String get fwDone;

  /// No description provided for @fwFailed.
  ///
  /// In en, this message translates to:
  /// **'Update failed'**
  String get fwFailed;

  /// No description provided for @fwCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get fwCancelled;

  /// No description provided for @fwProgressKb.
  ///
  /// In en, this message translates to:
  /// **'{sentKb} of {totalKb} KB'**
  String fwProgressKb(String sentKb, String totalKb);

  /// No description provided for @fwKeptOld.
  ///
  /// In en, this message translates to:
  /// **'The device kept its current firmware and works as before.'**
  String get fwKeptOld;

  /// No description provided for @fwStepSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get fwStepSend;

  /// No description provided for @fwStepVerify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get fwStepVerify;

  /// No description provided for @fwStepRestart.
  ///
  /// In en, this message translates to:
  /// **'Restart'**
  String get fwStepRestart;

  /// No description provided for @fwStepConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get fwStepConfirm;

  /// No description provided for @fwHowTitle.
  ///
  /// In en, this message translates to:
  /// **'How the update stays safe'**
  String get fwHowTitle;

  /// No description provided for @fwHow1.
  ///
  /// In en, this message translates to:
  /// **'Sent in 512-byte pieces; each is confirmed before the next.'**
  String get fwHow1;

  /// No description provided for @fwHow2.
  ///
  /// In en, this message translates to:
  /// **'If the link drops, it resumes where it stopped.'**
  String get fwHow2;

  /// No description provided for @fwHow3.
  ///
  /// In en, this message translates to:
  /// **'The device checks the whole image (size, CRC-32, header) before installing anything.'**
  String get fwHow3;

  /// No description provided for @fwHow4.
  ///
  /// In en, this message translates to:
  /// **'A failed check leaves the current firmware running.'**
  String get fwHow4;

  /// No description provided for @fwHow5.
  ///
  /// In en, this message translates to:
  /// **'Done only when the device restarts reporting the new version.'**
  String get fwHow5;

  /// No description provided for @fwProgressSemantics.
  ///
  /// In en, this message translates to:
  /// **'Firmware update progress'**
  String get fwProgressSemantics;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get editProfile;

  /// No description provided for @statRecordings.
  ///
  /// In en, this message translates to:
  /// **'Recordings'**
  String get statRecordings;

  /// No description provided for @statTimeMonitored.
  ///
  /// In en, this message translates to:
  /// **'Time monitored'**
  String get statTimeMonitored;

  /// No description provided for @statAverageHr.
  ///
  /// In en, this message translates to:
  /// **'Average HR'**
  String get statAverageHr;

  /// No description provided for @statSymptoms.
  ///
  /// In en, this message translates to:
  /// **'Symptoms logged'**
  String get statSymptoms;

  /// No description provided for @maxHrSuggestion.
  ///
  /// In en, this message translates to:
  /// **'Age-predicted maximum heart rate is {maxHr} bpm. Use it as the upper alarm limit?'**
  String maxHrSuggestion(int maxHr);

  /// No description provided for @conditions.
  ///
  /// In en, this message translates to:
  /// **'Conditions'**
  String get conditions;

  /// No description provided for @medication.
  ///
  /// In en, this message translates to:
  /// **'Medication'**
  String get medication;

  /// No description provided for @noneRecorded.
  ///
  /// In en, this message translates to:
  /// **'None recorded'**
  String get noneRecorded;

  /// No description provided for @physician.
  ///
  /// In en, this message translates to:
  /// **'Physician'**
  String get physician;

  /// No description provided for @emergencyContact.
  ///
  /// In en, this message translates to:
  /// **'Emergency contact'**
  String get emergencyContact;

  /// No description provided for @ageYears.
  ///
  /// In en, this message translates to:
  /// **'{age} years'**
  String ageYears(int age);

  /// No description provided for @setupProfile.
  ///
  /// In en, this message translates to:
  /// **'Set up your profile'**
  String get setupProfile;

  /// No description provided for @setupProfileText.
  ///
  /// In en, this message translates to:
  /// **'Your age personalises the heart-rate limits.'**
  String get setupProfileText;

  /// No description provided for @addDetails.
  ///
  /// In en, this message translates to:
  /// **'Add details'**
  String get addDetails;

  /// No description provided for @encryptedOnDevice.
  ///
  /// In en, this message translates to:
  /// **'Encrypted on device'**
  String get encryptedOnDevice;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get fullName;

  /// No description provided for @yearOfBirth.
  ///
  /// In en, this message translates to:
  /// **'Year of birth'**
  String get yearOfBirth;

  /// No description provided for @sexLabel.
  ///
  /// In en, this message translates to:
  /// **'Sex'**
  String get sexLabel;

  /// No description provided for @sexFemale.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get sexFemale;

  /// No description provided for @sexMale.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get sexMale;

  /// No description provided for @sexOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get sexOther;

  /// No description provided for @medicationHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Bisoprolol 2.5 mg'**
  String get medicationHint;

  /// No description provided for @addItem.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get addItem;

  /// No description provided for @emergencyContactHint.
  ///
  /// In en, this message translates to:
  /// **'Emergency contact (name and phone)'**
  String get emergencyContactHint;

  /// No description provided for @condHypertension.
  ///
  /// In en, this message translates to:
  /// **'Hypertension'**
  String get condHypertension;

  /// No description provided for @condAtrialFibrillation.
  ///
  /// In en, this message translates to:
  /// **'Atrial fibrillation'**
  String get condAtrialFibrillation;

  /// No description provided for @condDiabetes.
  ///
  /// In en, this message translates to:
  /// **'Diabetes'**
  String get condDiabetes;

  /// No description provided for @condHeartFailure.
  ///
  /// In en, this message translates to:
  /// **'Heart failure'**
  String get condHeartFailure;

  /// No description provided for @condAsthma.
  ///
  /// In en, this message translates to:
  /// **'Asthma'**
  String get condAsthma;

  /// No description provided for @hrLimitsTitle.
  ///
  /// In en, this message translates to:
  /// **'Heart-rate alarm limits'**
  String get hrLimitsTitle;

  /// No description provided for @limitLow.
  ///
  /// In en, this message translates to:
  /// **'LOW'**
  String get limitLow;

  /// No description provided for @limitHigh.
  ///
  /// In en, this message translates to:
  /// **'HIGH'**
  String get limitHigh;

  /// No description provided for @hrLimitsText.
  ///
  /// In en, this message translates to:
  /// **'The monitor turns red and logs an alarm when the heart rate leaves this band.'**
  String get hrLimitsText;

  /// No description provided for @hrLimitsSemantics.
  ///
  /// In en, this message translates to:
  /// **'Heart-rate alarm limits, low {low}, high {high} beats per minute'**
  String hrLimitsSemantics(int low, int high);

  /// No description provided for @deviceTitle.
  ///
  /// In en, this message translates to:
  /// **'Device'**
  String get deviceTitle;

  /// No description provided for @ecgSimulator.
  ///
  /// In en, this message translates to:
  /// **'ECG simulator'**
  String get ecgSimulator;

  /// No description provided for @bluetooth.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth'**
  String get bluetooth;

  /// No description provided for @simulatorText.
  ///
  /// In en, this message translates to:
  /// **'ECG, heart rate and alarms over TCP. Change host and port when connecting.'**
  String get simulatorText;

  /// No description provided for @firmwareSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Installed {installed} · available {available}'**
  String firmwareSubtitle(String installed, String available);

  /// No description provided for @sensor.
  ///
  /// In en, this message translates to:
  /// **'Sensor'**
  String get sensor;

  /// No description provided for @noneYet.
  ///
  /// In en, this message translates to:
  /// **'None yet'**
  String get noneYet;

  /// No description provided for @forgetSensor.
  ///
  /// In en, this message translates to:
  /// **'Forget this sensor'**
  String get forgetSensor;

  /// No description provided for @bluetoothText.
  ///
  /// In en, this message translates to:
  /// **'Any sensor with the standard Bluetooth Heart Rate Service: chest straps such as Polar H10, or nRF Connect on another phone. Heart rate and beat intervals, no ECG.'**
  String get bluetoothText;

  /// No description provided for @typeAppliesNext.
  ///
  /// In en, this message translates to:
  /// **'Changing the type applies to the next connection.'**
  String get typeAppliesNext;

  /// No description provided for @server.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get server;

  /// No description provided for @setServer.
  ///
  /// In en, this message translates to:
  /// **'Set server'**
  String get setServer;

  /// No description provided for @fhirSettingsText.
  ///
  /// In en, this message translates to:
  /// **'Recordings can be exported as HL7 FHIR R4 (a file, or sent to this server over https). Public test servers are visible to anyone: never send real patient data there.'**
  String get fhirSettingsText;

  /// No description provided for @fhirServerTitle.
  ///
  /// In en, this message translates to:
  /// **'FHIR server'**
  String get fhirServerTitle;

  /// No description provided for @baseUrl.
  ///
  /// In en, this message translates to:
  /// **'Base URL'**
  String get baseUrl;

  /// No description provided for @useHttps.
  ///
  /// In en, this message translates to:
  /// **'Use an https:// address'**
  String get useHttps;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get languageSystem;

  /// No description provided for @privacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacyTitle;

  /// No description provided for @storage.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get storage;

  /// No description provided for @key.
  ///
  /// In en, this message translates to:
  /// **'Key'**
  String get key;

  /// No description provided for @privacyText.
  ///
  /// In en, this message translates to:
  /// **'Recordings, profile and settings stay in the app\'s private storage. The key cannot be exported, so copied files are unreadable. Only a report or FHIR export you choose to share leaves the device.'**
  String get privacyText;

  /// No description provided for @aboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get aboutTitle;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @aboutText.
  ///
  /// In en, this message translates to:
  /// **'PulseBridge is a portfolio project, not a medical device. Rhythm indicators are screening aids and not a diagnosis.'**
  String get aboutText;

  /// No description provided for @clinicianAccess.
  ///
  /// In en, this message translates to:
  /// **'Clinician access'**
  String get clinicianAccess;

  /// No description provided for @createPinHint.
  ///
  /// In en, this message translates to:
  /// **'Open the Recordings tab to create the clinician PIN.'**
  String get createPinHint;

  /// No description provided for @unlocked.
  ///
  /// In en, this message translates to:
  /// **'Unlocked'**
  String get unlocked;

  /// No description provided for @locked.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get locked;

  /// No description provided for @fingerprintUnlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock with fingerprint'**
  String get fingerprintUnlock;

  /// No description provided for @noFingerprint.
  ///
  /// In en, this message translates to:
  /// **'No fingerprint enrolled on this device'**
  String get noFingerprint;

  /// No description provided for @pinFallback.
  ///
  /// In en, this message translates to:
  /// **'The PIN still works as a fallback'**
  String get pinFallback;

  /// No description provided for @unlockToChange.
  ///
  /// In en, this message translates to:
  /// **'Unlock the Recordings tab to change this'**
  String get unlockToChange;

  /// No description provided for @fingerprintNotConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Fingerprint not confirmed'**
  String get fingerprintNotConfirmed;

  /// No description provided for @changePin.
  ///
  /// In en, this message translates to:
  /// **'Change PIN'**
  String get changePin;

  /// No description provided for @lockNow.
  ///
  /// In en, this message translates to:
  /// **'Lock now'**
  String get lockNow;

  /// No description provided for @lockInfo.
  ///
  /// In en, this message translates to:
  /// **'The area also locks 30 s after the app goes to the background. Five wrong PINs pause entry, for longer each time.'**
  String get lockInfo;

  /// No description provided for @lockError.
  ///
  /// In en, this message translates to:
  /// **'Could not read the lock: {error}'**
  String lockError(String error);

  /// No description provided for @lockedTitle.
  ///
  /// In en, this message translates to:
  /// **'Clinical area locked'**
  String get lockedTitle;

  /// No description provided for @lockedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Recordings contain health data. Enter the clinician PIN.'**
  String get lockedSubtitle;

  /// No description provided for @fingerprintFailed.
  ///
  /// In en, this message translates to:
  /// **'Fingerprint not recognised. Use the PIN.'**
  String get fingerprintFailed;

  /// No description provided for @wrongPinAttempts.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Wrong PIN · 1 attempt before a pause} other{Wrong PIN · {count} attempts before a pause}}'**
  String wrongPinAttempts(int count);

  /// No description provided for @tooManyPins.
  ///
  /// In en, this message translates to:
  /// **'Too many wrong PINs'**
  String get tooManyPins;

  /// No description provided for @tryAgainIn.
  ///
  /// In en, this message translates to:
  /// **'Too many wrong PINs. Try again in {time}'**
  String tryAgainIn(String time);

  /// No description provided for @protectTitle.
  ///
  /// In en, this message translates to:
  /// **'Protect the clinical area'**
  String get protectTitle;

  /// No description provided for @protectSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a 6-digit PIN. It will be needed to open recordings and export reports.'**
  String get protectSubtitle;

  /// No description provided for @confirmPin.
  ///
  /// In en, this message translates to:
  /// **'Confirm the PIN'**
  String get confirmPin;

  /// No description provided for @confirmPinSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter the same 6 digits again.'**
  String get confirmPinSubtitle;

  /// No description provided for @pinMismatch.
  ///
  /// In en, this message translates to:
  /// **'The PINs didn\'t match. Start again.'**
  String get pinMismatch;

  /// No description provided for @currentPin.
  ///
  /// In en, this message translates to:
  /// **'Current PIN'**
  String get currentPin;

  /// No description provided for @newPin.
  ///
  /// In en, this message translates to:
  /// **'New PIN'**
  String get newPin;

  /// No description provided for @confirmNewPin.
  ///
  /// In en, this message translates to:
  /// **'Confirm new PIN'**
  String get confirmNewPin;

  /// No description provided for @currentPinSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter the PIN in use now.'**
  String get currentPinSubtitle;

  /// No description provided for @newPinSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose 6 new digits.'**
  String get newPinSubtitle;

  /// No description provided for @confirmNewPinSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter the new PIN again.'**
  String get confirmNewPinSubtitle;

  /// No description provided for @wrongPin.
  ///
  /// In en, this message translates to:
  /// **'Wrong PIN'**
  String get wrongPin;

  /// No description provided for @newPinMismatch.
  ///
  /// In en, this message translates to:
  /// **'The PINs didn\'t match. Choose the new PIN again.'**
  String get newPinMismatch;

  /// No description provided for @pinChanged.
  ///
  /// In en, this message translates to:
  /// **'PIN changed'**
  String get pinChanged;

  /// No description provided for @useFingerprint.
  ///
  /// In en, this message translates to:
  /// **'Use fingerprint'**
  String get useFingerprint;

  /// No description provided for @deleteDigit.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteDigit;

  /// No description provided for @pinDigits.
  ///
  /// In en, this message translates to:
  /// **'{count} of 6 digits entered'**
  String pinDigits(int count);

  /// No description provided for @biometricReason.
  ///
  /// In en, this message translates to:
  /// **'Unlock the clinical area'**
  String get biometricReason;

  /// No description provided for @biometricEnableReason.
  ///
  /// In en, this message translates to:
  /// **'Confirm to enable fingerprint unlock'**
  String get biometricEnableReason;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
