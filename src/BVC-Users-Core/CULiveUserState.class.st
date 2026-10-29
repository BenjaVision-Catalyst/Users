"
Authoritative live User state returned after Runtime commit. Reuses the User descriptions, with read-only identity/revision and server-owned flags.
"
Class {
	#name : 'CULiveUserState',
	#superclass : 'CUUser',
	#instVars : [
		'outcome'
	],
	#category : 'BVC-Users-Core',
	#package : 'BVC-Users-Core'
}

{ #category : 'live users' }
CULiveUserState class >> from: user outcome: status [
 ^ self new name: user name; isSuperUser: user isSuperUser; userIdentifier: user userIdentifier; revision: user revision; outcome: status; yourself
]

{ #category : 'live users' }
CULiveUserState class >> outcome: status [
 ^ self new name: ''; isSuperUser: false; userIdentifier: ''; revision: 0; outcome: status; yourself
]

{ #category : 'live users' }
CULiveUserState >> outcome [
 ^ outcome ifNil: ['']
]

{ #category : 'live users' }
CULiveUserState >> outcome: value [
 outcome := value
]
