"
A server-held change receive using Connect's original deferred reply and owner. Encodes a coalesced state or lease heartbeat, releases its receive ticket, and fences stale service scopes. No socket, worker, event history or native frame extension.
"
Class {
	#name : 'CUUsersFeedResponse',
	#superclass : 'CCObjectDeferredResponse',
	#instVars : [
		'feed',
		'schema',
		'ticket',
		'deadline'
	],
	#category : 'BVC-Users-Connect-Core',
	#package : 'BVC-Users-Connect-Core'
}

{ #category : 'push updates' }
CUUsersFeedResponse >> attach: source schema: codec [
 feed := source. schema := codec. ticket := feed beginWait. deadline := CRPlatform current currentMillis + feed waitMillis
]

{ #category : 'push updates' }
CUUsersFeedResponse >> cancel [
 self releaseFeed. super cancel
]

{ #category : 'push updates' }
CUUsersFeedResponse >> isReady [
 | incomingState |
 super isReady ifTrue: [^ true].
 feed ifNil: [^ false].
 (scope notNil and: [scope isActive not]) ifTrue: [self complete: #[] status: 409. self releaseFeed. ^ true].
 incomingState := feed peekFor: ticket.
 (incomingState isNil and: [CRPlatform current currentMillis >= deadline]) ifTrue: [incomingState := CULiveUserState outcome: 'renew'].
 incomingState ifNil: [^ false].
 [[self complete: (schema encode: incomingState) status: 0] on: Error do: [:error | self complete: #[] status: 500]]
  ensure: [self releaseFeed].
 ^ true
]

{ #category : 'push updates' }
CUUsersFeedResponse >> releaseFeed [
 feed ifNotNil: [feed endWait: ticket]. feed := nil. schema := nil. ticket := nil
]
