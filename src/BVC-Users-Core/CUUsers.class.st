"
Single entry point for the Catalyst Users API. On first access, AllUsers holds a shared temporary collection with admin (the super user) and unknownUser. It remains intact on subsequent access and reloads until tenant-owned storage replaces it. GemStone callers own repository transactions.
"
Class {
	#name : 'CUUsers',
	#superclass : 'Object',
	#classVars : [
		'AllUsers'
	],
	#category : 'BVC-Users-Core',
	#package : 'BVC-Users-Core'
}

{ #category : 'adding' }
CUUsers class >> addUser: aUser [
 ^ self allUsers add: aUser
]

{ #category : 'accessing' }
CUUsers class >> admin [
 ^ self allUsers detect: [:user | user name = 'admin']
]

{ #category : 'accessing' }
CUUsers class >> allUsers [
 "Create the temporary store and its two defaults only on first access."
 ^ AllUsers ifNil: [AllUsers := self newAllUsers]
]

{ #category : 'creating' }
CUUsers class >> createUser: aUser [
 (aUser isKindOf: CUUser) ifFalse: [CUUserCreationError signal: 'A CUUser is required.'].
 aUser isSuperUser ifTrue: [CUUserCreationError signal: 'Creating super users is not supported.'].
 (self allUsers identityIncludes: aUser) ifTrue: [CUUserCreationError signal: 'The user is already stored.'].
 ^ self addUser: aUser
]

{ #category : 'users api' }
CUUsers class >> getUser: exactName [
 | matches |
 exactName isString ifFalse: [self error: 'User name must be text.'].
 matches := self allUsers select: [:user | user name = exactName].
 matches size > 1 ifTrue: [CUAmbiguousUserError signal: 'More than one user has this exact name.'].
 ^ matches ifEmpty: [nil] ifNotEmpty: [matches first]
]

{ #category : 'live users' }
CUUsers class >> liveUser: change operation: code principal: principal [
 | user key |
 (change isKindOf: CUUserChange) ifFalse: [self error: 'Live User command required.'].
 (#(3 4 5 6) includes: code) ifFalse: [self error: 'Uninstalled live User operation.'].
 key := change operationIdentifier.
 ((principal isString and: [principal notEmpty]) and: [key isString and: [key size between: 1 and: 128]]) ifFalse: [^ CULiveUserState outcome: 'refused'].
 code = 3 ifTrue: [
  user := self allUsers detect: [:each | each creationIdentifier = key and: [each creationPrincipal = principal]] ifNone: [nil].
  user ifNotNil: [^ user creationName = change name ifTrue: [CULiveUserState from: user outcome: 'created'] ifFalse: [CULiveUserState outcome: 'refused']].
  user := self createUser: (CUUser new name: change name; yourself).
  user ensureIdentity; creationIdentifier: key principal: principal name: change name.
  ^ CULiveUserState from: user outcome: 'created'].
 code = 6 ifTrue: [
  user := self allUsers detect: [:each | each creationIdentifier = key and: [each creationPrincipal = principal]] ifNone: [nil].
  ^ user ifNil: [CULiveUserState outcome: 'unknown'] ifNotNil: [CULiveUserState from: user outcome: 'created']].
 user := change userIdentifier isEmpty
  ifTrue: [code = 4 ifTrue: [[self getUser: change name] on: CUAmbiguousUserError do: [:error | ^ CULiveUserState outcome: 'refused']] ifFalse: [nil]]
  ifFalse: [self allUsers detect: [:each | each userIdentifier = change userIdentifier] ifNone: [nil]].
 user ifNil: [^ CULiveUserState outcome: 'notFound'].
 user ensureIdentity.
 code = 4 ifTrue: [^ CULiveUserState from: user outcome: 'current'].
 user creationPrincipal = principal ifFalse: [^ CULiveUserState outcome: 'refused'].
 user revision = change expectedRevision ifFalse: [^ CULiveUserState from: user outcome: 'conflict'].
 user name: change name.
 ^ CULiveUserState from: user outcome: 'updated'
]

{ #category : 'private' }
CUUsers class >> newAllUsers [
 ^ OrderedCollection
  with: (CUUser new name: 'admin'; isSuperUser: true; yourself)
  with: (CUUser new name: 'unknownUser'; isSuperUser: false; yourself)
]

{ #category : 'accessing' }
CUUsers class >> unknownUser [
 ^ self allUsers detect: [:user | user name = 'unknownUser']
]
