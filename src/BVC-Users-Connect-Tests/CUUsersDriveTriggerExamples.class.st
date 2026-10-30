Class {
	#name : 'CUUsersDriveTriggerExamples',
	#superclass : 'TestCase',
	#category : 'BVC-Users-Connect-Tests',
	#package : 'BVC-Users-Connect-Tests'
}

{ #category : 'helpers' }
CUUsersDriveTriggerExamples >> executionFixture [
 ^ (CRWorkUnitExecution envelope: CCQuicDriveWork new asEnvelope) startMillis: 10; endMillis: 11; markSuccessful; yourself
]

{ #category : 'helpers' }
CUUsersDriveTriggerExamples >> serviceFixture [
 | service bridge |
 service := CCQuicService new. bridge := CCQuicBridge new.
 bridge instVarNamed: 'observedGeneration' put: 10.
 service instVarNamed: 'bridge' put: bridge; instVarNamed: 'pending' put: (Array new: 3);
 instVarNamed: 'stats' put: (Dictionary new at: #drives put: 1; at: #entryHintsConsumed put: 1; yourself);
 instVarNamed: 'pushContinuation' put: false; instVarNamed: 'callBudget' put: 100;
 instVarNamed: 'byteBudget' put: 1000; instVarNamed: 'candidateBudget' put: 60;
 instVarNamed: 'driveDeadline' put: 20.
 ^ service
]

{ #category : 'tests' }
CUUsersDriveTriggerExamples >> testDriveTraceBoundIsExplicit [
 <gtExample>
 <return: #CUUsersDriveTriggerMetrics>
 | metrics |
 metrics := CUUsersDriveTriggerMetrics new configureFrom: CRWorkUnitExecutionMetrics new service: self serviceFixture.
 metrics instVarNamed: 'driveRows' put: (OrderedCollection new addAll: (Array new: metrics maximumDriveRows); yourself).
 self should: [metrics recordDrive: self executionFixture sequence: 1] raise: Error.
 self assert: (metrics driveReport at: 'rows') size equals: metrics maximumDriveRows.
 ^ metrics
]

{ #category : 'tests' }
CUUsersDriveTriggerExamples >> testLocalReplacementPreservesSequenceAndRetention [
 <gtExample>
 <return: #CUUsersDriveTriggerMetrics>
 | original metrics collection |
 original := CRWorkUnitExecutionMetrics new maxSamples: 2; yourself.
 2 timesRepeat: [original recordExecution: self executionFixture].
 collection := original samples.
 metrics := CUUsersDriveTriggerMetrics new configureFrom: original service: self serviceFixture.
 metrics recordExecution: self executionFixture.
 self assert: metrics samples == collection. self assert: metrics maxSamples equals: 2.
 self assert: metrics lastSequenceNumber equals: 3.
 self assert: ((metrics driveReport at: 'rows') first at: 'sequence') equals: 3.
 ^ metrics
]

{ #category : 'tests' }
CUUsersDriveTriggerExamples >> testQueuedExecutionIsDistinguishedFromReadyIo [
 <gtExample>
 <return: #CUUsersDriveTriggerMetrics>
 | service metrics activation response row |
 service := self serviceFixture.
 activation := CRServiceActivation owner: nil unit: Object new epoch: Object new charge: 1.
 response := CCQuicDeferredResponse new.
 (service instVarNamed: 'pending') at: 1 put: (CCQuicClaim new kind: 1; stage: #executing; activation: activation; yourself);
 at: 2 put: (CCQuicClaim new stage: #waiting; body: response; yourself).
 metrics := CUUsersDriveTriggerMetrics new configureFrom: CRWorkUnitExecutionMetrics new service: service.
 metrics recordExecution: self executionFixture.
 row := (metrics driveReport at: 'rows') first.
 self deny: (row at: 'localContinuationPredicate').
 self assert: (row at: 'executingWithUnit') equals: 1.
 self assert: (row at: 'immediateClaims') equals: 0.
 response complete: #[1] status: 0.
 metrics recordExecution: self executionFixture.
 row := (metrics driveReport at: 'rows') last.
 self assert: (row at: 'waitingReady') equals: 1.
 self assert: (row at: 'immediateClaims') equals: 1.
 ^ metrics
]

{ #category : 'tests' }
CUUsersDriveTriggerExamples >> testScanCopiesSlotPositionsAndCandidateCharges [
 <gtExample>
 <return: #CUUsersDriveTriggerMetrics>
 | service metrics claim scan |
 service := self serviceFixture. service instVarNamed: 'cursor' put: 0.
 claim := CCQuicClaim new identifier: 99; kind: 1; stage: #captured; yourself.
 (service instVarNamed: 'pending') at: 3 put: claim.
 metrics := CUUsersDriveTriggerMetrics new configureFrom: CRWorkUnitExecutionMetrics new service: service.
 metrics recordScanEntry.
 service instVarNamed: 'cursor' put: 2; instVarNamed: 'candidateBudget' put: 58.
 metrics recordExecution: self executionFixture.
 scan := (metrics driveReport at: 'rows') first at: 'claimScan'.
 self assert: (scan at: 'entryMatched').
 self assert: (scan at: 'claimCandidateCharges') equals: 2.
 self assert: (scan at: 'cursorBefore') equals: 0. self assert: (scan at: 'cursorAfter') equals: 2.
 self assert: ((scan at: 'slotsBefore') first at: 'slot') equals: 3.
 claim stage: #discard.
 self assert: ((scan at: 'slotsBefore') first at: 'stage') equals: 'captured'.
 self assert: ((scan at: 'slotsAfter') first at: 'stage') equals: 'captured'.
 self assert: (STON toJsonString: metrics driveReport) notEmpty.
 ^ metrics
]

{ #category : 'tests' }
CUUsersDriveTriggerExamples >> testScanEntryIsOneShotAndDriveMatched [
 <gtExample>
 <return: #CUUsersDriveTriggerMetrics>
 | service metrics rows |
 service := self serviceFixture. service instVarNamed: 'cursor' put: 0.
 metrics := CUUsersDriveTriggerMetrics new configureFrom: CRWorkUnitExecutionMetrics new service: service.
 metrics recordScanEntry.
 (service instVarNamed: 'stats') at: #drives put: 2.
 metrics recordExecution: self executionFixture.
 self deny: (((metrics driveReport at: 'rows') first at: 'claimScan') at: 'entryMatched').
 metrics recordScanEntry.
 metrics recordExecution: self executionFixture.
 metrics recordExecution: self executionFixture.
 rows := metrics driveReport at: 'rows'.
 self assert: ((rows second at: 'claimScan') at: 'entryMatched').
 self deny: ((rows third at: 'claimScan') at: 'entryMatched').
 ^ metrics
]

{ #category : 'tests' }
CUUsersDriveTriggerExamples >> testTraceCopiesCountersAndDoesNotEnterDurableSamples [
 <gtExample>
 <return: #CUUsersDriveTriggerMetrics>
 | service metrics first durable |
 service := self serviceFixture.
 metrics := CUUsersDriveTriggerMetrics new configureFrom: CRWorkUnitExecutionMetrics new service: service.
 metrics recordExecution: self executionFixture.
 first := (metrics driveReport at: 'rows') first.
 (service instVarNamed: 'stats') at: #entryHintsConsumed put: 2; at: #drives put: 2.
 (service instVarNamed: 'bridge') instVarNamed: 'observedGeneration' put: 12.
 metrics recordExecution: self executionFixture.
 self assert: ((first at: 'statisticsDelta') at: 'entryHintsConsumed') equals: 1.
 self assert: (((metrics driveReport at: 'rows') last at: 'entryNativeGenerationDelta')) equals: 2.
 durable := CRWorkUnitExecutionMetrics new recordExecution: self executionFixture.
 self assert: durable localTimings isNil.
 ^ metrics
]
