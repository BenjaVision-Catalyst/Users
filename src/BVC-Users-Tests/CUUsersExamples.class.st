Class {
	#name : 'CUUsersExamples',
	#superclass : 'TestCase',
	#category : 'BVC-Users-Tests',
	#package : 'BVC-Users-Tests'
}

{ #category : 'tests - creating' }
CUUsersExamples >> testCreateUserCapabilityExpiresOnRestart [
 <gtExample>
 <return: #CUUser>
 | user users |
 users := CUUsers allUsers. user := CUUser new name: 'Fresh Users epoch'; yourself.
 [self withWorkerDo: [:worker | | service old current |
  service := worker services serviceAtIdentifier: 'users'.
  old := service providedCapabilityIfPresent: CUUsersCapability.
  worker services stopService: service.
  self should: [old createUser: user] raise: CRCapabilityDeniedException.
  worker services startServiceIdentifier: 'users'.
  self should: [old createUser: user] raise: CRCapabilityDeniedException.
  self deny: (users identityIncludes: user).
  current := service providedCapabilityIfPresent: CUUsersCapability.
  self assert: (current createUser: user) == user]]
 ensure: [users remove: user ifAbsent: []].
 ^ user
]

{ #category : 'tests - creating' }
CUUsersExamples >> testCreateUserMissingServiceDoesNotMutate [
 <gtExample>
 <return: #CUCreateUserWorkUnit>
 | user work users original |
 users := CUUsers allUsers. original := users copy.
 user := CUUser new name: 'Missing Users destination'; yourself.
 work := CUCreateUserWorkUnit user: user.
 self withWorkerDo: [:worker |
  self should: [(CRWorkRouter deploymentTopology: worker runtime deploymentTopology)
   enqueue: (work asEnvelope serviceIdentifier: 'missingUsers'; yourself)]
   raise: CRNoWorkerHostingRequiredServiceException.
  self assert: worker isWorkQueueEmpty].
 self assert: users equals: original.
 ^ work
]

{ #category : 'tests - creating' }
CUUsersExamples >> testCreateUserQueueHonoursTransactionRequirement [
 <gtExample>
 <return: #CUCreateUserWorkUnit>
 | user work users localGemStone |
 users := CUUsers allUsers. user := CUUser new name: 'Queued create user example'; yourself.
 work := CUCreateUserWorkUnit user: user.
 [self withWorkerDo: [:worker |
  localGemStone := worker executionStrategy class name asString = 'CRGemStoneLocalExecutionStrategy'.
  (CRWorkRouter deploymentTopology: worker runtime deploymentTopology)
   enqueue: (work asEnvelope serviceIdentifier: 'users'; yourself).
  self deny: (users identityIncludes: user).
  worker executeWorkUnitInEnvelope: worker workerHandle workQueue nextForExecutionOrNil.
  localGemStone ifTrue: [
   self deny: (users identityIncludes: user).
   self assert: worker workerHandle failedWorkUnitExecutions size equals: 1.
   self assert: worker workerHandle failedWorkUnitExecutions asArray first errorClassName asString equals: 'CRWorkUnitTransactionError']
  ifFalse: [self assert: (users identityIncludes: user). self assert: worker workerHandle failedWorkUnitExecutions isEmpty].
  self assert: worker isWorkQueueEmpty]]
 ensure: [users remove: user ifAbsent: []].
 ^ work
]

{ #category : 'tests - creating' }
CUUsersExamples >> testCreateUserRejectsDuplicateObject [
 <gtExample>
 <return: #CUUser>
 | user users size |
 users := CUUsers allUsers. user := CUUser new name: 'Duplicate create user example'; yourself.
 [CUUsers createUser: user. size := users size.
  self should: [CUUsers createUser: user] raise: CUUserCreationError.
  self assert: users size equals: size]
 ensure: [users remove: user ifAbsent: []].
 ^ user
]

{ #category : 'tests - creating' }
CUUsersExamples >> testCreateUserRejectsInvalidOrElevatedUser [
 <gtExample>
 <return: #CUUser>
 | users original user |
 users := CUUsers allUsers. original := users copy.
 user := CUUser new name: 'Rejected super user'; isSuperUser: true; yourself.
 self should: [CUUsers createUser: Object new] raise: CUUserCreationError.
 self should: [CUUsers createUser: user] raise: CUUserCreationError.
 self assert: users equals: original.
 ^ user
]

{ #category : 'tests - creating' }
CUUsersExamples >> testCreateUserStoresNativeUser [
 <gtExample>
 <return: #CUUser>
 | user users |
 users := CUUsers allUsers. user := CUUser new name: 'Create user example'; yourself.
 [self assert: (CUUsers createUser: user) == user.
  self assert: (users identityIncludes: user).
  self deny: user isSuperUser]
 ensure: [users remove: user ifAbsent: []].
 ^ user
]

{ #category : 'tests - creating' }
CUUsersExamples >> testCreateUserWorkUnitUsesNamedCapability [
 <gtExample>
 <return: #CUCreateUserWorkUnit>
 | user work users |
 users := CUUsers allUsers. user := CUUser new name: 'Bound create user example'; yourself.
 work := CUCreateUserWorkUnit user: user.
 [self withWorkerDo: [:worker | | execution |
  execution := CRWorkUnitExecution envelope: (work asEnvelope serviceIdentifier: 'users'; yourself).
  worker prepareWorkUnitExecution: execution.
  self assert: (work executeInContext: execution context) == user.
  self assert: (users identityIncludes: user).
  self assert: work class requiresTransaction.
  self deny: work class allowsConflictReplay]]
 ensure: [users remove: user ifAbsent: []].
 ^ work
]

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

{ #category : 'tests - lookup' }
CUUsersExamples >> testGetUserRefusesAmbiguousNames [
 <gtExample>
 <return: #CUUser>
 | first second users original |
 users := CUUsers allUsers. original := users copy.
 first := CUUser new name: 'Ambiguous lookup example'; yourself.
 second := CUUser new name: first name; yourself.
 [CUUsers createUser: first. CUUsers createUser: second.
 self should: [CUUsers getUser: first name] raise: CUAmbiguousUserError.
 self assert: users size equals: original size + 2]
 ensure: [users remove: first ifAbsent: []; remove: second ifAbsent: []].
 self assert: users equals: original. ^ first
]

{ #category : 'tests - lookup' }
CUUsersExamples >> testGetUserRequiresCurrentAuthoritativeCapability [
 <gtExample>
 <return: #CUGetUserWorkUnit>
 | work |
 work := CUGetUserWorkUnit named: 'admin'.
 self withWorkerDo: [:worker | | service execution capability |
 service := worker services serviceAtIdentifier: 'users'.
 execution := CRWorkUnitExecution envelope: (work asEnvelope serviceIdentifier: 'users'; yourself).
 worker prepareWorkUnitExecution: execution.
 self assert: (work executeInContext: execution context) == CUUsers admin.
 capability := service providedCapabilityIfPresent: CUUsersCapability.
 worker services stopService: service.
 self should: [capability getUser: 'admin'] raise: CRCapabilityDeniedException.
 worker services startServiceIdentifier: 'users'.
 self should: [capability getUser: 'admin'] raise: CRCapabilityDeniedException.
 capability := service providedCapabilityIfPresent: CUUsersCapability.
 worker services applyConfiguration: (service configuration authoritative: false; serviceClass: CUUsersService; yourself) serviceIdentifier: 'users' version: 1.
 self should: [capability getUser: 'admin'] raise: CRCapabilityDeniedException].
 self assert: work class requiresTransaction. self deny: work class allowsConflictReplay. ^ work
]

{ #category : 'tests - lookup' }
CUUsersExamples >> testGetUserUsesExactNameAndExplicitAbsence [
 <gtExample>
 <return: #CUUser>
 | user users original |
 users := CUUsers allUsers. original := users copy.
 user := CUUser new name: 'Exact lookup example'; yourself.
 [CUUsers createUser: user.
 self assert: (CUUsers getUser: user name) == user.
 self assert: (CUUsers getUser: 'exact lookup example') isNil.
 self assert: (CUUsers getUser: 'No such lookup example') isNil.
 self assert: (CUUsers getUser: 'admin') == CUUsers admin.
 self assert: (CUUsers getUser: 'unknownUser') == CUUsers unknownUser.
 self assert: users size equals: original size + 1]
 ensure: [users remove: user ifAbsent: []].
 self assert: users equals: original. ^ user
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

{ #category : 'tests - creating' }
CUUsersExamples >> testNonAuthoritativeServiceCannotCreateUser [
 <gtExample>
 | user users |
 user := CUUser new name: 'Rejected non-authoritative creation'; yourself.
 users := CUUsers allUsers.
 self withWorkerDo: [ :worker |
  | service configuration |
  service := worker services serviceAtIdentifier: 'users'.
  configuration := service configuration authoritative: false; serviceClass: CUUsersService; yourself.
  worker services applyConfiguration: configuration serviceIdentifier: 'users' version: 1.
  self should: [ (service providedCapabilityIfPresent: CUUsersCapability) createUser: user ] raise: CRCapabilityDeniedException.
  self deny: (users identityIncludes: user) ]
]

{ #category : 'tests' }
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
 self assert: coreClasses equals: #('CUAmbiguousUserError' 'CUUser' 'CUUserCreationError' 'CUUsers').
 self assert: runtimeClasses equals: #('CUCreateUserWorkUnit' 'CUGetUserWorkUnit' 'CUUsersCapability' 'CUUsersService' 'CUUsersWorkUnit').
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

{ #category : 'tests - creating' }
CUUsersExamples >> testTransactionalCreationRejectsAutomaticCompletion [
 <gtExample>
 <return: #CRWorkUnitEnvelope>
 | envelope |
 envelope := (CUCreateUserWorkUnit user: CUUser new) asEnvelope.
 self should: [envelope resultCompletion: CRWorkUnitResultCompletion new] raise: Error.
 self assert: envelope resultCompletion isNil.
 ^ envelope
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
 worker services installServiceClass: CUUsersService serviceIdentifier: 'users' configuration: (CRServiceConfiguration default authoritative: true; yourself).
 worker services installServiceClass: CUUsersService serviceIdentifier: 'otherUsers' configuration: (CRServiceConfiguration default authoritative: true; yourself).
 worker start. worker workerHandle lifecycleStatus: CRStatus running.
 worker services startAll. worker publishHandleToTopology.
 [result := block value: worker] ensure: [
  [worker isWorkQueueEmpty] whileFalse: [worker executeWorkUnitInEnvelope: worker workerHandle workQueue nextForExecutionOrNil].
  worker stopAndUninstallServices. worker unpublishHandleFromTopology].
 ^ result
]
