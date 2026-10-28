"
Users Runtime service foundation. Runtime owns lifecycle, service placement and capability resolution. This initial project setup does not implement account storage, registration or authentication.
"
Class {
	#name : 'CUUsersService',
	#superclass : 'CRWorkerService',
	#category : 'BVC-Users-Runtime',
	#package : 'BVC-Users-Runtime'
}

{ #category : 'lifecycle' }
CUUsersService >> start [
super start.
 self provideCapability: CUUsersCapability instance: (CUUsersCapability service: self).
 ^ self
]
