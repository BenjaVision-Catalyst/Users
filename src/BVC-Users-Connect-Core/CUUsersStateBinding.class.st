"
Installed state-profile Users binding. Explicitly permits volatile GT finalization while retaining the native GemStone post-commit requirement.
"
Class {
	#name : 'CUUsersStateBinding',
	#superclass : 'CCObjectStateBinding',
	#category : 'BVC-Users-Connect-Core',
	#package : 'BVC-Users-Connect-Core'
}

{ #category : 'push updates' }
CUUsersStateBinding >> acceptsInMemoryFinalization [
 ^ true
]
