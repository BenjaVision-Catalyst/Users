Class {
	#name : 'CUUsersDriveTriggerApplicationFixture',
	#superclass : 'CUUsersFanoutApplicationFixture',
	#instVars : [
		'driveMetrics',
		'traceService'
	],
	#category : 'BVC-Users-Connect-Tests',
	#package : 'BVC-Users-Connect-Tests'
}

{ #category : 'qualification' }
CUUsersDriveTriggerApplicationFixture >> exportDiagnostics [
 Processor activeProcess == diagnosticOwner ifFalse: [self error: 'Drive export requires its Runtime owner'].
 exported ifTrue: [^ self].
 driveMetrics ifNotNil: [self writeDiagnostic: driveMetrics driveReport name: 'drive-triggers.json'].
 ^ super exportDiagnostics
]

{ #category : 'qualification' }
CUUsersDriveTriggerApplicationFixture >> initializeDiagnostics [
 super initializeDiagnostics. driveMetrics := nil. traceService := nil
]

{ #category : 'qualification' }
CUUsersDriveTriggerApplicationFixture >> progressUsing: service [
 | worker metrics |
 traceService := service.
 driveMetrics ifNil: [
  worker := (service instVarNamed: 'port') instVarNamed: 'worker'.
  metrics := worker workerHandle statistics at: #workUnitExecution.
  driveMetrics := CUUsersDriveTriggerMetrics new configureFrom: metrics service: service.
  worker workerHandle statistics at: #workUnitExecution put: driveMetrics].
 ^ super progressUsing: service
]

{ #category : 'qualification' }
CUUsersDriveTriggerApplicationFixture >> recordDiagnostic: sample [
 | native values |
 native := traceService instVarNamed: 'bridge'.
 values := #(18 19) collect: [:field | native info: field].
 traceService instVarNamed: 'callBudget' put: (traceService instVarNamed: 'callBudget') - 2.
 sample at: 'readinessCounterBusy' put: (values anySatisfy: [:v | v = 16rFFFFFFFFFFFFFFFF]).
 (sample at: 'readinessCounterBusy') ifFalse: [
  (sample at: 'native') at: '18' put: values first; at: '19' put: values second].
 ^ super recordDiagnostic: sample
]
