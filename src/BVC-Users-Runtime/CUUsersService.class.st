"
Authoritative Users Runtime service. Creation and exact-name lookup delegate to CUUsers through the existing named capability and transaction boundaries. Transport trust does not authenticate an account or establish tenant ownership.
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

{ #category : 'users api' }
CUUsersService >> getUser: exactName [
 (self isCurrentResultEpoch: self resultEpoch) ifFalse: [CRCapabilityDeniedException signal: 'Users service is not active.'].
 (self configuration notNil and: [self configuration isAuthoritative]) ifFalse: [CRCapabilityDeniedException signal: 'Users service is not authoritative.'].
 ^ CUUsers getUser: exactName
]

{ #category : 'lifecycle' }
CUUsersService >> start [
super start.
 self provideCapability: CUUsersCapability instance: (CUUsersCapability service: self).
 ^ self
]
