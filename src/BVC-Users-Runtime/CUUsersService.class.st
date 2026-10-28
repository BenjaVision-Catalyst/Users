"
Users Runtime service. createUser: delegates to the shared CUUsers data API. Runtime owns named placement, capability binding and transaction boundaries. Creating users does not authenticate a caller or establish tenant ownership.
"
Class {
	#name : 'CUUsersService',
	#superclass : 'CRWorkerService',
	#category : 'BVC-Users-Runtime',
	#package : 'BVC-Users-Runtime'
}

{ #category : 'users api' }
CUUsersService >> createUser: aUser [
 (self isCurrentResultEpoch: self resultEpoch) ifFalse: [CRCapabilityDeniedException signal: 'Users service is not active.'].
 (self configuration notNil and: [self configuration isAuthoritative]) ifFalse: [
  CRCapabilityDeniedException signal: 'Users service is not authoritative.'].
 ^ CUUsers createUser: aUser
]

{ #category : 'lifecycle' }
CUUsersService >> start [
super start.
 self provideCapability: CUUsersCapability instance: (CUUsersCapability service: self).
 ^ self
]
