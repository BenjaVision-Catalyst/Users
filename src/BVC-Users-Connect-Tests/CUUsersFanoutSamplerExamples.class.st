Class {
	#name : 'CUUsersFanoutSamplerExamples',
	#superclass : 'TestCase',
	#category : 'BVC-Users-Connect-Tests',
	#package : 'BVC-Users-Connect-Tests'
}

{ #category : 'tests' }
CUUsersFanoutSamplerExamples >> testBufferedSnapshotsExportOnlyAtUninstall [
 <gtExample>
 <return: #CUUsersFanoutMemoryFixture>
 | fixture announcer sample nested |
 fixture := CUUsersFanoutMemoryFixture new initializeDiagnostics; yourself.
 announcer := CRAnnouncer new. fixture registerExportWith: announcer. fixture registerExportWith: announcer.
 nested := Dictionary new at: 'pending' put: 2; yourself.
 sample := Dictionary new at: 'sample' put: 1; at: 'millis' put: CRPlatform current currentMillis; at: 'feeds' put: {nested}; yourself.
 fixture recordDiagnostic: sample. nested at: 'pending' put: 99.
 self assert: fixture writes isEmpty.
 announcer announce: CRWorkerServicesStoppingAnnouncement new. self assert: fixture writes isEmpty.
 announcer announce: CRWorkerServicesUninstallingAnnouncement new.
 self assert: fixture writes size equals: 2.
 self assert: fixture writes first first equals: 'native-1.json'.
 self assert: (((fixture writes first second at: 'feeds') first) at: 'pending') equals: 2.
 self assert: (fixture writes last second at: 'ownerProcessVerified').
 announcer announce: CRWorkerServicesUninstallingAnnouncement new. self assert: fixture writes size equals: 2.
 self should: [fixture recordDiagnostic: (Dictionary new at: 'sample' put: 2; yourself)] raise: Error.
 ^ fixture
]

{ #category : 'tests' }
CUUsersFanoutSamplerExamples >> testExportRequiresRegisteredOwner [
 <gtExample>
 <return: #CUUsersFanoutMemoryFixture>
 | fixture announcer owner |
 fixture := CUUsersFanoutMemoryFixture new initializeDiagnostics; yourself.
 self should: [fixture exportDiagnostics] raise: Error.
 announcer := CRAnnouncer new. fixture registerExportWith: announcer.
 owner := fixture instVarNamed: 'diagnosticOwner'.
 fixture instVarNamed: 'diagnosticOwner' put: Object new.
 self should: [fixture exportDiagnostics] raise: Error.
 self assert: fixture writes isEmpty.
 fixture instVarNamed: 'diagnosticOwner' put: owner.
 announcer announce: CRWorkerServicesUninstallingAnnouncement new.
 self assert: fixture writes size equals: 1.
 ^ fixture
]

{ #category : 'tests' }
CUUsersFanoutSamplerExamples >> testOverflowIsReportedWithoutDroppingRetainedSamples [
 <gtExample>
 <return: #CUUsersFanoutMemoryFixture>
 | fixture announcer |
 fixture := CUUsersFanoutMemoryFixture new initializeDiagnostics; yourself.
 announcer := CRAnnouncer new. fixture registerExportWith: announcer.
 1 to: fixture maximumSamples do: [:index | fixture recordDiagnostic: (Dictionary new at: 'sample' put: index; yourself)].
 self should: [fixture recordDiagnostic: (Dictionary new at: 'sample' put: fixture maximumSamples + 1; yourself)] raise: Error.
 self assert: fixture writes isEmpty.
 announcer announce: CRWorkerServicesUninstallingAnnouncement new.
 self assert: (fixture writes last second at: 'sampleCount') equals: fixture maximumSamples.
 self assert: (fixture writes last second at: 'failure') equals: 'Users sampler buffer exhausted'.
 ^ fixture
]

{ #category : 'tests' }
CUUsersFanoutSamplerExamples >> testSequenceGapsAndLiveObjectsAreRefused [
 <gtExample>
 <return: #CUUsersFanoutMemoryFixture>
 | fixture |
 fixture := CUUsersFanoutMemoryFixture new initializeDiagnostics; yourself.
 self should: [fixture recordDiagnostic: (Dictionary new at: 'sample' put: 2; yourself)] raise: Error.
 self should: [fixture recordDiagnostic: (Dictionary new at: 'sample' put: 1; at: 'worker' put: Object new; yourself)] raise: Error.
 self assert: (fixture instVarNamed: 'samples') isEmpty.
 fixture recordDiagnostic: (Dictionary new at: 'sample' put: 1; yourself).
 self assert: (fixture instVarNamed: 'samples') size equals: 1.
 ^ fixture
]

{ #category : 'tests' }
CUUsersFanoutSamplerExamples >> testStartupUnavailabilityIsRetainedAsBoundedEvidence [
 <gtExample>
 <return: #CUUsersFanoutMemoryFixture>
 | fixture announcer |
 fixture := CUUsersFanoutMemoryFixture new initializeDiagnostics; yourself.
 announcer := CRAnnouncer new. fixture registerExportWith: announcer.
 fixture noteStartupSkip: 'Users service not installed' at: 42.
 announcer announce: CRWorkerServicesUninstallingAnnouncement new.
 self assert: (fixture writes last second at: 'startupSkips') equals: { {42. 'Users service not installed'} }.
 ^ fixture
]
