"
Activation-local, peer-and-client-scoped latest-state feed. Coalesces finalized User state by identity and retains it until native publication accepts a byte copy. One persistent publisher owns the feed. Uses the existing Runtime lifecycle mutex; never store this in persistent Users.
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
CUUsersChangeFeed >> beginPush [
 ^ mutex critical: [
 (active and: [ticket isNil]) ifFalse: [self error: 'One active publisher per Users feed.'].
 self touch. ticket := Object new. ticket]
]

{ #category : 'push updates' }
CUUsersChangeFeed >> close [
 ^ mutex critical: [active := false. ticket := nil. pending := Dictionary new. order := OrderedCollection new. identities := Dictionary new]
]

{ #category : 'push updates' }
CUUsersChangeFeed >> configure: policy [
 ^ mutex critical: [maximumUsers := policy maximumUsersPerFeed]
]

{ #category : 'push updates' }
CUUsersChangeFeed >> endPush: stamp [
 ^ mutex critical: [ticket == stamp ifTrue: [ticket := nil. self touch]]
]

{ #category : 'push updates' }
CUUsersChangeFeed >> hasPublisher [
 ^ mutex critical: [ticket notNil]
]

{ #category : 'push updates' }
CUUsersChangeFeed >> initialize [
 super initialize. mutex := CRPlatform current newRuntimeLifecycleMutex. identities := Dictionary new. pending := Dictionary new. order := OrderedCollection new. active := true. self touch
]

{ #category : 'push updates' }
CUUsersChangeFeed >> isActive [
 ^ mutex critical: [active]
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
 active ifFalse: [^ CULiveUserState outcome: 'closed'].
 ticket == stamp ifFalse: [^ CULiveUserState outcome: 'refused'].
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
CUUsersChangeFeed >> watches: identifier [
 ^ mutex critical: [
 ^ active and: [identities includesKey: identifier]
 ]
]
