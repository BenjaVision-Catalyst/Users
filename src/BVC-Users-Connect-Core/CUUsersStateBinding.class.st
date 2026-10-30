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

{ #category : 'result publication' }
CUUsersStateBinding >> resultCompletionFor: response probe: isProbe [
 (isProbe not and: [#(3 5) includes: self operation]) ifTrue: [
  ^ CUUsersMutationResultCompletion new binding: self response: response probe: false].
 ^ super resultCompletionFor: response probe: isProbe
]
