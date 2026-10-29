"
Authoritative Users Runtime service. Creation and exact-name lookup delegate to CUUsers through the existing named capability and transaction boundaries. Transport trust does not authenticate an account or establish tenant ownership.
"
Class {
	#name : 'CUUsersService',
	#superclass : 'CRWorkerService',
	#instVars : [
		'feeds',
		'pendingChanges',
		'flushQueued',
		'feedPort'
	],
	#category : 'BVC-Users-Runtime',
	#package : 'BVC-Users-Runtime'
}

{ #category : 'push updates' }
CUUsersService class >> configurationClass [
 ^ CUUsersConfiguration
]

{ #category : 'push updates' }
CUUsersService class >> requiredCapabilities [
 ^ {CRServiceActivationCapability}
]

{ #category : 'push updates' }
CUUsersService >> createUser: aUser [
 (self isCurrentResultEpoch: self resultEpoch) ifFalse: [CRCapabilityDeniedException signal: 'Users service is not active.'].
 (self configuration notNil and: [self configuration isAuthoritative]) ifFalse: [CRCapabilityDeniedException signal: 'Users service is not authoritative.'].
 ^ CUUsers createUser: aUser
]

{ #category : 'push updates' }
CUUsersService >> drainChanges [
 | identifiers states |
 identifiers := pendingChanges asArray. pendingChanges := Set new. flushQueued := false.
 states := OrderedCollection new.
 identifiers do: [:userId | | user |
  user := CUUsers allUsers detect: [:each | each userIdentifier = userId] ifNone: [nil].
  user ifNotNil: [states add: (CULiveUserState from: user outcome: 'current')]].
 ^ states asArray
]

{ #category : 'push updates' }
CUUsersService >> feedFor: change principal: principal create: create [
 | key current expired now |
 now := CRPlatform current currentMillis.
 expired := feeds keys select: [:each | (feeds at: each) isActive not or: [(feeds at: each) hasPublisher not and: [now - (feeds at: each) lastUsed > self feedPolicy feedLeaseMillis]]].
 expired do: [:each | (feeds removeKey: each) close].
 key := {principal copy. change operationIdentifier copy}.
 current := feeds at: key ifAbsent: [nil].
 (current isNil and: [create]) ifTrue: [
  feeds size >= self feedPolicy maximumFeeds ifTrue: [self error: 'Users feed capacity.'].
  current := CUUsersChangeFeed new configure: self feedPolicy; yourself. feeds at: key put: current].
 ^ current
]

{ #category : 'push updates' }
CUUsersService >> feedPolicy [
 ^ (configuration isKindOf: CUUsersConfiguration) ifTrue: [configuration] ifFalse: [CUUsersConfiguration default]
]

{ #category : 'users api' }
CUUsersService >> getUser: exactName [
 (self isCurrentResultEpoch: self resultEpoch) ifFalse: [CRCapabilityDeniedException signal: 'Users service is not active.'].
 (self configuration notNil and: [self configuration isAuthoritative]) ifFalse: [CRCapabilityDeniedException signal: 'Users service is not authoritative.'].
 ^ CUUsers getUser: exactName
]

{ #category : 'push updates' }
CUUsersService >> liveUser: change operation: code principal: principal [
 | result feed |
 (self isCurrentResultEpoch: self resultEpoch) ifFalse: [CRCapabilityDeniedException signal: 'Users service is not active.'].
 (self configuration notNil and: [self configuration isAuthoritative]) ifFalse: [CRCapabilityDeniedException signal: 'Users service is not authoritative.'].
 (#(7 8 9) includes: code) ifTrue: [
  ((principal isString and: [principal notEmpty]) and: [change operationIdentifier size between: 1 and: 128]) ifFalse: [^ CULiveUserState outcome: 'refused'].
  code = 7 ifTrue: [
   result := CUUsers liveUser: change operation: 4 principal: principal.
   result outcome = 'current' ifFalse: [^ result].
   feed := self feedFor: change principal: principal create: true.
   feed register: result userIdentifier revision: (change expectedRevision min: result revision). feed publish: result. ^ result].
  feed := self feedFor: change principal: principal create: false.
  feed ifNil: [^ CULiveUserState outcome: 'closed'].
  code = 9 ifTrue: [feed unregister: change userIdentifier. ^ CULiveUserState outcome: 'unwatched'].
  feed acknowledge: change userIdentifier revision: change expectedRevision. ^ feed].
 result := CUUsers liveUser: change operation: code principal: principal.
 ((#('created' 'updated') includes: result outcome) and: [#(3 5) includes: code]) ifTrue: [self stageUser: result userIdentifier].
 ^ result
]

{ #category : 'push updates' }
CUUsersService >> publishChanges: states epoch: stamp [
 (self isCurrentResultEpoch: stamp) ifFalse: [^ self].
 states do: [:state | feeds valuesDo: [:feed | feed publish: state]]
]

{ #category : 'push updates' }
CUUsersService >> stageUser: userId [
 | envelope observation |
 (feeds values anySatisfy: [:feed | feed watches: userId]) ifFalse: [^ self].
 pendingChanges add: userId.
 flushQueued ifTrue: [^ self].
 envelope := CUUsersFlushWork new asEnvelope.
 envelope serviceIdentifier: feedPort serviceIdentifier.
 envelope resultCompletion: (CUUsersFlushCompletion new service: self epoch: self resultEpoch).
 observation := feedPort submitRouted: envelope admittedBy: nil releasedBy: nil.
 (observation isNil or: [observation admission = #refused]) ifTrue: [
  feeds valuesDo: #close. self error: 'Users change publication could not be queued.'].
 flushQueued := true
]

{ #category : 'push updates' }
CUUsersService >> start [
 super start. feeds := Dictionary new. pendingChanges := Set new. flushQueued := false.
 feedPort := self capability: CRServiceActivationCapability. feedPort activateRecords: 2 bytes: 262144.
 self provideCapability: CUUsersCapability instance: (CUUsersCapability service: self). ^ self
]

{ #category : 'push updates' }
CUUsersService >> stop [
 feeds ifNotNil: [feeds valuesDo: #close. feeds removeAll].
 feedPort ifNotNil: [feedPort deactivate]. pendingChanges := nil. flushQueued := false. ^ super stop
]
