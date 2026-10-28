"
Fault-injection composition used only by native qualification; production Users still executes its ordinary handler.
"
Class {
	#name : 'CUUsersConnectTestApplication',
	#superclass : 'CUUsersObjectApplication',
	#category : 'BVC-Users-Connect-Tests',
	#package : 'BVC-Users-Connect-Tests'
}

{ #category : 'configuration' }
CUUsersConnectTestApplication >> messageWorkClass [
 ^ CUUsersRollbackMessageFixture
]
