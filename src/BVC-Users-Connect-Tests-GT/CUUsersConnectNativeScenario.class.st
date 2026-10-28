"
Opt-in native GT client Runtime owner. Called only inside CCNativeMcpLease by the qualification controller.
"
Class {
	#name : 'CUUsersConnectNativeScenario',
	#superclass : 'TestCase',
	#instVars : [
		'runtime',
		'evidence'
	],
	#category : 'BVC-Users-Connect-Tests-GT',
	#package : 'BVC-Users-Connect-Tests-GT'
}

{ #category : 'accessing' }
CUUsersConnectNativeScenario >> evidence [
 ^ evidence
]

{ #category : 'native validation' }
CUUsersConnectNativeScenario >> runConfiguration: connectConfiguration cases: cases directory: directory [
 | configuration orchestrator host worker service client results originalCount convergence workerIds |
 originalCount := CUUsers allUsers size. results := OrderedCollection new.
 runtime := CRRuntime new.
 orchestrator := CROrchestrationConfiguration default heartbeatIntervalMillis: 500; reconcileIntervalMillis: 100; yourself.
 configuration := CRRuntimeConfiguration new label: 'Users native client'; services: {orchestrator. connectConfiguration}; yourself.
 host := CRHostConfiguration new identifier: #client; label: 'Client'; address: 'localhost'; maxProcesses: 1; services: {CRRuntime orchestratorIdentifier. #connect}; yourself.
 configuration topology: (CRTopologyConfiguration new hosts: {host}; placementStrategyConfiguration: CRRoundRobinPlacementStrategyConfiguration new; yourself).
 configuration deployment serviceDeployments: {CRServiceDeploymentConfiguration new serviceIdentifier: CRRuntime orchestratorIdentifier; label: 'Orchestrator'; initialCount: 1; yourself. CRServiceDeploymentConfiguration new serviceIdentifier: #connect; label: 'Connect'; initialCount: 1; yourself}.
 configuration failureEvidenceConfiguration captureDebugArtifacts: false.
 self assert: configuration validate isValid.
 [runtime configure: configuration. runtime start.
 
 self waitUntil: [runtime convergenceReport notNil and: [runtime convergenceReport isConverged]] directory: directory.
 convergence := true. workerIds := runtime deploymentTopology snapshot workerHandles collect: [:handle | handle workerIdentifier asString].
 worker := CRPharoWorker allInstances detect: [:candidate | candidate runtime == runtime and: [(candidate services serviceAtIdentifier: #connect) notNil]].
 service := worker services serviceAtIdentifier: #connect. client := CUUsersClient usingConnectService: service.
 
 self waitUntil: [client isReady] directory: directory.
 cases do: [:test | | future result user |
  user := CUUser new name: (test at: 'name'); isSuperUser: (test at: 'superUser'); yourself.
  
  future := client createUser: user.
  self waitUntil: [future isFinished] directory: directory.
  self assert: future state asString equals: (test at: 'expected').
  result := Dictionary new at: 'name' put: user name; at: 'state' put: future state asString; yourself.
  future state = #completed ifTrue: [self assert: future value class == CUUser. self assert: future value name equals: user name. self deny: future value isSuperUser.
   result at: 'nativeClass' put: future value class name asString].
  results add: result].
 self assert: CUUsers allUsers size equals: originalCount
 ] ensure: [runtime stop. runtime registry unregister: runtime].
 evidence := Dictionary new at: 'runtimeIdentifier' put: runtime identifier asString; at: 'configurationVersion' put: runtime effectiveConfiguration version;
  at: 'createdFromConfiguration' put: true; at: 'converged' put: convergence; at: 'workerIdentifiers' put: workerIds asArray;
  at: 'results' put: results asArray; at: 'clientStoreUnchanged' put: (CUUsers allUsers size = originalCount); at: 'runtimeStopped' put: (runtime status = CRStatus stopped);
  at: 'runtimeUnregistered' put: ((runtime registry runtimes identityIncludes: runtime) not); at: 'service' put: service status; yourself.
 CRPlatform current writeConnectEvidence: evidence to: (directory / 'evidence.json') fullName.
 ^ evidence
]

{ #category : 'tests - loading' }
CUUsersConnectNativeScenario >> testConnectLoadingIsOptional [
 <gtExample>
 <return: #MetacelloVersion>
 | version |
 version := BaselineOfCatalystUsers new project version.
 self assert: ((version packagesForSpecNamed: 'default') collect: #name) asArray sorted equals: #('BVC-Users-Core' 'BVC-Users-Runtime').
 self assert: ((version packagesForSpecNamed: 'connect') collect: #name) asArray sorted equals: #('BVC-Users-Connect-Core' 'BVC-Users-Core' 'BVC-Users-Runtime').
 self assert: (version packageNamed: 'BVC-Users-Connect-Core') requires asArray equals: #('BVC-Users-Runtime' 'CatalystConnect').
 self assert: (version packageNamed: 'BVC-Users-Connect-Tests-GT') requires asArray equals: #('BVC-Users-Connect-Tests' 'CatalystConnect tests').
 ^ version
]

{ #category : 'private' }
CUUsersConnectNativeScenario >> waitUntil: predicate directory: directory [
 | deadline |
 deadline := Time millisecondClockValue + 30000.
 [predicate value or: [(directory / 'stop') exists or: [Time millisecondClockValue >= deadline]]] whileFalse: [(Delay forMilliseconds: 5) wait].
 self assert: predicate value description: 'Native Users client did not reach the expected state.'
]
