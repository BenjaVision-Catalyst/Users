"
Configured Runtime startup-failure qualification. Run only under CCNativeMcpLease, with an externally occupied UDP endpoint and no application submissions.
"
Class {
	#name : 'CUUsersConnectReadinessScenario',
	#superclass : 'CUUsersConnectNativeScenario',
	#category : 'BVC-Users-Connect-Tests-GT',
	#package : 'BVC-Users-Connect-Tests-GT'
}

{ #category : 'native validation' }
CUUsersConnectReadinessScenario >> runFailureConfiguration: connect directory: directory [
 | configuration orchestrator host worker service report |
 orchestrator := CROrchestrationConfiguration default heartbeatIntervalMillis: 1000; reconcileIntervalMillis: 1000; yourself.
 configuration := CRRuntimeConfiguration new label: 'Readiness startup failure'; services: {orchestrator. connect}; yourself.
 host := CRHostConfiguration new identifier: #authority; label: 'Authority'; address: 'localhost'; maxProcesses: 1; services: {CRRuntime orchestratorIdentifier. #connect}; yourself.
 configuration topology: (CRTopologyConfiguration new hosts: {host}; placementStrategyConfiguration: CRRoundRobinPlacementStrategyConfiguration new; yourself).
 configuration deployment serviceDeployments: (configuration services collect: [:cfg | CRServiceDeploymentConfiguration new serviceIdentifier: cfg identifier; label: cfg label; initialCount: 1; yourself]).
 configuration failureEvidenceConfiguration captureDebugArtifacts: false.
 self assert: configuration validate isValid. runtime := CRRuntime new.
 report := Dictionary new.
 [runtime configure: configuration. runtime start.
 self waitUntil: [worker := CRPharoWorker allInstances detect: [:candidate | candidate runtime == runtime and: [(candidate services serviceAtIdentifier: #connect) notNil]] ifNone: [nil]. worker notNil] directory: directory.
 service := worker services serviceAtIdentifier: #connect.
 self waitUntil: [| statistics | statistics := service status at: #statistics. statistics notNil and: [(statistics at: #nativePhase) >= 3 or: [statistics includesKey: #startError]]] directory: directory.
 report at: 'nativeFailureObserved' put: true; at: 'zeroApplicationSubmissions' put: true]
 ensure: [runtime stop.
 report at: 'runtimeStopped' put: (runtime status = CRStatus stopped).
 self assert: runtime status equals: CRStatus stopped.
 runtime registry unregister: runtime.
 report at: 'runtimeUnregistered' put: ((runtime registry runtimes identityIncludes: runtime) not).
 service ifNotNil: [report at: 'service' put: service status. self assert: (service status at: #buffersReleased)].
 CRPlatform current writeConnectEvidence: report to: (directory / 'failure-evidence.json') fullName].
 ^ report
]
