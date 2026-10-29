Extension { #name : 'CULiveUserState' }

{ #category : '*BVC-Users-Connect-Core' }
CULiveUserState >> magritteDescription [
 ^ MAContainer withAll: {
  self descriptionName.
  self readOnlyDescription: self descriptionSuperUser.
  self readOnlyDescription: (MAStringDescription new accessor: #userIdentifier; label: 'User identity'; beRequired; yourself).
  self readOnlyDescription: (MANumberDescription new accessor: #revision; kind: Integer; label: 'Revision'; beRequired; min: 0; yourself).
  self readOnlyDescription: (MAStringDescription new accessor: #outcome; label: 'Outcome'; beRequired; yourself)}
]
