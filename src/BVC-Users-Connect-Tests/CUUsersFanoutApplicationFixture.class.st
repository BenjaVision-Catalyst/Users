"
Opt-in fan-out sampler under the existing Connect owner hook. Charges native diagnostics to the existing call budget; preserves bounded feed and native-state evidence without changing persistent metrics.
"
Class {
	#name : 'CUUsersFanoutApplicationFixture',
	#superclass : 'CUUsersObjectApplication',
	#instVars : [
		'evidenceDirectory',
		'nextSample',
		'sampleNumber'
	],
	#category : 'BVC-Users-Connect-Tests',
	#package : 'BVC-Users-Connect-Tests'
}

{ #category : 'qualification' }
CUUsersFanoutApplicationFixture >> configure: configuration [
 super configure: configuration.
 evidenceDirectory := configuration label. nextSample := 0. sampleNumber := 0
]

{ #category : 'qualification' }
CUUsersFanoutApplicationFixture >> progressUsing: service [
 | now bridge counters fields values worker users feeds rows metrics sample statistics |
 super progressUsing: service.
 now := CRPlatform current currentMillis.
 now < nextSample ifTrue: [^ self]. nextSample := now + 500.
 service assertOwner.
 bridge := service instVarNamed: 'bridge'.
 fields := #(1 7 8 9 11 12 14 16).
 values := fields collect: [:field | bridge info: field].
 service instVarNamed: 'callBudget' put: (service instVarNamed: 'callBudget') - fields size.
 (values anySatisfy: [:value | value = 16rFFFFFFFFFFFFFFFF]) ifTrue: [^ self].
 counters := Dictionary new.
 fields with: values do: [:field :value | counters at: field asString put: value].
 worker := (service instVarNamed: 'port') instVarNamed: 'worker'.
 users := worker services serviceAtIdentifier: #users.
 feeds := users instVarNamed: 'feeds'.
 rows := feeds values collect: [:feed | (feed instVarNamed: 'mutex') critical: [
  Dictionary new at: 'active' put: feed isActive; at: 'publisher' put: feed hasPublisher;
   at: 'watched' put: (feed instVarNamed: 'identities') size; at: 'pending' put: (feed instVarNamed: 'pending') size;
   at: 'pendingRevisions' put: (((feed instVarNamed: 'pending') values collect: #revision) asArray); yourself]].
 metrics := worker workerHandle statistics at: #workUnitExecution.
 statistics := Dictionary new. (service status at: #statistics) keysAndValuesDo: [:key :value | statistics at: key asString put: value].
 sampleNumber := sampleNumber + 1.
 sample := Dictionary new at: 'sample' put: sampleNumber; at: 'millis' put: now; at: 'native' put: counters;
  at: 'feeds' put: rows asArray; at: 'publishers' put: (service instVarNamed: 'pushSources') size;
  at: 'executionSequence' put: (metrics samples ifEmpty: [0] ifNotEmpty: [:samples | samples last sequence]);
  at: 'connectStatistics' put: statistics;
  at: 'driveLimits' put: (Dictionary new at: 'calls' put: service configuration driveCallLimit; at: 'bytes' put: service configuration driveByteLimit; at: 'millis' put: service configuration driveTimeLimitMillis; yourself);
  at: 'publicationCaches' put: ((bindings select: #supportsSubscription) collect: #publicationStatistics); yourself.
 CRPlatform current writeConnectEvidence: sample to: evidenceDirectory, '/native-', sampleNumber asString, '.json'
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
