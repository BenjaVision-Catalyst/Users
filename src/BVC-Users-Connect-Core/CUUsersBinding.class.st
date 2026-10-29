"
Snapshot Users binding with explicit volatile GT finalization; native GemStone completion still requires confirmed commit.
"
Class {
	#name : 'CUUsersBinding',
	#superclass : 'CCObjectBinding',
	#category : 'BVC-Users-Connect-Core',
	#package : 'BVC-Users-Connect-Core'
}

{ #category : 'push updates' }
CUUsersBinding >> acceptsInMemoryFinalization [
 ^ true
]
