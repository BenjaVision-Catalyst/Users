"
Activation-local, peer-and-client-scoped feed. Coalesces the latest committed User state by identity, retains it until acknowledgment, and permits one receive ticket. Uses the Runtime lifecycle mutex; never store this in persistent Users.
"
Class {
	#name : 'CUUsersChangeFeed',
	#superclass : 'Object',
	#instVars : [
		'identities',
		'pending',
		'order',
		'ticket',
		'active',
		'lastUsed',
		'maximumUsers',
		'waitMillis',
		'mutex'
	],
	#category : 'BVC-Users-Runtime',
	#package : 'BVC-Users-Runtime'
}

{ #category : 'push updates' }
CUUsersChangeFeed >> acknowledge: identifier revision: version [
 ^ mutex critical: [
 | state |
 state := pending at: identifier ifAbsent: [nil].
 (state notNil and: [state revision <= version]) ifTrue: [pending removeKey: identifier. order remove: identifier ifAbsent: []].
 (identities includesKey: identifier) ifTrue: [identities at: identifier put: ((identities at: identifier) max: version)]
 ]
]

{ #category : 'push updates' }
CUUsersChangeFeed >> beginWait [
 ^ mutex critical: [
 (active and: [ticket isNil]) ifFalse: [self error: 'One active receive per Users feed.'].
 self touch. ticket := Object new. ^ ticket
 ]
]

{ #category : 'push updates' }
CUUsersChangeFeed >> close [
 ^ mutex critical: [
 active := false. pending removeAll. order removeAll. identities removeAll
 ]
]

{ #category : 'push updates' }
CUUsersChangeFeed >> configure: policy [
 ^ mutex critical: [
 maximumUsers := policy maximumUsersPerFeed. waitMillis := policy receiveWaitMillis
 ]
]

{ #category : 'push updates' }
CUUsersChangeFeed >> endWait: stamp [
 ^ mutex critical: [
 ticket == stamp ifTrue: [ticket := nil. self touch]
 ]
]

{ #category : 'push updates' }
CUUsersChangeFeed >> initialize [
 super initialize. mutex := CRPlatform current newRuntimeLifecycleMutex. identities := Dictionary new. pending := Dictionary new. order := OrderedCollection new. active := true. self touch
]

{ #category : 'push updates' }
CUUsersChangeFeed >> lastUsed [
 ^ mutex critical: [
 ^ lastUsed
 ]
]

{ #category : 'push updates' }
CUUsersChangeFeed >> peekFor: stamp [
 ^ mutex critical: [
 ticket == stamp ifFalse: [^ CULiveUserState outcome: 'refused'].
 active ifFalse: [^ CULiveUserState outcome: 'closed'].
 ^ order ifEmpty: [nil] ifNotEmpty: [pending at: order first]
 ]
]

{ #category : 'push updates' }
CUUsersChangeFeed >> publish: state [
 ^ mutex critical: [
 | identifier |
 identifier := state userIdentifier.
 (self watches: identifier) ifFalse: [^ self].
 state revision <= (identities at: identifier) ifTrue: [^ self].
 (pending includesKey: identifier) ifFalse: [order add: identifier].
 pending at: identifier put: state
 ]
]

{ #category : 'push updates' }
CUUsersChangeFeed >> register: identifier revision: version [
 ^ mutex critical: [
 active ifFalse: [self error: 'Closed Users feed.'].
 ((identities includesKey: identifier) not and: [identities size >= maximumUsers]) ifTrue: [self error: 'Users feed capacity.'].
 identities at: identifier put: version. self acknowledge: identifier revision: version. self touch
 ]
]

{ #category : 'push updates' }
CUUsersChangeFeed >> touch [
 ^ mutex critical: [
 lastUsed := CRPlatform current currentMillis
 ]
]

{ #category : 'push updates' }
CUUsersChangeFeed >> unregister: identifier [
 ^ mutex critical: [
 identities removeKey: identifier ifAbsent: []. pending removeKey: identifier ifAbsent: []. order remove: identifier ifAbsent: []. self touch
 ]
]

{ #category : 'push updates' }
CUUsersChangeFeed >> waitMillis [
 ^ mutex critical: [
 ^ waitMillis
 ]
]

{ #category : 'push updates' }
CUUsersChangeFeed >> watches: identifier [
 ^ mutex critical: [
 ^ active and: [identities includesKey: identifier]
 ]
]
