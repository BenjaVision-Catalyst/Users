Class {
	#name : 'CUUsersExamples',
	#superclass : 'TestCase',
	#category : 'Catalyst-Users-Tests',
	#package : 'Catalyst-Users-Tests'
}

{ #category : 'tests' }
CUUsersExamples >> testNamedServiceExecutesUsersWork [
<gtExample>
 <return: #CUUsersBindingTestWorkUnit>
 ^ self withWorkerDo: [:worker | | work |
 work := CUUsersBindingTestWorkUnit new.
 (CRWorkRouter deploymentTopology: worker runtime deploymentTopology)
  enqueue: (work asEnvelope serviceIdentifier: 'users'; yourself).
 self deny: work executed.
 worker executeWorkUnitInEnvelope: worker workerHandle workQueue nextForExecutionOrNil.
 self assert: work executed. self assert: work serviceIdentifier equals: 'users'.
 self assert: worker workerHandle failedWorkUnitExecutions isEmpty.
 work]
]

{ #category : 'tests - loading' }
CUUsersExamples >> testProductionAndTestLoadGroupsAreSeparate [
 <gtExample>
 <return: #MetacelloVersion>
 | version |
 version := BaselineOfCatalystUsers new project version.
 self assert: ((version packagesForSpecNamed: 'default') collect: #name) asArray sorted equals: #('BVC-Users-Core' 'Catalyst-Users-Runtime').
 self assert: ((version packagesForSpecNamed: 'runtime') collect: #name) asArray sorted equals: #('BVC-Users-Core' 'Catalyst-Users-Runtime').
 self assert: ((version packagesForSpecNamed: 'tests') collect: #name) asArray sorted equals: #('BVC-Users-Core' 'Catalyst-Users-Runtime' 'Catalyst-Users-Tests').
 self assert: ((version packagesForSpecNamed: 'core') collect: #name) asArray sorted equals: #('BVC-Users-Core').
 self assert: (version packageNamed: 'Catalyst-Users-Runtime') requires asArray equals: #('BVC-Users-Core' 'CatalystRuntime').
 ^ version
]

{ #category : 'tests' }
CUUsersExamples >> testStoppedServiceCannotExecuteWork [
<gtExample>
 <return: #CUUsersBindingTestWorkUnit>
 ^ self withWorkerDo: [:worker | | work service |
 service := worker services serviceAtIdentifier: 'users'. worker services stopService: service.
 work := CUUsersBindingTestWorkUnit new.
 self should: [(CRWorkRouter deploymentTopology: worker runtime deploymentTopology)
  enqueue: (work asEnvelope serviceIdentifier: 'users'; yourself)]
 raise: CRNoWorkerHostingRequiredServiceException.
 self deny: work executed. self assert: worker isWorkQueueEmpty. work]
]

{ #category : 'tests' }
CUUsersExamples >> testUnavailableNameDoesNotFallBack [
<gtExample>
 <return: #CUUsersBindingTestWorkUnit>
 ^ self withWorkerDo: [:worker | | work |
 work := CUUsersBindingTestWorkUnit new.
 self should: [(CRWorkRouter deploymentTopology: worker runtime deploymentTopology)
  enqueue: (work asEnvelope serviceIdentifier: 'missingUsers'; yourself)]
 raise: CRNoWorkerHostingRequiredServiceException.
 self deny: work executed. self assert: worker isWorkQueueEmpty. work]
]

{ #category : 'tests' }
CUUsersExamples >> testUnrelatedWorkCannotAcquireUsersCapability [
<gtExample>
 <return: #CUUsersDeniedTestWorkUnit>
 ^ self withWorkerDo: [:worker | | work failure |
 work := CUUsersDeniedTestWorkUnit new.
 (CRWorkRouter deploymentTopology: worker runtime deploymentTopology)
  enqueue: (work asEnvelope serviceIdentifier: 'users'; yourself).
 worker executeWorkUnitInEnvelope: worker workerHandle workQueue nextForExecutionOrNil.
 self deny: work executed.
 self assert: worker workerHandle failedWorkUnitExecutions size equals: 1.
 failure := worker workerHandle failedWorkUnitExecutions asArray first.
 self assert: failure errorClassName asString equals: 'CRCapabilityDeniedException'.
 work]
]

{ #category : 'tests' }
CUUsersExamples >> testUsersCapabilityIsNotServiceControlAuthority [
<gtExample>
 <return: #CUUsersService>
 ^ self withWorkerDo: [:worker | | service |
 service := worker services serviceAtIdentifier: 'users'.
 self deny: (CUUsersCapability canBeGrantedToWorkUnitClass: CRWorkUnit).
 self deny: (CUUsersCapability canBeGrantedToWorkUnitClass: CUUsersWorkUnit).
 self deny: (CUUsersCapability canBeGrantedToServiceClass: CUUsersService).
 self assert: CUUsersBindingTestWorkUnit serviceClass == CUUsersService.
 self assert: CUUsersBindingTestWorkUnit requiredCapabilities equals: {CUUsersCapability}.
 service]
]

{ #category : 'fixtures' }
CUUsersExamples >> withWorkerDo: block [
| worker result |
 worker := CRFinalizedResultTestWorker new.
 worker workerHandle workerIdentifier: #usersProjectTest.
 worker bindRuntime: CRRuntime new hostIdentifier: #usersProjectTest.
 worker services installServiceClass: CUUsersService serviceIdentifier: 'users' configuration: CRServiceConfiguration default.
 worker services installServiceClass: CUUsersService serviceIdentifier: 'otherUsers' configuration: CRServiceConfiguration default.
 worker start. worker workerHandle lifecycleStatus: CRStatus running.
 worker services startAll. worker publishHandleToTopology.
 [result := block value: worker] ensure: [
 [worker isWorkQueueEmpty] whileFalse: [worker executeWorkUnitInEnvelope: worker workerHandle workQueue nextForExecutionOrNil].
 worker stopAndUninstallServices. worker unpublishHandleFromTopology].
 ^ result
]
