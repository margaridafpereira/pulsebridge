// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appTitle => 'PulseBridge';

  @override
  String get tabMonitor => 'Monitor';

  @override
  String get tabRecordings => 'Gravações';

  @override
  String get tabProfile => 'Perfil';

  @override
  String get tabSettings => 'Definições';

  @override
  String get cancel => 'Cancelar';

  @override
  String get save => 'Guardar';

  @override
  String get delete => 'Apagar';

  @override
  String get apply => 'Aplicar';

  @override
  String get connect => 'Ligar';

  @override
  String get disconnect => 'Desligar';

  @override
  String get send => 'Enviar';

  @override
  String get clear => 'Limpar';

  @override
  String get notSet => 'Não definido';

  @override
  String get none => 'Nenhum';

  @override
  String get bpm => 'bpm';

  @override
  String percentValue(int value) {
    return '$value por cento';
  }

  @override
  String recordingSaved(String duration) {
    return 'Gravação guardada (encriptada) · $duration';
  }

  @override
  String get notMonitoring => 'SEM MONITORIZAÇÃO';

  @override
  String get linkReconnecting => 'A religar ao aparelho';

  @override
  String get linkLostBanner => 'Ligação ao aparelho perdida';

  @override
  String get electrodeOff => 'Elétrodo solto';

  @override
  String get checkLeads => 'Verifique a colocação dos elétrodos';

  @override
  String get batteryLowTitle => 'Bateria do aparelho fraca';

  @override
  String get batteryLowText => 'Carregue o aparelho em breve';

  @override
  String batteryLevel(int percent) {
    return 'Bateria do aparelho a $percent por cento';
  }

  @override
  String get connectTitle => 'Ligar ao aparelho';

  @override
  String get connectSubtitle =>
      'Monitor de ECG por TCP (simulador). Para um sensor Bluetooth, mude o tipo de aparelho nas Definições.';

  @override
  String get host => 'Host';

  @override
  String get port => 'Porta';

  @override
  String get linkLive => 'Em direto';

  @override
  String get linkLinking => 'A ligar';

  @override
  String get linkLost => 'Perdida';

  @override
  String get linkOffline => 'Desligado';

  @override
  String get heartRateLabel => 'RITMO CARDÍACO';

  @override
  String get fromEcg => '· do ECG';

  @override
  String get fromSensor => '· do sensor';

  @override
  String hrHigh(int limit) {
    return 'ALTO > $limit';
  }

  @override
  String hrLow(int limit) {
    return 'BAIXO < $limit';
  }

  @override
  String heartRateSemantics(int bpm) {
    return 'Ritmo cardíaco $bpm batimentos por minuto';
  }

  @override
  String get heartRateUnknown => 'Ritmo cardíaco desconhecido';

  @override
  String get statMin => 'MÍN';

  @override
  String get statAvg => 'MÉD';

  @override
  String get statMax => 'MÁX';

  @override
  String get last5min => 'últimos 5 min';

  @override
  String trendSemantics(int low, int high) {
    return 'Tendência do ritmo cardíaco, de $low a $high batimentos por minuto';
  }

  @override
  String get ecgLabel => 'ECG';

  @override
  String get ecgScale => 'Derivação II · 25 mm/s · 10 mm/mV';

  @override
  String get ecgSemantics => 'Traçado de ECG em direto';

  @override
  String get ecgSemanticsDimmed =>
      'Traçado de ECG parado: ligação ao aparelho perdida';

  @override
  String get noEcgTitle => 'Sensor de ritmo cardíaco';

  @override
  String get noEcgText =>
      'Este sensor envia o ritmo cardíaco e os intervalos entre batimentos, não um ECG. A triagem do ritmo continua a funcionar com esses intervalos.';

  @override
  String rec(String duration) {
    return 'REC $duration';
  }

  @override
  String recSemantics(String duration) {
    return 'A gravar há $duration';
  }

  @override
  String get rrIrregular => 'RR irregular';

  @override
  String get rrRegular => 'RR regular';

  @override
  String prematureBeats(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count batimentos prematuros',
      one: '1 batimento prematuro',
      zero: '$count batimentos prematuros',
    );
    return '$_temp0';
  }

  @override
  String get noDataLost => 'Sem perda de dados';

  @override
  String samplesLost(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count amostras perdidas',
      one: '1 amostra perdida',
      zero: '$count amostras perdidas',
    );
    return '$_temp0';
  }

  @override
  String get stopRecording => 'Parar gravação';

  @override
  String get startRecording => 'Iniciar gravação';

  @override
  String get markSymptom => 'Registar sintoma';

  @override
  String markSymptomCount(int count) {
    return 'Registar sintoma · $count registados';
  }

  @override
  String get symptomQuestion => 'O que está a sentir?';

  @override
  String get symptomHint => 'Fica marcado no ECG neste preciso momento.';

  @override
  String symptomMarked(String symptom) {
    return '$symptom: marcado no ECG';
  }

  @override
  String get connectDevice => 'Ligar um aparelho';

  @override
  String get symptomPalpitations => 'Palpitações';

  @override
  String get symptomDizziness => 'Tonturas';

  @override
  String get symptomChestPain => 'Dor no peito';

  @override
  String get symptomShortnessOfBreath => 'Falta de ar';

  @override
  String get symptomFatigue => 'Cansaço';

  @override
  String get symptomExercise => 'Exercício';

  @override
  String get bleTitle => 'Sensor de ritmo cardíaco Bluetooth';

  @override
  String get bleSubtitle =>
      'Cinta peitoral, relógio ou qualquer sensor com o serviço padrão de ritmo cardíaco. Só ritmo cardíaco, sem ECG.';

  @override
  String bleLastUsed(String address) {
    return 'Último usado · $address';
  }

  @override
  String get bleNoBluetooth => 'Este telemóvel não tem Bluetooth LE.';

  @override
  String get blePermission =>
      'O PulseBridge precisa da autorização \"Dispositivos próximos\" para encontrar sensores.';

  @override
  String get bleOff => 'O Bluetooth está desligado. Ligue-o e procure de novo.';

  @override
  String bleScanFailed(String error) {
    return 'A procura falhou: $error';
  }

  @override
  String get bleSearching => 'À procura de sensores…';

  @override
  String get bleNoneFound =>
      'Nenhum sensor encontrado. Coloque a cinta (liga-se com o contacto com a pele) ou, noutro telemóvel, abra o nRF Connect → Advertiser e adicione o serviço Heart Rate.';

  @override
  String get bleUnnamed => 'Aparelho sem nome';

  @override
  String bleHrSensor(String address) {
    return 'Sensor de ritmo cardíaco · $address';
  }

  @override
  String get bleScanAgain => 'Procurar de novo';

  @override
  String bleSignal(int bars) {
    return 'Sinal $bars de 4';
  }

  @override
  String get recordingsError => 'Não foi possível ler as gravações';

  @override
  String get noRecordings => 'Ainda não há gravações';

  @override
  String get noRecordingsText =>
      'Inicie uma gravação no separador Monitor. Cada sessão fica guardada encriptada neste aparelho.';

  @override
  String get encryptionNote =>
      'AES-256-GCM · chave guardada no Android Keystore';

  @override
  String get lock => 'Bloquear';

  @override
  String get avgBpm => 'bpm médio';

  @override
  String bpmRange(int low, int high) {
    return '$low–$high bpm';
  }

  @override
  String prematureShort(int count) {
    return '$count prematuros';
  }

  @override
  String alarmsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count alarmes',
      one: '1 alarme',
      zero: '$count alarmes',
    );
    return '$_temp0';
  }

  @override
  String lostPercent(String amount) {
    return '$amount% perdido';
  }

  @override
  String get deleteTitle => 'Apagar gravação?';

  @override
  String get deleteText =>
      'O ECG e todos os dados desta sessão são apagados do aparelho.';

  @override
  String openRecording(String date, String duration, int bpm) {
    return 'Gravação de $date, $duration, média de $bpm bpm';
  }

  @override
  String get pdfReport => 'Relatório PDF';

  @override
  String get fhirExport => 'Exportação FHIR';

  @override
  String get statAverage => 'Média';

  @override
  String get statMinShort => 'Mín';

  @override
  String get statMaxShort => 'Máx';

  @override
  String get statDuration => 'Duração';

  @override
  String get statPremature => 'Prematuros';

  @override
  String get statDataLost => 'Dados perdidos';

  @override
  String get sectionHeartRate => 'Ritmo cardíaco';

  @override
  String hrBand(int low, int high) {
    return 'faixa $low–$high bpm';
  }

  @override
  String get sectionEcgReview => 'Revisão do ECG';

  @override
  String ecgDecryptError(String error) {
    return 'Não foi possível desencriptar o ECG: $error';
  }

  @override
  String get noEcgRecording =>
      'Esta gravação não tem ECG: veio de um sensor de ritmo cardíaco.';

  @override
  String get sectionEvents => 'Eventos';

  @override
  String get tapToSeeEcg => 'toque para ver o ECG';

  @override
  String stripRange(String from, String to, String length) {
    return '$from – $to de $length';
  }

  @override
  String stripSemantics(String from, String to) {
    return 'Traçado de ECG de $from a $to';
  }

  @override
  String get eventRecordingStarted => 'Gravação iniciada';

  @override
  String get eventRecordingStopped => 'Gravação terminada';

  @override
  String get eventDeviceConnected => 'Aparelho ligado';

  @override
  String get eventReconnecting => 'A religar';

  @override
  String get eventLinkLost => 'Ligação perdida';

  @override
  String eventLinkLostReason(String reason) {
    return 'Ligação perdida: $reason';
  }

  @override
  String get eventElectrodeOffCleared => 'Elétrodo recolocado';

  @override
  String get eventLowBattery => 'Bateria fraca';

  @override
  String get eventLowBatteryCleared => 'Bateria recuperada';

  @override
  String get eventPremature => 'Batimento prematuro';

  @override
  String eventHrOutside(int bpm, int low, int high) {
    return 'Ritmo cardíaco $bpm bpm fora de $low–$high';
  }

  @override
  String get reportTitle => 'Relatório para o médico';

  @override
  String get reportPdfTitle => 'Relatório de gravação de ECG';

  @override
  String recordedOn(String date) {
    return 'Gravado a $date';
  }

  @override
  String get disclaimer =>
      'Projeto de portefólio, não é um dispositivo médico. Os indicadores de ritmo são ajudas de triagem, não um diagnóstico.';

  @override
  String pageOf(int page, int total) {
    return 'Página $page de $total';
  }

  @override
  String get patient => 'Doente';

  @override
  String get recording => 'Gravação';

  @override
  String get name => 'Nome';

  @override
  String get ageSex => 'Idade · sexo';

  @override
  String ageBorn(int age, int year) {
    return '$age anos (n. $year)';
  }

  @override
  String get noProfile => 'Sem perfil de doente registado';

  @override
  String get profileLabel => 'Perfil';

  @override
  String get start => 'Início';

  @override
  String get device => 'Aparelho';

  @override
  String deviceDesc(String id, int rate) {
    return '$id · $rate Hz, uma derivação';
  }

  @override
  String get alarmLimits => 'Limites de alarme';

  @override
  String get signalLost => 'Sinal perdido';

  @override
  String signalLostValue(String amount, int lost, int total) {
    return '$amount % ($lost de $total amostras)';
  }

  @override
  String get averageHr => 'Ritmo médio';

  @override
  String get minHr => 'Ritmo mín.';

  @override
  String get maxHr => 'Ritmo máx.';

  @override
  String get prematureBeatsLabel => 'Batimentos prematuros';

  @override
  String get symptomsLabel => 'Sintomas';

  @override
  String get alarmsLabel => 'Alarmes';

  @override
  String findingPremature(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count batimentos prematuros assinalados (RR abaixo de 80 % da mediana recente).',
      one: '1 batimento prematuro assinalado (RR abaixo de 80 % da mediana recente).',
      zero:
          '$count batimentos prematuros assinalados (RR abaixo de 80 % da mediana recente).',
    );
    return '$_temp0';
  }

  @override
  String get findingNoPremature => 'Nenhum batimento prematuro assinalado.';

  @override
  String findingAlarms(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count alarmes do aparelho ou do ritmo cardíaco durante a gravação.',
      one: '1 alarme do aparelho ou do ritmo cardíaco durante a gravação.',
      zero:
          '$count alarmes do aparelho ou do ritmo cardíaco durante a gravação.',
    );
    return '$_temp0';
  }

  @override
  String findingSymptoms(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count sintomas referidos pelo doente; o ECG em cada um está abaixo.',
      one: '1 sintoma referido pelo doente; o ECG nesse momento está abaixo.',
      zero:
          '$count sintomas referidos pelo doente; o ECG em cada um está abaixo.',
    );
    return '$_temp0';
  }

  @override
  String get notEnoughHr =>
      'Leituras de ritmo cardíaco insuficientes para o gráfico.';

  @override
  String get ecgScaleNote =>
      'Derivação II · 25 mm/s · 10 mm/mV · sinal em bruto, linha de base removida em cada traçado. As faixas cinzentas marcam amostras perdidas.';

  @override
  String get symptomTag => 'SINTOMA';

  @override
  String get alarmTag => 'ALARME';

  @override
  String get startOfRecording => 'Início da gravação';

  @override
  String atTime(String time) {
    return 'aos $time';
  }

  @override
  String get eventLog => 'Registo de eventos';

  @override
  String get time => 'Hora';

  @override
  String get type => 'Tipo';

  @override
  String get event => 'Evento';

  @override
  String get noEvents => 'Sem eventos.';

  @override
  String get kindAlarm => 'Alarme';

  @override
  String get kindLink => 'Ligação';

  @override
  String get kindSymptom => 'Sintoma';

  @override
  String get kindInfo => 'Info';

  @override
  String get kindRhythm => 'Ritmo';

  @override
  String prematureNotListed(int count) {
    return '$count marcadores individuais de batimentos prematuros não estão listados.';
  }

  @override
  String fhirBuildError(String error) {
    return 'Não foi possível criar a exportação: $error';
  }

  @override
  String get size => 'Tamanho';

  @override
  String get fhirCodes =>
      'Códigos: LOINC (ritmo cardíaco, estudo de ECG, sintoma), SNOMED CT (sintomas), ISO/IEEE 11073 MDC (ECG derivação II), unidades UCUM.';

  @override
  String get shareFile => 'Partilhar como ficheiro';

  @override
  String get fhirSendNoServer =>
      'Enviar para servidor FHIR (defina um nas Definições)';

  @override
  String fhirSendTo(String server) {
    return 'Enviar para $server';
  }

  @override
  String get preview => 'Pré-visualização';

  @override
  String get fhirSendTitle => 'Enviar dados de saúde?';

  @override
  String fhirSendText(String server) {
    return 'Esta gravação e o perfil do doente vão ser enviados para\n$server';
  }

  @override
  String fhirAccepted(int count) {
    return 'Aceite · $count recursos criados';
  }

  @override
  String fhirNotSent(String error) {
    return 'Não enviado: $error';
  }

  @override
  String get fhirShareSubject => 'Gravação de ECG (FHIR)';

  @override
  String get firmwareTitle => 'Firmware do aparelho';

  @override
  String get fwInstalled => 'INSTALADO';

  @override
  String get fwAvailable => 'DISPONÍVEL';

  @override
  String get fwChanges =>
      'Novidades da 1.1.0: deteção mais rápida de elétrodo solto e menor consumo durante a transmissão.';

  @override
  String get fwConnectFirst => 'Ligue ao aparelho de ECG no separador Monitor.';

  @override
  String get fwStopRecording =>
      'Pare primeiro a gravação. Uma atualização nunca interrompe a monitorização.';

  @override
  String get fwCancel => 'Cancelar atualização';

  @override
  String get fwUpToDate => 'Atualizado';

  @override
  String fwInstall(String version) {
    return 'Instalar $version';
  }

  @override
  String get fwSending => 'A enviar';

  @override
  String get fwWaitingLink => 'Ligação perdida, vai retomar';

  @override
  String get fwVerifying => 'O aparelho está a verificar a imagem';

  @override
  String get fwRestarting => 'O aparelho está a reiniciar';

  @override
  String get fwDone => 'Atualizado';

  @override
  String get fwFailed => 'A atualização falhou';

  @override
  String get fwCancelled => 'Cancelada';

  @override
  String fwProgressKb(String sentKb, String totalKb) {
    return '$sentKb de $totalKb KB';
  }

  @override
  String get fwKeptOld =>
      'O aparelho manteve o firmware atual e funciona como antes.';

  @override
  String get fwStepSend => 'Enviar';

  @override
  String get fwStepVerify => 'Verificar';

  @override
  String get fwStepRestart => 'Reiniciar';

  @override
  String get fwStepConfirm => 'Confirmar';

  @override
  String get fwHowTitle => 'Como a atualização se mantém segura';

  @override
  String get fwHow1 =>
      'Enviada em blocos de 512 bytes; cada um é confirmado antes do seguinte.';

  @override
  String get fwHow2 => 'Se a ligação cair, retoma onde parou.';

  @override
  String get fwHow3 =>
      'O aparelho verifica a imagem inteira (tamanho, CRC-32, cabeçalho) antes de instalar.';

  @override
  String get fwHow4 =>
      'Se a verificação falhar, o firmware atual continua a funcionar.';

  @override
  String get fwHow5 =>
      'Só fica concluída quando o aparelho reinicia com a versão nova.';

  @override
  String get fwProgressSemantics => 'Progresso da atualização de firmware';

  @override
  String get editProfile => 'Editar perfil';

  @override
  String get statRecordings => 'Gravações';

  @override
  String get statTimeMonitored => 'Tempo monitorizado';

  @override
  String get statAverageHr => 'Ritmo médio';

  @override
  String get statSymptoms => 'Sintomas registados';

  @override
  String maxHrSuggestion(int maxHr) {
    return 'O ritmo cardíaco máximo previsto para a idade é $maxHr bpm. Usar como limite superior do alarme?';
  }

  @override
  String get conditions => 'Condições';

  @override
  String get medication => 'Medicação';

  @override
  String get noneRecorded => 'Nada registado';

  @override
  String get physician => 'Médico';

  @override
  String get emergencyContact => 'Contacto de emergência';

  @override
  String ageYears(int age) {
    return '$age anos';
  }

  @override
  String get setupProfile => 'Configure o seu perfil';

  @override
  String get setupProfileText =>
      'A sua idade personaliza os limites de ritmo cardíaco.';

  @override
  String get addDetails => 'Adicionar dados';

  @override
  String get encryptedOnDevice => 'Encriptado no aparelho';

  @override
  String get fullName => 'Nome completo';

  @override
  String get yearOfBirth => 'Ano de nascimento';

  @override
  String get sexLabel => 'Sexo';

  @override
  String get sexFemale => 'Feminino';

  @override
  String get sexMale => 'Masculino';

  @override
  String get sexOther => 'Outro';

  @override
  String get medicationHint => 'ex.: Bisoprolol 2,5 mg';

  @override
  String get addItem => 'Adicionar';

  @override
  String get emergencyContactHint => 'Contacto de emergência (nome e telefone)';

  @override
  String get condHypertension => 'Hipertensão';

  @override
  String get condAtrialFibrillation => 'Fibrilhação auricular';

  @override
  String get condDiabetes => 'Diabetes';

  @override
  String get condHeartFailure => 'Insuficiência cardíaca';

  @override
  String get condAsthma => 'Asma';

  @override
  String get hrLimitsTitle => 'Limites de alarme do ritmo cardíaco';

  @override
  String get limitLow => 'BAIXO';

  @override
  String get limitHigh => 'ALTO';

  @override
  String get hrLimitsText =>
      'O monitor fica vermelho e regista um alarme quando o ritmo cardíaco sai desta faixa.';

  @override
  String hrLimitsSemantics(int low, int high) {
    return 'Limites de alarme do ritmo cardíaco, baixo $low, alto $high batimentos por minuto';
  }

  @override
  String get deviceTitle => 'Aparelho';

  @override
  String get ecgSimulator => 'Simulador de ECG';

  @override
  String get bluetooth => 'Bluetooth';

  @override
  String get simulatorText =>
      'ECG, ritmo cardíaco e alarmes por TCP. Altere o host e a porta ao ligar.';

  @override
  String firmwareSubtitle(String installed, String available) {
    return 'Instalado $installed · disponível $available';
  }

  @override
  String get sensor => 'Sensor';

  @override
  String get noneYet => 'Nenhum ainda';

  @override
  String get forgetSensor => 'Esquecer este sensor';

  @override
  String get bluetoothText =>
      'Qualquer sensor com o serviço padrão Bluetooth Heart Rate: cintas como a Polar H10, ou o nRF Connect noutro telemóvel. Ritmo cardíaco e intervalos entre batimentos, sem ECG.';

  @override
  String get typeAppliesNext =>
      'A mudança de tipo aplica-se à próxima ligação.';

  @override
  String get server => 'Servidor';

  @override
  String get setServer => 'Definir servidor';

  @override
  String get fhirSettingsText =>
      'As gravações podem ser exportadas em HL7 FHIR R4 (um ficheiro, ou enviadas para este servidor por https). Os servidores públicos de teste são visíveis para todos: nunca envie para lá dados reais de doentes.';

  @override
  String get fhirServerTitle => 'Servidor FHIR';

  @override
  String get baseUrl => 'URL base';

  @override
  String get useHttps => 'Use um endereço https://';

  @override
  String get language => 'Idioma';

  @override
  String get languageSystem => 'Sistema';

  @override
  String get privacyTitle => 'Privacidade';

  @override
  String get storage => 'Armazenamento';

  @override
  String get key => 'Chave';

  @override
  String get privacyText =>
      'Gravações, perfil e definições ficam no armazenamento privado da app. A chave não pode ser exportada, por isso ficheiros copiados são ilegíveis. Só sai do aparelho o relatório ou a exportação FHIR que decidir partilhar.';

  @override
  String get aboutTitle => 'Sobre';

  @override
  String get version => 'Versão';

  @override
  String get aboutText =>
      'O PulseBridge é um projeto de portefólio, não um dispositivo médico. Os indicadores de ritmo são uma ajuda de triagem e não um diagnóstico.';

  @override
  String get clinicianAccess => 'Acesso clínico';

  @override
  String get createPinHint =>
      'Abra o separador Gravações para criar o PIN clínico.';

  @override
  String get unlocked => 'Desbloqueado';

  @override
  String get locked => 'Bloqueado';

  @override
  String get fingerprintUnlock => 'Desbloquear com impressão digital';

  @override
  String get noFingerprint =>
      'Não há impressão digital registada neste aparelho';

  @override
  String get pinFallback => 'O PIN continua a funcionar como alternativa';

  @override
  String get unlockToChange => 'Desbloqueie o separador Gravações para alterar';

  @override
  String get fingerprintNotConfirmed => 'Impressão digital não confirmada';

  @override
  String get changePin => 'Alterar PIN';

  @override
  String get lockNow => 'Bloquear agora';

  @override
  String get lockInfo =>
      'A área também bloqueia 30 s depois de a app ir para segundo plano. Cinco PINs errados suspendem a entrada, cada vez por mais tempo.';

  @override
  String get demoDevice => 'Aparelho de demonstração';

  @override
  String get demoText =>
      'Corre dentro do browser e reproduz ECG real do registo 119 do MIT-BIH (um doente com bigeminismo ventricular).';

  @override
  String get demoControls => 'Experimente as funções de segurança';

  @override
  String get demoControlsText =>
      'Faça o aparelho de demonstração falhar de propósito e veja como a app reage.';

  @override
  String get demoDropLink => 'Cortar a ligação';

  @override
  String get demoElectrodeOff => 'Soltar elétrodo';

  @override
  String get demoNeedsConnection => 'Ligue primeiro no separador Monitor.';

  @override
  String get webDemoNote =>
      'Demo web: aparelho simulado, ECG real. A app Android liga-se a hardware real.';

  @override
  String get webPrivacyText =>
      'Nesta demo web, os dados ficam neste browser (localStorage) e não são encriptados com uma chave de hardware. Aqui só existem gravações simuladas. A app Android encripta tudo com AES-256-GCM e uma chave guardada no Android Keystore.';

  @override
  String get bleChoose => 'Escolher sensor';

  @override
  String get bleWebHint =>
      'O browser vai mostrar os sensores de ritmo cardíaco próximos (Chrome ou Edge, no computador ou Android).';

  @override
  String get bleWebUnsupported =>
      'Este browser não tem Web Bluetooth. Abra a demo no Chrome ou no Edge.';

  @override
  String lockError(String error) {
    return 'Não foi possível ler o bloqueio: $error';
  }

  @override
  String get lockedTitle => 'Área clínica bloqueada';

  @override
  String get lockedSubtitle =>
      'As gravações contêm dados de saúde. Introduza o PIN clínico.';

  @override
  String get fingerprintFailed =>
      'Impressão digital não reconhecida. Use o PIN.';

  @override
  String wrongPinAttempts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'PIN errado · $count tentativas antes de uma pausa',
      one: 'PIN errado · 1 tentativa antes de uma pausa',
      zero: 'PIN errado · $count tentativas antes de uma pausa',
    );
    return '$_temp0';
  }

  @override
  String get tooManyPins => 'Demasiados PINs errados';

  @override
  String tryAgainIn(String time) {
    return 'Demasiados PINs errados. Tente de novo dentro de $time';
  }

  @override
  String get protectTitle => 'Proteja a área clínica';

  @override
  String get protectSubtitle =>
      'Escolha um PIN de 6 dígitos. Vai ser pedido para abrir gravações e exportar relatórios.';

  @override
  String get confirmPin => 'Confirme o PIN';

  @override
  String get confirmPinSubtitle => 'Introduza os mesmos 6 dígitos outra vez.';

  @override
  String get pinMismatch => 'Os PINs não coincidem. Comece de novo.';

  @override
  String get currentPin => 'PIN atual';

  @override
  String get newPin => 'Novo PIN';

  @override
  String get confirmNewPin => 'Confirme o novo PIN';

  @override
  String get currentPinSubtitle => 'Introduza o PIN em uso.';

  @override
  String get newPinSubtitle => 'Escolha 6 dígitos novos.';

  @override
  String get confirmNewPinSubtitle => 'Introduza o novo PIN outra vez.';

  @override
  String get wrongPin => 'PIN errado';

  @override
  String get newPinMismatch =>
      'Os PINs não coincidem. Escolha o novo PIN outra vez.';

  @override
  String get pinChanged => 'PIN alterado';

  @override
  String get useFingerprint => 'Usar impressão digital';

  @override
  String get deleteDigit => 'Apagar';

  @override
  String pinDigits(int count) {
    return '$count de 6 dígitos introduzidos';
  }

  @override
  String get biometricReason => 'Desbloquear a área clínica';

  @override
  String get biometricEnableReason =>
      'Confirme para ativar o desbloqueio por impressão digital';
}
