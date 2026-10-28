Class {
	#name : 'CUUsersExamples',
	#superclass : 'TestCase',
	#category : 'BVC-Users-Tests',
	#package : 'BVC-Users-Tests'
}

{ #category : 'tests - api' }
CUUsersExamples >> testDefaultUsers [
 <gtExample>
 <return: #OrderedCollection>
 | users admin unknown |
 users := CUUsers newAllUsers.
 self assert: users size equals: 2.
 admin := users first. unknown := users last.
 self assert: admin name equals: 'admin'.
 self assert: admin isSuperUser.
 self assert: unknown name equals: 'unknownUser'.
 self deny: unknown isSuperUser.
 self deny: admin == unknown.
 self assert: CUUsers admin == CUUsers admin.
 self assert: CUUsers unknownUser == CUUsers unknownUser.
 self assert: CUUsers admin isSuperUser.
 self deny: CUUsers unknownUser isSuperUser.
 ^ users
]

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
 | version coreClasses runtimeClasses |
 version := BaselineOfCatalystUsers new project version.
 #('default' 'runtime') do: [:group |
  self assert: ((version packagesForSpecNamed: group) collect: #name) asArray sorted equals: #('BVC-Users-Core' 'BVC-Users-Runtime')].
 self assert: ((version packagesForSpecNamed: 'core') collect: #name) asArray equals: #('BVC-Users-Core').
 self assert: ((version packagesForSpecNamed: 'tests') collect: #name) asArray sorted equals: #('BVC-Users-Core' 'BVC-Users-Runtime' 'BVC-Users-Tests').
 self assert: (version packageNamed: 'BVC-Users-Runtime') requires asArray equals: #('BVC-Users-Core' 'CatalystRuntime').
 coreClasses := (((MCPackage named: 'BVC-Users-Core') snapshot definitions select: [:definition | definition isClassDefinition]) collect: [:definition | definition className asString]) asArray sorted.
 runtimeClasses := (((MCPackage named: 'BVC-Users-Runtime') snapshot definitions select: [:definition | definition isClassDefinition]) collect: [:definition | definition className asString]) asArray sorted.
 self assert: coreClasses equals: #('CUUser' 'CUUsers').
 self assert: runtimeClasses equals: #('CUUsersCapability' 'CUUsersService' 'CUUsersWorkUnit').
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

{ #category : 'tests - api' }
CUUsersExamples >> testUsersApiRetainsUsers [
 <gtExample>
 <return: #CUUser>
 | users user originalUsers |
 users := CUUsers allUsers.
 originalUsers := users copy.
 user := CUUser new.
 [self assert: (CUUsers addUser: user) == user.
  self assert: CUUsers allUsers == users.
  self assert: (CUUsers allUsers includes: user).
  self assert: users size equals: originalUsers size + 1]
 ensure: [users remove: user ifAbsent: []].
 self assert: users equals: originalUsers.
 ^ user
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
