Class {
	#name : 'CUUsersPublicationFailingFeed',
	#superclass : 'CUUsersChangeFeed',
	#category : 'BVC-Users-Connect-Tests',
	#package : 'BVC-Users-Connect-Tests'
}

{ #category : 'tests - publication' }
CUUsersPublicationFailingFeed >> publish: state [
 self error: 'Injected publication failure'
]
