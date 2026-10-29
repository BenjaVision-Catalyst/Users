"
Composes an installed Users change feed with the existing deferred-response hooks. The locally installed result type is never selected by peer bytes.
"
Class {
	#name : 'CUUsersFeedBinding',
	#superclass : 'CUUsersStateBinding',
	#instVars : [
		'publicationCache'
	],
	#category : 'BVC-Users-Connect-Core',
	#package : 'BVC-Users-Connect-Core'
}

{ #category : 'push updates' }
CUUsersFeedBinding >> completeResult: result response: response probe: probe [
 (probe not and: [result class == CUUsersChangeFeed]) ifTrue: [
  publicationCache ifNil: [publicationCache := CCObjectPublicationCache new schema: self resultSchema capacity: 128].
  ^ response attach: result schema: self resultSchema cache: publicationCache].
 ^ super completeResult: result response: response probe: probe
]

{ #category : 'push updates' }
CUUsersFeedBinding >> newResponse [
 ^ CUUsersFeedResponse new
]

{ #category : 'push updates' }
CUUsersFeedBinding >> publicationCacheCapacity: limit [
 publicationCache ifNotNil: [self error: 'Immutable publication view'].
 publicationCache := CCObjectPublicationCache new schema: self resultSchema capacity: limit
]

{ #category : 'push updates' }
CUUsersFeedBinding >> publicationStatistics [
 ^ publicationCache ifNil: [Dictionary new at: #encodings put: 0; at: #entries put: 0; at: #capacity put: 128; yourself] ifNotNil: [publicationCache statistics]
]

{ #category : 'push updates' }
CUUsersFeedBinding >> supportsSubscription [
 ^ true
]
