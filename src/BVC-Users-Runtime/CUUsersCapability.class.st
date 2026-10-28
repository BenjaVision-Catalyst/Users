"
Narrow Users service capability. Only installed Users WorkUnit subclasses may receive it. Domain operations will be added with their authority and persistence contracts.
"
Class {
	#name : 'CUUsersCapability',
	#superclass : 'CRServiceBoundCapability',
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
