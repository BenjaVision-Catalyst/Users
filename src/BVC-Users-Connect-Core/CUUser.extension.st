Extension { #name : 'CUUser' }

{ #category : '*BVC-Users-Connect-Core' }
CUUser >> descriptionName [
 ^ MAStringDescription new accessor: #name; label: 'Name'; beRequired; yourself
]

{ #category : '*BVC-Users-Connect-Core' }
CUUser >> descriptionSuperUser [
 ^ MABooleanDescription new accessor: (MASelectorAccessor read: #isSuperUser write: #isSuperUser:); label: 'Super user'; beRequired; yourself
]

{ #category : '*BVC-Users-Connect-Core' }
CUUser >> magritteDescription [
 ^ MAContainer withAll: {self descriptionName. self descriptionSuperUser}
]
