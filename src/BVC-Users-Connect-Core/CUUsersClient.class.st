"
Local Users client API. Configured Connect establishes the endpoint once; createUser: accepts a client-created CUUser and returns the framework future.
"
Class {
	#name : 'CUUsersClient',
	#superclass : 'Object',
	#instVars : [
		'endpoint'
	],
	#category : 'BVC-Users-Connect-Core',
	#package : 'BVC-Users-Connect-Core'
}

{ #category : 'instance creation' }
CUUsersClient class >> usingConnectService: service [
 ^ self new endpoint: service objectEndpoint
]

{ #category : 'users api' }
CUUsersClient >> createUser: aUser [
 ^ endpoint call: aUser
]

{ #category : 'configuration' }
CUUsersClient >> endpoint: configuredEndpoint [
 endpoint ifNotNil: [self error: 'Users client endpoint is already configured.'].
 endpoint := configuredEndpoint. ^ self
]

{ #category : 'testing' }
CUUsersClient >> isReady [
 ^ endpoint isReady
]
