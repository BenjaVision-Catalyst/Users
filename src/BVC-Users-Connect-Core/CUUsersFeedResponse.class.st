"
Persistent session-scoped User publisher registered only after Runtime finalization. Setup completes once; committed coalesced states are encoded by the installed Magritte schema and sent by the existing Connect owner. Native Busy retains application state; disconnect, revocation or stale Runtime scope closes the publisher.
"
Class {
	#name : 'CUUsersFeedResponse',
	#superclass : 'CCObjectDeferredResponse',
	#instVars : [
		'feed',
		'schema',
		'ticket',
		'publicationCache'
	],
	#category : 'BVC-Users-Connect-Core',
	#package : 'BVC-Users-Connect-Core'
}

{ #category : 'push updates' }
CUUsersFeedResponse >> attach: source schema: codec [
 ^ self attach: source schema: codec cache: (CCObjectPublicationCache new schema: codec capacity: 128)
]

{ #category : 'push updates' }
CUUsersFeedResponse >> attach: source schema: codec cache: cache [
 feed := source. schema := codec. publicationCache := cache. ticket := feed beginPush.
 self complete: (schema encode: (CULiveUserState outcome: 'subscribed')) status: 0
]

{ #category : 'push updates' }
CUUsersFeedResponse >> cancel [
 self close. super cancel
]

{ #category : 'push updates' }
CUUsersFeedResponse >> close [
 feed ifNotNil: [feed close]. self releaseFeed
]

{ #category : 'push updates' }
CUUsersFeedResponse >> isActive [
 ^ feed notNil and: [feed isActive and: [scope notNil and: [scope isActive]]]
]

{ #category : 'push updates' }
CUUsersFeedResponse >> isPushRegistration [
 ^ feed notNil and: [ticket notNil]
]

{ #category : 'push updates' }
CUUsersFeedResponse >> isReady [
 ^ super isReady
]

{ #category : 'push updates' }
CUUsersFeedResponse >> nextPublication [
 | incoming |
 self isActive ifFalse: [^ nil].
 incoming := feed peekFor: ticket.
 ^ incoming ifNil: [nil] ifNotNil: [publicationCache publicationFor: incoming identity: incoming userIdentifier revision: incoming revision epoch: scope epoch]
]

{ #category : 'push updates' }
CUUsersFeedResponse >> published: publication [
 feed ifNotNil: [feed acknowledge: publication identifier revision: publication revision]
]

{ #category : 'push updates' }
CUUsersFeedResponse >> releaseFeed [
 feed ifNotNil: [feed endPush: ticket]. feed := nil. schema := nil. ticket := nil. publicationCache := nil
]
