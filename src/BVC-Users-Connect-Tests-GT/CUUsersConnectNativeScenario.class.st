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

{ #category : 'native qualification' }
CUUsersConnectNativeScenario >> runServerConfigurations: specifications directory: directory [
 | configuration orchestrator host services deployments worker usersService connects original prefix results originalGate deadline idleStarts idleChecks parameters fanout cadence |
 parameters := STONJSON fromString: (directory / 'parameters.json') contents.
 cadence := parameters at: 'cadenceConfiguration' ifAbsent: [Dictionary new].
 fanout := parameters at: 'fanout' ifAbsent: [false]. prefix := parameters at: 'prefix'.
 original := CUUsers allUsers copy. originalGate := CUUsersCommitGateMessageFixture gateDirectory. connects := OrderedCollection new.
 orchestrator := CROrchestrationConfiguration default heartbeatIntervalMillis: (cadence at: 'heartbeatIntervalMillis' ifAbsent: [500]); reconcileIntervalMillis: (cadence at: 'reconcileIntervalMillis' ifAbsent: [100]); yourself.
 services := OrderedCollection with: orchestrator with: (CUUsersConfiguration new identifier: #users; label: 'Volatile authoritative Users'; authoritative: true; maximumFeeds: (parameters at: 'maximumFeeds' ifAbsent: [16]); maximumUsersPerFeed: (parameters at: 'maximumUsersPerFeed' ifAbsent: [256]); yourself).
 specifications do: [:spec | | cfg |
  cfg := CCQuicConfiguration new nativeProtocolVersion: 2; identifier: ('connect_', (spec at: 'name')) asSymbol; label: (fanout ifTrue: [directory fullName] ifFalse: ['Users native server']);
   nativeOptionsJson: (spec at: 'serverOptions') asFileReference contents; libraryPath: (spec at: 'library');
   principal: (spec at: 'name'); readinessEnabled: (parameters at: 'readinessEnabled' ifAbsent: [false]); idleMillis: (cadence at: 'idleMillis' ifAbsent: [20]); allowedOperations: #(1 2 3 4 5 6 7 8 9 65534); applicationClass: (fanout ifTrue: [CUUsersFanoutApplicationFixture] ifFalse: [CUUsersCommitGateApplicationFixture]);
   bindings: {CRServiceBindingConfiguration new identifier: #users; serviceIdentifier: #users; yourself}; yourself.
  services add: cfg].
 configuration := CRRuntimeConfiguration new label: 'GT Users authority qualification'; services: services asArray; yourself.
 host := CRHostConfiguration new identifier: #authority; label: 'GT authority'; address: 'localhost'; maxProcesses: 1; services: (services collect: #identifier) asArray; yourself.
 configuration topology: (CRTopologyConfiguration new hosts: {host}; placementStrategyConfiguration: CRRoundRobinPlacementStrategyConfiguration new; yourself).
 deployments := services collect: [:service | CRServiceDeploymentConfiguration new serviceIdentifier: service identifier; label: service label; initialCount: 1; yourself].
 configuration deployment serviceDeployments: deployments asArray. configuration failureEvidenceConfiguration captureDebugArtifacts: false.
 self assert: configuration validate isValid. runtime := CRRuntime new.
 idleStarts := Dictionary new. idleChecks := Set new. results := Dictionary new at: 'createdFromConfiguration' put: true; at: 'volatileAuthority' put: true; at: 'library' put: (specifications first at: 'library'); yourself.
 [runtime configure: configuration. runtime start.
 (Delay forMilliseconds: 1000) wait.
 CRPlatform current writeConnectEvidence: (Dictionary new at: 'workers' put: ((CRPharoWorker allInstances select: [:each | each runtime == runtime]) collect: [:each |
  {each workerHandle workerIdentifier asString. each status printString. each workerHandle serviceHandles collect: [:handle | {handle serviceIdentifier asString. handle lifecycleStatus printString}]. each workerHandle failedWorkUnitExecutions asArray collect: [:failure | failure errorMessage]}]) asArray printString; yourself) to: (directory / 'startup-diagnostic.json') fullName.
 [self waitUntil: [runtime convergenceReport notNil and: [runtime convergenceReport isConverged]] directory: directory]
 on: Error, TestFailure do: [:error |
  CRPlatform current writeConnectEvidence: (Dictionary new at: 'workers' put: ((CRPharoWorker allInstances select: [:each | each runtime == runtime]) collect: [:each |
   {each workerHandle workerIdentifier asString. each status printString. each workerHandle serviceHandles collect: [:handle | {handle serviceIdentifier asString. handle lifecycleStatus printString}]. each workerHandle failedWorkUnitExecutions asArray collect: [:failure | failure errorMessage]}]) asArray printString;
   at: 'report' put: runtime convergenceReport printString; yourself) to: (directory / 'server-diagnostic.json') fullName.
  error pass].
 worker := CRPharoWorker allInstances detect: [:candidate | candidate runtime == runtime and: [(candidate services serviceAtIdentifier: #users) notNil]].
 usersService := worker services serviceAtIdentifier: #users. (worker workerHandle statistics at: #workUnitExecution) maxSamples: 100000.
 specifications do: [:spec | connects add: (worker services serviceAtIdentifier: ('connect_', (spec at: 'name')) asSymbol)].
 CRPlatform current writeConnectEvidence: (Dictionary new at: 'ready' put: true; yourself) to: (directory / 'server-ready.json') fullName.
 deadline := Time millisecondClockValue + 540000.
 [(directory / 'server-stop') exists or: [Time millisecondClockValue >= deadline]] whileFalse: [
  [| params | params := STONJSON fromString: (directory / 'parameters.json') contents.
   (params at: 'activeClient' ifAbsent: [nil]) ifNotNil: [:spec | CUUsersCommitGateMessageFixture gateDirectory ~= (spec at: 'output') ifTrue: [
    CUUsersCommitGateMessageFixture gateDirectory: (spec at: 'output').
    CRPlatform current writeConnectEvidence: (Dictionary new at: 'prefix' put: (spec at: 'prefix'); yourself) to: (spec at: 'output'), '/gate-ready.json']]] on: Error do: [:error | ].
  specifications do: [:client | | clientDirectory clientKey count |
   clientDirectory := (client at: 'output') asFileReference. clientKey := client at: 'prefix'.
   ((clientDirectory / 'idle-start.json') exists and: [(idleStarts includesKey: clientKey) not]) ifTrue: [
    count := (worker workerHandle statistics at: #workUnitExecution) samples last sequence.
    idleStarts at: clientKey put: count].
   ((clientDirectory / 'idle-end.json') exists and: [(idleStarts includesKey: clientKey) and: [(idleChecks includes: clientKey) not]]) ifTrue: [
    count := (worker workerHandle statistics at: #workUnitExecution) samples count: [:sample | (#(CUReadLiveUserWork CUReceiveUserChangesWork) includes: sample workUnitClass name)].
    self deny: ((worker workerHandle statistics at: #workUnitExecution) samples anySatisfy: [:sample |
 sample sequence > (idleStarts at: clientKey) and: [#(CUReadLiveUserWork CUReceiveUserChangesWork) includes: sample workUnitClass name]]).
 idleChecks add: clientKey.
    CRPlatform current writeConnectEvidence: (Dictionary new at: 'zeroIdleReads' put: true; at: 'zeroIdleReceiveRequests' put: true; yourself) to: (clientDirectory / 'idle-proof.json') fullName]].
  (Delay forMilliseconds: 10) wait].
 self assert: (directory / 'server-stop') exists.
 results at: 'zeroIdleReads' put: true; at: 'zeroIdleReceiveRequests' put: true; at: 'idleChecks' put: idleChecks size.
 results at: 'readSamples' put: ((worker workerHandle statistics at: #workUnitExecution) samples count: [:sample | sample workUnitClass == CUReadLiveUserWork]).
 results at: 'createdUsers' put: ((CUUsers allUsers select: [:user | user name beginsWith: prefix]) collect: #name) asArray.
 [| selected |
 selected := (worker workerHandle statistics at: #workUnitExecution) samples select: [:sample |
  sample isSuccessful and: [(sample workUnitClass inheritsFrom: CULiveUserWork) and: [#(3 5) includes: sample workUnitClass operation]]].
 self assert: selected notEmpty.
 self assert: (selected allSatisfy: [:sample | sample transactionOutcome = #inMemory and: [sample completionRecordingOutcome = #inMemory]]).
 results at: 'publicationCommitEvidenceSource' put: 'verifiedMutationResultFinalization'; at: 'inMemoryFinalizations' put: selected size] value
 ] ensure: [
  runtime stop. runtime registry unregister: runtime. CUUsersCommitGateMessageFixture gateDirectory: originalGate.
  CUUsers allUsers removeAllSuchThat: [:user | (user name beginsWith: prefix) or: [user creationName beginsWith: prefix]].
  original do: [:user | self assert: (CUUsers allUsers identityIncludes: user)].
  results at: 'runtimeStopped' put: (runtime status = CRStatus stopped); at: 'runtimeUnregistered' put: ((runtime registry runtimes identityIncludes: runtime) not);
   at: 'buffersReleased' put: (connects allSatisfy: [:service | (service status at: #buffersReleased)])].
 evidence := results. CRPlatform current writeConnectEvidence: results to: (directory / 'server-evidence.json') fullName. ^ results
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
