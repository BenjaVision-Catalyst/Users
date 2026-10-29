"
Bounded activation-local Users change-feed policy. Existing Runtime effective copies, validation and reconciliation apply changes; existing plain Users configurations retain these defaults.
"
Class {
	#name : 'CUUsersConfiguration',
	#superclass : 'CRServiceConfiguration',
	#instVars : [
		'maximumFeeds',
		'maximumUsersPerFeed',
		'receiveWaitMillis',
		'feedLeaseMillis'
	],
	#category : 'BVC-Users-Runtime',
	#package : 'BVC-Users-Runtime'
}

{ #category : 'push updates' }
CUUsersConfiguration >> descriptionFeedLeaseMillis [
 <magritteDescription>
 ^ MANumberDescription new accessor: #feedLeaseMillis; label: 'FeedLeaseMillis'; kind: Integer; min: 1; beRequired; yourself
]

{ #category : 'push updates' }
CUUsersConfiguration >> descriptionMaximumFeeds [
 <magritteDescription>
 ^ MANumberDescription new accessor: #maximumFeeds; label: 'MaximumFeeds'; kind: Integer; min: 1; beRequired; yourself
]

{ #category : 'push updates' }
CUUsersConfiguration >> descriptionMaximumUsersPerFeed [
 <magritteDescription>
 ^ MANumberDescription new accessor: #maximumUsersPerFeed; label: 'MaximumUsersPerFeed'; kind: Integer; min: 1; beRequired; yourself
]

{ #category : 'push updates' }
CUUsersConfiguration >> descriptionReceiveWaitMillis [
 <magritteDescription>
 ^ MANumberDescription new accessor: #receiveWaitMillis; label: 'ReceiveWaitMillis'; kind: Integer; min: 1; beRequired; yourself
]

{ #category : 'push updates' }
CUUsersConfiguration >> feedLeaseMillis [
 ^ feedLeaseMillis
]

{ #category : 'push updates' }
CUUsersConfiguration >> feedLeaseMillis: value [
 feedLeaseMillis := value
]

{ #category : 'push updates' }
CUUsersConfiguration >> initialize [
 super initialize. serviceClass := CUUsersService. maximumFeeds := 16. maximumUsersPerFeed := 256. receiveWaitMillis := 15000. feedLeaseMillis := 60000
]

{ #category : 'push updates' }
CUUsersConfiguration >> maximumFeeds [
 ^ maximumFeeds
]

{ #category : 'push updates' }
CUUsersConfiguration >> maximumFeeds: value [
 maximumFeeds := value
]

{ #category : 'push updates' }
CUUsersConfiguration >> maximumUsersPerFeed [
 ^ maximumUsersPerFeed
]

{ #category : 'push updates' }
CUUsersConfiguration >> maximumUsersPerFeed: value [
 maximumUsersPerFeed := value
]

{ #category : 'push updates' }
CUUsersConfiguration >> receiveWaitMillis [
 ^ receiveWaitMillis
]

{ #category : 'push updates' }
CUUsersConfiguration >> receiveWaitMillis: value [
 receiveWaitMillis := value
]

{ #category : 'push updates' }
CUUsersConfiguration >> validateSemanticsOn: result [
 super validateSemanticsOn: result.
 ((maximumFeeds isInteger and: [maximumFeeds between: 1 and: 64]) and: [maximumUsersPerFeed isInteger and: [maximumUsersPerFeed between: 1 and: 256]]) ifFalse: [result addError: 'Users feed capacity is out of bounds.'].
 ((receiveWaitMillis isInteger and: [receiveWaitMillis between: 100 and: 15000]) and: [feedLeaseMillis isInteger and: [feedLeaseMillis between: receiveWaitMillis * 2 and: 300000]]) ifFalse: [result addError: 'Users feed wait/lease is out of bounds.']
]
