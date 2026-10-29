"
Optional Users composition over Connect's generic described-object endpoint. Uses the existing #users service binding and the actual CUUser description; no domain codec or transport protocol.
"
Class {
	#name : 'CUUsersObjectApplication',
	#superclass : 'CCObjectApplication',
	#category : 'BVC-Users-Connect-Core',
	#package : 'BVC-Users-Connect-Core'
}

{ #category : 'push updates' }
CUUsersObjectApplication >> bindingClass [
 ^ CUUsersBinding
]

{ #category : 'push updates' }
CUUsersObjectApplication >> bindingFor: configuration [
 | target validation |
 target := configuration bindingNamed: #users.
 target ifNil: [self error: 'Configure the Users service binding.'].
 validation := CRRuntimeConfigurationValidationResult new. target validateSemanticsOn: validation.
 validation isValid ifFalse: [self error: 'Invalid Users service binding.'].
 (target isRemote and: [configuration principal ~= target runtimeIdentifier or: [configuration identifier ~= target connectServiceIdentifier]])
  ifTrue: [self error: 'Users binding must select this configured Connect peer and service.'].
 ^ self bindingClass new operation: 1 request: CUUser new result: CUUser new
  work: self messageWorkClass service: target serviceIdentifier peer: configuration principal
]

{ #category : 'push updates' }
CUUsersObjectApplication >> bindingsFor: configuration [
 | result creation |
 creation := self bindingFor: configuration. result := OrderedCollection with: creation.
 (configuration allowedOperations includes: 2) ifTrue: [result add: (self lookupBindingFor: configuration)].
 self liveWorkClasses do: [:work |
  (configuration allowedOperations includes: work operation) ifTrue: [result add: (CUUsersStateBinding new operation: work operation request: CUUserChange new result: (CULiveUserState outcome: '') work: work service: (configuration bindingNamed: #users) serviceIdentifier peer: creation localIdentity)]].
 #(7 8 9) do: [:code | (configuration allowedOperations includes: code) ifTrue: [
  result add: ((code = 8 ifTrue: [CUUsersFeedBinding] ifFalse: [CUUsersStateBinding]) new operation: code request: CUUserChange new result: (CULiveUserState outcome: '')
   work: ({CUSubscribeUserWork. CUReceiveUserChangesWork. CUUnsubscribeUserWork} at: code - 6) service: (configuration bindingNamed: #users) serviceIdentifier peer: creation localIdentity)]].
 result do: [:each | each supportsSubscription ifTrue: [each publicationCacheCapacity: configuration publicationCacheCapacity]].
 ^ result asArray
]

{ #category : 'live users' }
CUUsersObjectApplication >> liveWorkClasses [
 ^ {CUCreateLiveUserWork. CUReadLiveUserWork. CUUpdateLiveUserWork. CURecoverLiveUserWork}
]

{ #category : 'configuration' }
CUUsersObjectApplication >> lookupBindingFor: configuration [
 | creation |
 creation := self bindingFor: configuration.
 ^ CUGetUserBinding new operation: 2 request: CUUserLookup new result: CUUser new
  work: CUGetUserMessageWork service: (configuration bindingNamed: #users) serviceIdentifier peer: creation localIdentity
]

{ #category : 'configuration' }
CUUsersObjectApplication >> messageWorkClass [
 ^ CUCreateUserMessageWork
]
