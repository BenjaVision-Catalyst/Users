"
Narrow Users creation and exact-name lookup capability for installed CUUsersWorkUnit subclasses. Bound to one service activation epoch; expires across stop/restart. Carries no service-control or authentication authority.
"
Class {
	#name : 'CUUsersCapability',
	#superclass : 'CRServiceBoundCapability',
	#instVars : [
		'epoch'
	],
	#category : 'BVC-Users-Runtime',
	#package : 'BVC-Users-Runtime'
}

{ #category : 'authority' }
CUUsersCapability class >> canBeGrantedToServiceClass: serviceClass [
^ false
]

{ #category : 'authority' }
CUUsersCapability class >> canBeGrantedToWorkUnitClass: workClass [
^ workClass inheritsFrom: CUUsersWorkUnit
]

{ #category : 'initialization' }
CUUsersCapability >> bindService: aService [
 super bindService: aService.
 epoch := aService resultEpoch
]

{ #category : 'users api' }
CUUsersCapability >> createUser: aUser [
 (service isCurrentResultEpoch: epoch) ifFalse: [CRCapabilityDeniedException signal: 'Users capability has expired.'].
 ^ service createUser: aUser
]

{ #category : 'users api' }
CUUsersCapability >> getUser: exactName [
 (service isCurrentResultEpoch: epoch) ifFalse: [CRCapabilityDeniedException signal: 'Users capability has expired.'].
 ^ service getUser: exactName
]
