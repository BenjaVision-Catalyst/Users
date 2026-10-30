Class {
	#name : 'CUUsersPublicationExamples',
	#superclass : 'TestCase',
	#category : 'BVC-Users-Connect-Tests',
	#package : 'BVC-Users-Connect-Tests'
}

{ #category : 'tests - publication' }
CUUsersPublicationExamples >> routeFixture: fixture [
 | binding response envelope |
 binding := fixture at: #binding.
 response := binding routeBytes: (binding requestSchema encode: (fixture at: #input)) principal: 'peer' probe: false using: (fixture at: #port).
 envelope := (fixture at: #target) workerHandle workQueue nextForExecutionOrNil.
 fixture at: #response put: response; at: #envelope put: envelope; at: #completion put: envelope resultCompletion.
 ^ envelope
]

{ #category : 'tests - publication' }
CUUsersPublicationExamples >> testConflictedOutcomeHasNoPublication [
 <gtExample>
 <return: #CCObjectDeferredResponse>
 ^ self withFixtureDo: [:f | | envelope feed ticket state |
 (f at: #input) expectedRevision: 0.
 envelope := self routeFixture: f. feed := f at: #feed. ticket := feed beginPush.
 (f at: #target) executeWorkUnitInEnvelope: envelope.
 self assert: (feed peekFor: ticket) isNil. self assert: (f at: #target) isWorkQueueEmpty.
 state := (f at: #binding) resultSchema decode: (f at: #response) response first.
 self assert: state outcome equals: 'conflict'. self assert: state revision equals: 1. f at: #response]
]

{ #category : 'tests - publication' }
CUUsersPublicationExamples >> testDirectCompletionDoesNotDrainFallbackIdentities [
 <gtExample>
 <return: #CUUsersChangeFeed>
 ^ self withFixtureDo: [:f | | envelope fallback pending |
 (f at: #users) stageUser: (f at: #input) userIdentifier.
 fallback := (f at: #target) workerHandle workQueue nextForExecutionOrNil.
 envelope := self routeFixture: f.
 (f at: #target) executeWorkUnitInEnvelope: envelope.
 pending := (f at: #users) instVarNamed: 'pendingChanges'.
 self assert: (pending includes: (f at: #input) userIdentifier).
 self assert: ((f at: #users) instVarNamed: 'flushQueued').
 (f at: #target) executeWorkUnitInEnvelope: fallback.
 self assert: ((f at: #users) instVarNamed: 'pendingChanges') isEmpty.
 f at: #feed]
]

{ #category : 'tests - publication' }
CUUsersPublicationExamples >> testFailedMutationNeverPublishesOrQueuesReread [
 <gtExample>
 <return: #CCObjectDeferredResponse>
 ^ self withFixtureDo: [:f | | envelope feed ticket |
 envelope := self routeFixture: f. feed := f at: #feed. ticket := feed beginPush.
 envelope workUnit afterBody: [:result :context | self error: 'Publication test failure after mutation'].
 (f at: #target) executeWorkUnitInEnvelope: envelope.
 self assert: (feed peekFor: ticket) isNil. self assert: (f at: #target) isWorkQueueEmpty.
 self assert: (f at: #completion) state equals: #abandoned.
 self assert: (f at: #response) response second equals: 500.
 self assert: (f at: #binding) pool usedRecords equals: 0. f at: #response]
]

{ #category : 'tests - publication' }
CUUsersPublicationExamples >> testFallbackRetainsTheTransactionalReread [
 <gtExample>
 <return: #CUUsersChangeFeed>
 ^ self withFixtureDo: [:f | | binding envelope feed ticket |
 binding := CUUsersLegacyStateBindingFixture new operation: 5 request: CUUserChange new result: (CULiveUserState outcome: '') work: CUUsersPublicationTestWork service: 'users' peer: 'peer'.
 f at: #binding put: binding. envelope := self routeFixture: f. feed := f at: #feed. ticket := feed beginPush.
 (f at: #target) executeWorkUnitInEnvelope: envelope.
 self assert: (f at: #response) isReady. self assert: (feed peekFor: ticket) isNil.
 self deny: (f at: #target) isWorkQueueEmpty.
 envelope := (f at: #target) workerHandle workQueue nextForExecutionOrNil.
 self assert: envelope workUnit class == CUUsersFlushWork.
 (f at: #target) executeWorkUnitInEnvelope: envelope.
 self assert: (feed peekFor: ticket) revision equals: 2. feed]
]

{ #category : 'tests - publication' }
CUUsersPublicationExamples >> testFinalizationFailureCannotPublish [
 <gtExample>
 <return: #CUUsersChangeFeed>
 ^ self withFixtureDo: [:f | | envelope ticket |
 envelope := self routeFixture: f. ticket := (f at: #feed) beginPush.
 (f at: #target) failAt: #metrics.
 self should: [(f at: #target) executeWorkUnitInEnvelope: envelope] raise: Error.
 self assert: ((f at: #feed) peekFor: ticket) isNil.
 self assert: (f at: #completion) state equals: #abandoned.
 self assert: (f at: #binding) pool usedRecords equals: 0. f at: #feed]
]

{ #category : 'tests - publication' }
CUUsersPublicationExamples >> testForeignAndEarlyCallbacksCannotPublish [
 <gtExample>
 <return: #CCObjectDeferredResponse>
 ^ self withFixtureDo: [:f | | envelope |
 envelope := self routeFixture: f.
 envelope workUnit afterBody: [:result :context |
  self should: [(f at: #completion) finishResult: result in: context onWorker: (f at: #target)] raise: Error.
  self should: [(context capability: CUUsersCapability) publishCommittedUser: result completion: CCObjectResultCompletion new in: context onWorker: (f at: #target)] raise: Error].
 (f at: #target) executeWorkUnitInEnvelope: envelope.
 self assert: (f at: #completion) state equals: #completed. self assert: (f at: #response) response second equals: 0. f at: #response]
]

{ #category : 'tests - publication' }
CUUsersPublicationExamples >> testMalformedResultClosesFeedAndDoesNotReplayMutation [
 <gtExample>
 <return: #CCObjectDeferredResponse>
 ^ self withFixtureDo: [:f | | envelope |
 envelope := self routeFixture: f.
 envelope workUnit afterBody: [:result :context | result name: (String new: 1025 withAll: $x)].
 (f at: #target) executeWorkUnitInEnvelope: envelope.
 self deny: (f at: #feed) isActive. self assert: (f at: #completion) state equals: #failed.
 self assert: (f at: #response) response second equals: 500. self assert: (f at: #target) isWorkQueueEmpty.
 self assert: (CUUsers getUser: 'Publication updated') revision equals: 2.
 self assert: (f at: #binding) pool usedRecords equals: 0. f at: #response]
]

{ #category : 'tests - publication' }
CUUsersPublicationExamples >> testProbeAndReadBindingsRetainGenericCompletion [
 <gtExample>
 <return: #CUUsersStateBinding>
 ^ self withFixtureDo: [:f | | binding |
 binding := f at: #binding.
 self assert: (binding resultCompletionFor: CCObjectDeferredResponse new probe: true) class == CCObjectResultCompletion.
 binding := CUUsersStateBinding new operation: 4 request: CUUserChange new result: (CULiveUserState outcome: '') work: CUReadLiveUserWork service: 'users' peer: 'peer'.
 self assert: (binding resultCompletionFor: CCObjectDeferredResponse new probe: false) class == CCObjectResultCompletion.
 binding]
]

{ #category : 'tests - publication' }
CUUsersPublicationExamples >> testPublicationFailureClosesFeedsWithoutReplayingMutation [
 <gtExample>
 <return: #CCObjectDeferredResponse>
 ^ self withFixtureDo: [:f | | envelope failed |
 failed := CUUsersPublicationFailingFeed new configure: CUUsersConfiguration new; yourself.
 failed register: (f at: #input) userIdentifier revision: 1.
 ((f at: #users) instVarNamed: 'feeds') at: #failed put: failed.
 envelope := self routeFixture: f. (f at: #target) executeWorkUnitInEnvelope: envelope.
 self assert: (f at: #completion) state equals: #failed.
 self deny: failed isActive. self deny: (f at: #feed) isActive.
 self assert: (CUUsers getUser: 'Publication updated') revision equals: 2.
 self assert: (f at: #target) isWorkQueueEmpty. self assert: (f at: #response) response second equals: 500.
 f at: #response]
]

{ #category : 'tests - publication' }
CUUsersPublicationExamples >> testPublicationWaitsForFinalizationAndQueuesNoReread [
 <gtExample>
 <return: #CCObjectDeferredResponse>
 ^ self withFixtureDo: [:f | | envelope response feed ticket |
 envelope := self routeFixture: f. response := f at: #response. feed := f at: #feed. ticket := feed beginPush.
 envelope workUnit afterBody: [:result :context | self deny: response isReady. self assert: (feed peekFor: ticket) isNil. self assert: (f at: #target) isWorkQueueEmpty].
 (f at: #target) executeWorkUnitInEnvelope: envelope.
 self assert: response response second equals: 0. self assert: (feed peekFor: ticket) revision equals: 2.
 self assert: (feed peekFor: ticket) outcome equals: 'current'.
 self assert: (f at: #completion) state equals: #completed. self assert: (f at: #target) isWorkQueueEmpty.
 self assert: (f at: #binding) pool usedRecords equals: 0. self assert: (f at: #port) count equals: 0.
 response]
]

{ #category : 'tests - publication' }
CUUsersPublicationExamples >> testPublishedSnapshotIsPrivateAndCompletionReleasesReferences [
 <gtExample>
 <return: #CUUsersChangeFeed>
 ^ self withFixtureDo: [:f | | envelope result ticket published completion capturedContext |
 envelope := self routeFixture: f. ticket := (f at: #feed) beginPush.
 envelope workUnit afterBody: [:value :context | result := value. capturedContext := context].
 (f at: #target) executeWorkUnitInEnvelope: envelope.
 published := (f at: #feed) peekFor: ticket.
 self deny: published == result. result name at: 1 put: $X.
 self assert: published name equals: 'Publication updated'.
 completion := f at: #completion.
 self assert: (completion instVarNamed: 'publicationCapability') isNil.
 self assert: (completion instVarNamed: 'publicationContext') isNil.
 self should: [completion finishResult: result in: capturedContext onWorker: (f at: #target)] raise: Error.
 self assert: published revision equals: 2. f at: #feed]
]

{ #category : 'tests - publication' }
CUUsersPublicationExamples >> testStoppedServiceCannotPublishAFormerEpoch [
 <gtExample>
 <return: #CUUsersChangeFeed>
 ^ self withFixtureDo: [:f | | envelope |
 envelope := self routeFixture: f.
 envelope workUnit afterBody: [:result :context | (f at: #target) services stopService: (f at: #users)].
 (f at: #target) executeWorkUnitInEnvelope: envelope.
 self deny: (f at: #feed) isActive. self assert: (f at: #response) response second equals: 500.
 self assert: (f at: #binding) pool usedRecords equals: 0. f at: #feed]
]

{ #category : 'tests - publication' }
CUUsersPublicationExamples >> withFixtureDo: block [
 | fixture origin target runtime service binding input user feed result original |
 original := CUUsers allUsers copy.
 fixture := CCQuicCompletionExamples new fixtureForBytes: 1 operation: 1 principal: 'peer'.
 CCQuicCompletionExamples new executeFixture: fixture.
 origin := fixture at: #worker. target := CUUsersPublicationTestWorker new. runtime := CRRuntime new.
 origin workerHandle workerIdentifier: #publicationOrigin. origin bindRuntime: runtime hostIdentifier: #publicationFixture. origin publishHandleToTopology.
 target workerHandle workerIdentifier: #publicationTarget. target bindRuntime: runtime hostIdentifier: #publicationFixture.
 service := target services installServiceClass: CUUsersService serviceIdentifier: 'users' configuration: (CUUsersConfiguration new authoritative: true; yourself).
 target start. target workerHandle lifecycleStatus: CRStatus running. origin workerHandle lifecycleStatus: CRStatus running. target services startAll. target publishHandleToTopology.
 input := CUUserChange new name: 'Publication original'; operationIdentifier: UUID new asString36; yourself.
 user := CUUsers liveUser: input operation: 3 principal: 'peer'.
 input userIdentifier: user userIdentifier; expectedRevision: user revision; name: 'Publication updated'.
 feed := CUUsersChangeFeed new configure: CUUsersConfiguration new; yourself. feed register: user userIdentifier revision: user revision.
 (service instVarNamed: 'feeds') at: #test put: feed.
 binding := CUUsersStateBinding new operation: 5 request: CUUserChange new result: (CULiveUserState outcome: '') work: CUUsersPublicationTestWork service: 'users' peer: 'peer'.
 fixture at: #target put: target; at: #users put: service; at: #binding put: binding; at: #input put: input; at: #feed put: feed.
 [result := block value: fixture]
 ensure: [
  target failAt: nil.
  {origin. target} do: [:worker | [worker isWorkQueueEmpty] whileFalse: [worker executeWorkUnitInEnvelope: worker workerHandle workQueue nextForExecutionOrNil]].
  (fixture at: #port) deactivate. target stopAndUninstallServices. target unpublishHandleFromTopology.
  origin stopAndUninstallServices. origin unpublishHandleFromTopology.
  CUUsers allUsers removeAllSuchThat: [:each | (original identityIncludes: each) not]].
 ^ result
]
