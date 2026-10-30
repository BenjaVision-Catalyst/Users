"
Opt-in activation-local diagnostic sink. Preserves the existing local metric ring and sequences; copies bounded post-commit drive observations without native I/O or repository writes.
"
Class {
	#name : 'CUUsersDriveTriggerMetrics',
	#superclass : 'CRWorkUnitExecutionMetrics',
	#instVars : [
		'driveService',
		'driveRows',
		'previousStats',
		'previousGeneration',
		'traceOwner',
		'scanEntry'
	],
	#category : 'BVC-Users-Connect-Tests',
	#package : 'BVC-Users-Connect-Tests'
}

{ #category : 'qualification' }
CUUsersDriveTriggerMetrics >> configureFrom: metrics service: service [
 #(samples maxSamples nextSequence) do: [:name | self instVarNamed: name asString put: (metrics instVarNamed: name asString)].
 driveService := service. driveRows := OrderedCollection new. previousStats := nil. previousGeneration := nil.
 scanEntry := nil.
 traceOwner := Processor activeProcess. ^ self
]

{ #category : 'qualification' }
CUUsersDriveTriggerMetrics >> driveReport [
 ^ Dictionary new at: 'rows' put: driveRows asArray; at: 'maximumRows' put: self maximumDriveRows;
 at: 'localMetricsHead' put: self lastSequenceNumber; at: 'readOnlyDiagnostics' put: true; yourself
]

{ #category : 'qualification' }
CUUsersDriveTriggerMetrics >> maximumDriveRows [
 ^ 50000
]

{ #category : 'qualification' }
CUUsersDriveTriggerMetrics >> recordDrive: execution sequence: sequence [
 | started service statistics stageCounts executing waitingReady immediate pendingCount generation delta row endMillis |
 Processor activeProcess == traceOwner ifFalse: [self error: 'Drive trace requires its Runtime owner'].
 driveRows size >= self maximumDriveRows ifTrue: [self error: 'Drive diagnostic buffer exhausted'].
 started := CRPlatform current currentMillis. service := driveService.
 statistics := (service instVarNamed: 'stats') copy.
 stageCounts := Dictionary new. executing := 0. waitingReady := 0. immediate := 0. pendingCount := 0.
 (service instVarNamed: 'pending') do: [:claim |
 claim ifNotNil: [
  pendingCount := pendingCount + 1.
  stageCounts at: claim stage asString put: (stageCounts at: claim stage asString ifAbsent: [0]) + 1.
  claim stage == #executing
   ifTrue: [claim activation unit ifNil: [immediate := immediate + 1] ifNotNil: [executing := executing + 1]]
   ifFalse: [claim stage == #waiting
    ifTrue: [claim body isReady ifTrue: [waitingReady := waitingReady + 1. immediate := immediate + 1]]
    ifFalse: [immediate := immediate + 1]]]].
 generation := (service instVarNamed: 'bridge') instVarNamed: 'observedGeneration'.
 delta := Dictionary new.
 #(drives entryHintsConsumed admitted published completionWrites completionRetries pushCandidates pushAttempts pushAccepted pushBusy pushBudgetDeferrals copyBytes) do: [:key |
 delta at: key asString put: ((statistics at: key ifAbsent: [0]) - (previousStats ifNil: [0] ifNotNil: [previousStats at: key ifAbsent: [0]]))].
 endMillis := execution endMillis.
 row := Dictionary new at: 'sequence' put: sequence; at: 'endMillis' put: endMillis;
 at: 'bodyMillis' put: execution durationMillis; at: 'statisticsDelta' put: delta;
 at: 'firstPartialObservation' put: previousStats isNil;
 at: 'entryNativeGeneration' put: generation;
 at: 'entryNativeGenerationDelta' put: ((previousGeneration isNil or: [generation isNil]) ifTrue: [nil] ifFalse: [generation - previousGeneration]);
 at: 'pending' put: pendingCount; at: 'stages' put: stageCounts;
 at: 'executingWithUnit' put: executing; at: 'waitingReady' put: waitingReady; at: 'immediateClaims' put: immediate;
 at: 'pushContinuation' put: (service instVarNamed: 'pushContinuation');
 at: 'localContinuationPredicate' put: ((service instVarNamed: 'pushContinuation') == true or: [(service instVarNamed: 'pending') anySatisfy: [:claim | service claimRequiresProgress: claim]]);
 at: 'callBudget' put: (service instVarNamed: 'callBudget'); at: 'byteBudget' put: (service instVarNamed: 'byteBudget');
 at: 'candidateBudget' put: (service instVarNamed: 'candidateBudget'); at: 'driveDeadline' put: (service instVarNamed: 'driveDeadline');
 at: 'captureStartedMillis' put: started; yourself.
 self recordScanFor: row.
 driveRows add: row. previousStats := statistics. previousGeneration := generation.
 row at: 'captureFinishedMillis' put: CRPlatform current currentMillis
]

{ #category : 'qualification' }
CUUsersDriveTriggerMetrics >> recordExecution: execution [
 | sample |
 sample := super recordExecution: execution.
 (execution workUnit class == CCQuicDriveWork and: [driveService notNil]) ifTrue: [self recordDrive: execution sequence: sample sequence].
 ^ sample
]

{ #category : 'qualification' }
CUUsersDriveTriggerMetrics >> recordScanEntry [
 | started |
 Processor activeProcess == traceOwner ifFalse: [self error: 'Claim scan trace requires its Runtime owner'].
 started := CRPlatform current currentMillis.
 scanEntry := Dictionary new
 at: 'drive' put: ((driveService instVarNamed: 'stats') at: #drives);
 at: 'capacity' put: (driveService instVarNamed: 'pending') size;
 at: 'cursorBefore' put: (driveService instVarNamed: 'cursor');
 at: 'candidateBudgetBefore' put: (driveService instVarNamed: 'candidateBudget');
 at: 'pushCandidatesBefore' put: ((driveService instVarNamed: 'stats') at: #pushCandidates ifAbsent: [0]);
 at: 'slotsBefore' put: self snapshotPendingClaims;
 at: 'entryCaptureStartedMillis' put: started; yourself.
 scanEntry at: 'entryCaptureFinishedMillis' put: CRPlatform current currentMillis
]

{ #category : 'qualification' }
CUUsersDriveTriggerMetrics >> recordScanFor: row [
 | scan pushes visits |
 scan := Dictionary new at: 'entryMatched' put: false; yourself.
 (scanEntry notNil and: [(scanEntry at: 'drive') = ((driveService instVarNamed: 'stats') at: #drives)]) ifTrue: [
 scan := scanEntry copy.
 pushes := ((driveService instVarNamed: 'stats') at: #pushCandidates ifAbsent: [0]) - (scan at: 'pushCandidatesBefore').
 visits := (scan at: 'candidateBudgetBefore') - (driveService instVarNamed: 'candidateBudget') - pushes.
 scan at: 'entryMatched' put: true; at: 'claimCandidateCharges' put: visits;
 at: 'cursorAfter' put: (driveService instVarNamed: 'cursor'); at: 'slotsAfter' put: self snapshotPendingClaims].
 row at: 'claimScan' put: scan. scanEntry := nil
]

{ #category : 'qualification' }
CUUsersDriveTriggerMetrics >> snapshotPendingClaims [
 | slots claims |
 slots := OrderedCollection new. claims := driveService instVarNamed: 'pending'.
 1 to: claims size do: [:index | | claim |
 claim := claims at: index.
 claim ifNotNil: [slots add: (Dictionary new at: 'slot' put: index; at: 'identifier' put: claim identifier;
 at: 'kind' put: claim kind; at: 'stage' put: claim stage asString;
 at: 'requiresProgress' put: (driveService claimRequiresProgress: claim);
 at: 'ownsWorkUnit' put: (claim activation notNil and: [claim activation unit notNil]); yourself)]].
 ^ slots asArray
]
