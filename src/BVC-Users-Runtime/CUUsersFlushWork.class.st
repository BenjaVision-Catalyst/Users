"
Coalesced follow-up on the existing configured Users route. Rereads staged identities after the mutating delivery; a rollback therefore exposes only the prior committed state. Publication belongs to its Runtime result completion.
"
Class {
	#name : 'CUUsersFlushWork',
	#superclass : 'CUUsersWorkUnit',
	#category : 'BVC-Users-Runtime',
	#package : 'BVC-Users-Runtime'
}

{ #category : 'push updates' }
CUUsersFlushWork class >> allowsConflictReplay [
 ^ false
]

{ #category : 'push updates' }
CUUsersFlushWork class >> requiresTransaction [
 ^ true
]

{ #category : 'push updates' }
CUUsersFlushWork >> executeInContext: context [
 ^ (context capability: CUUsersCapability) drainChanges
]
