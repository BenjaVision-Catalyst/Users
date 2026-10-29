"
Opt-in fan-out sampler under the existing Connect owner hook. Charges native diagnostics to the existing call budget; preserves bounded feed and native-state evidence without changing persistent metrics.
"
Class {
	#name : 'CUUsersFanoutApplicationFixture',
	#superclass : 'CUUsersObjectApplication',
	#instVars : [
		'evidenceDirectory',
		'nextSample',
		'sampleNumber',
		'samples',
		'diagnosticOwner',
		'exportRegistered',
		'exported',
		'samplingFailure',
		'sampleAttempts',
		'skippedNativeSamples',
		'startupSkips'
	],
	#category : 'BVC-Users-Connect-Tests',
	#package : 'BVC-Users-Connect-Tests'
}

{ #category : 'qualification' }
CUUsersFanoutApplicationFixture >> configure: configuration [
 super configure: configuration.
 evidenceDirectory := configuration label. self initializeDiagnostics
]

{ #category : 'qualification' }
CUUsersFanoutApplicationFixture >> copyDiagnostic: value [
 "Keep copied JSON values only; never retain a live service, feed or worker."
 (value isNil or: [value == true or: [value == false or: [value isNumber]]]) ifTrue: [^ value].
 value isString ifTrue: [^ value copy].
 value isSymbol ifTrue: [^ value].
 (value isKindOf: Dictionary) ifTrue: [| copy |
  copy := Dictionary new. value keysAndValuesDo: [:key :each | copy at: (self copyDiagnostic: key) put: (self copyDiagnostic: each)]. ^ copy].
 value isArray ifTrue: [^ value collect: [:each | self copyDiagnostic: each]].
 self error: 'Sampler diagnostics must be copied JSON values'
]

{ #category : 'qualification' }
CUUsersFanoutApplicationFixture >> exportDiagnostics [
 | started finished report |
 Processor activeProcess == diagnosticOwner ifFalse: [self error: 'Sampler export requires its Runtime owner'].
 exported ifTrue: [^ self]. exported := true.
 started := CRPlatform current currentMillis.
 samples do: [:sample | self writeDiagnostic: sample name: 'native-', (sample at: 'sample') asString, '.json'].
 finished := CRPlatform current currentMillis.
 report := Dictionary new at: 'completed' put: true; at: 'mode' put: 'buffered';
  at: 'sampleCount' put: samples size; at: 'maximumSamples' put: self maximumSamples;
  at: 'sampleAttempts' put: sampleAttempts; at: 'skippedNativeBusy' put: skippedNativeSamples;
  at: 'startupSkips' put: startupSkips asArray;
  at: 'failure' put: samplingFailure; at: 'exportStartedMillis' put: started;
  at: 'exportFinishedMillis' put: finished; at: 'ownerProcessVerified' put: true; yourself.
 self writeDiagnostic: report name: 'sampler-export.json'
]

{ #category : 'qualification' }
CUUsersFanoutApplicationFixture >> initializeDiagnostics [
 nextSample := 0. sampleNumber := 0. samples := OrderedCollection new.
 diagnosticOwner := nil. exportRegistered := false. exported := false.
 samplingFailure := nil. sampleAttempts := 0. skippedNativeSamples := 0.
 startupSkips := OrderedCollection new
]

{ #category : 'qualification' }
CUUsersFanoutApplicationFixture >> maximumSamples [
 "500 ms samples within the qualification controller's 30-minute lease."
 ^ 3600
]

{ #category : 'qualification' }
CUUsersFanoutApplicationFixture >> noteStartupSkip: reason at: now [
 startupSkips size >= self maximumSamples ifTrue: [samplingFailure := 'Users startup sample buffer exhausted'. self error: samplingFailure].
 startupSkips add: {now. reason copy}
]

{ #category : 'qualification' }
CUUsersFanoutApplicationFixture >> progressUsing: service [
 | now bridge counters fields values worker users feeds rows metrics sample statistics |
 super progressUsing: service.
 now := CRPlatform current currentMillis.
 samplingFailure ifNotNil: [^ self].
 now < nextSample ifTrue: [^ self]. nextSample := now + 500.
 sampleAttempts := sampleAttempts + 1.
 samples size >= self maximumSamples ifTrue: [samplingFailure := 'Users sampler buffer exhausted'. self error: samplingFailure].
 service assertOwner.
 bridge := service instVarNamed: 'bridge'.
 fields := #(1 7 8 9 11 12 14 16).
 values := fields collect: [:field | bridge info: field].
 service instVarNamed: 'callBudget' put: (service instVarNamed: 'callBudget') - fields size.
 (values anySatisfy: [:value | value = 16rFFFFFFFFFFFFFFFF]) ifTrue: [skippedNativeSamples := skippedNativeSamples + 1. ^ self].
 counters := Dictionary new.
 fields with: values do: [:field :value | counters at: field asString put: value].
 worker := (service instVarNamed: 'port') instVarNamed: 'worker'.
 self registerExportWith: worker announcer.
 users := worker services serviceAtIdentifier: #users.
 users ifNil: [self noteStartupSkip: 'Users service not installed' at: now. ^ self].
 feeds := users instVarNamed: 'feeds'.
 feeds ifNil: [self noteStartupSkip: 'Users service not started' at: now. ^ self].
 rows := feeds values collect: [:feed | (feed instVarNamed: 'mutex') critical: [
  Dictionary new at: 'active' put: feed isActive; at: 'publisher' put: feed hasPublisher;
   at: 'watched' put: (feed instVarNamed: 'identities') size; at: 'pending' put: (feed instVarNamed: 'pending') size;
   at: 'pendingRevisions' put: (((feed instVarNamed: 'pending') values collect: #revision) asArray); yourself]].
 metrics := worker workerHandle statistics at: #workUnitExecution.
 statistics := Dictionary new. (service status at: #statistics) keysAndValuesDo: [:key :value | statistics at: key asString put: value].
 sample := Dictionary new at: 'sample' put: sampleNumber + 1; at: 'millis' put: now; at: 'native' put: counters;
  at: 'feeds' put: rows asArray; at: 'publishers' put: (service instVarNamed: 'pushSources') size;
  at: 'executionSequence' put: (metrics samples ifEmpty: [0] ifNotEmpty: [:samples | samples last sequence]);
  at: 'connectStatistics' put: statistics;
  at: 'driveLimits' put: (Dictionary new at: 'calls' put: service configuration driveCallLimit; at: 'bytes' put: service configuration driveByteLimit; at: 'millis' put: service configuration driveTimeLimitMillis; yourself);
  at: 'publicationCaches' put: ((bindings select: #supportsSubscription) collect: #publicationStatistics); yourself.
 sample at: 'snapshotStartedMillis' put: now.
 self recordDiagnostic: sample
]

{ #category : 'qualification' }
CUUsersFanoutApplicationFixture >> publicationCost [
 <gtExample>
 <return: #Dictionary>
 | state schema cache epoch report start originalTimes sharedTimes revisions recipients |
state := CULiveUserState new name: ('analysis:', (String new: 800 withAll: $x)); isSuperUser: false;
 userIdentifier: '00000000000000000000000001'; revision: 132; outcome: 'current'; yourself.
schema := CCObjectStateSchema forObject: state. epoch := Object new. revisions := 50. recipients := 60.
cache := CCObjectPublicationCache new schema: schema capacity: 128.
(schema encode: state) = (cache publicationFor: state identity: state userIdentifier revision: state revision epoch: epoch) bytes ifFalse: [self error: 'Publication payload mismatch'].
originalTimes := (1 to: 3) collect: [:trial |
 start := CRPlatform current currentMillis.
 1 to: revisions do: [:version | state revision: version. recipients timesRepeat: [schema encode: state]].
 CRPlatform current currentMillis - start].
sharedTimes := (1 to: 3) collect: [:trial |
 cache := CCObjectPublicationCache new schema: schema capacity: 128.
 start := CRPlatform current currentMillis.
 1 to: revisions do: [:version | state revision: version. recipients timesRepeat: [cache publicationFor: state identity: state userIdentifier revision: state revision epoch: epoch]].
 CRPlatform current currentMillis - start].
report := Dictionary new at: 'revisions' put: revisions; at: 'recipients' put: recipients; at: 'originalMillis' put: originalTimes asArray; at: 'sharedMillis' put: sharedTimes asArray;
 at: 'originalEncodingsPerTrial' put: revisions * recipients; at: 'sharedEncodingsPerTrial' put: (cache statistics at: #encodings); at: 'byteEquivalent' put: true; yourself.
(cache statistics at: #encodings) = revisions ifFalse: [self error: 'Expected one encoding per committed revision'].
^ report
]

{ #category : 'qualification' }
CUUsersFanoutApplicationFixture >> recordDiagnostic: sample [
 | copy finished |
 exported ifTrue: [self error: 'Sampler export already began'].
 samples size >= self maximumSamples ifTrue: [samplingFailure := 'Users sampler buffer exhausted'. self error: samplingFailure].
 (sample at: 'sample') = (sampleNumber + 1) ifFalse: [self error: 'Sampler sequence must be contiguous'].
 copy := self copyDiagnostic: sample. finished := CRPlatform current currentMillis.
 copy at: 'snapshotFinishedMillis' put: finished.
 samples add: copy. sampleNumber := sampleNumber + 1.
 copy at: 'hookFinishedMillis' put: CRPlatform current currentMillis
]

{ #category : 'qualification' }
CUUsersFanoutApplicationFixture >> registerExportWith: announcer [
 exportRegistered ifTrue: [^ self].
 diagnosticOwner := Processor activeProcess.
 announcer when: CRWorkerServicesUninstallingAnnouncement
  do: [:announcement | self exportDiagnostics. announcer unsubscribe: self] for: self.
 exportRegistered := true
]

{ #category : 'qualification' }
CUUsersFanoutApplicationFixture >> writeDiagnostic: value name: name [
 CRPlatform current writeConnectEvidence: value to: evidenceDirectory, '/', name
]
