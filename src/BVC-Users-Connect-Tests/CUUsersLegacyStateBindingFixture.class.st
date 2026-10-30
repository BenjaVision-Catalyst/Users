Class {
	#name : 'CUUsersLegacyStateBindingFixture',
	#superclass : 'CUUsersStateBinding',
	#category : 'BVC-Users-Connect-Tests',
	#package : 'BVC-Users-Connect-Tests'
}

{ #category : 'tests - publication' }
CUUsersLegacyStateBindingFixture >> resultCompletionFor: response probe: isProbe [
 ^ CCObjectResultCompletion new binding: self response: response probe: isProbe
]
