"
Optional Users composition over Connect's generic described-object endpoint. Uses the existing #users service binding and the actual CUUser description; no domain codec or transport protocol.
"
Class {
	#name : 'CUUsersObjectApplication',
	#superclass : 'CCObjectApplication',
	#category : 'BVC-Users-Connect-Core',
	#package : 'BVC-Users-Connect-Core'
}

{ #category : 'configuration' }
CUUsersObjectApplication >> bindingFor: configuration [
 | target validation |
 target := configuration bindingNamed: #users.
 target ifNil: [self error: 'Configure the Users service binding.'].
 validation := CRRuntimeConfigurationValidationResult new. target validateSemanticsOn: validation.
 validation isValid ifFalse: [self error: 'Invalid Users service binding.'].
 (target isRemote and: [configuration principal ~= target runtimeIdentifier or: [configuration identifier ~= target connectServiceIdentifier]])
  ifTrue: [self error: 'Users binding must select this configured Connect peer and service.'].
 ^ CCObjectBinding new operation: 1 request: CUUser new result: CUUser new
  work: self messageWorkClass service: target serviceIdentifier peer: configuration principal
]

{ #category : 'configuration' }
CUUsersObjectApplication >> bindingsFor: configuration [
 "Keep explicitly configured creation-only applications compatible. Lookup requires operation 2."
 ^ (configuration allowedOperations includes: 2)
  ifTrue: [{self bindingFor: configuration. self lookupBindingFor: configuration}]
  ifFalse: [super bindingsFor: configuration]
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
