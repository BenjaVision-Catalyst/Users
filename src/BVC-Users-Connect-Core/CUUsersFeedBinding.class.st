"
Composes an installed Users change feed with the existing deferred-response hooks. The locally installed result type is never selected by peer bytes.
"
Class {
	#name : 'CUUsersFeedBinding',
	#superclass : 'CUUsersStateBinding',
	#category : 'BVC-Users-Connect-Core',
	#package : 'BVC-Users-Connect-Core'
}

{ #category : 'push updates' }
CUUsersFeedBinding >> completeResult: result response: response probe: probe [
 (probe not and: [result class == CUUsersChangeFeed]) ifTrue: [^ response attach: result schema: self resultSchema].
 ^ super completeResult: result response: response probe: probe
]

{ #category : 'push updates' }
CUUsersFeedBinding >> newResponse [
 ^ CUUsersFeedResponse new
]

{ #category : 'push updates' }
CUUsersFeedBinding >> supportsSubscription [
 ^ true
]
