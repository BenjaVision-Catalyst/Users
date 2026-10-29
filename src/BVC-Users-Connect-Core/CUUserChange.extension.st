Extension { #name : 'CUUserChange' }

{ #category : '*BVC-Users-Connect-Core' }
CUUserChange >> magritteDescription [
 ^ MAContainer withAll: {
  CUUser new descriptionName.
  MAStringDescription new accessor: #userIdentifier; label: 'User identity'; beRequired; yourself.
  MAStringDescription new accessor: #operationIdentifier; label: 'Operation identity'; beRequired; yourself.
  MANumberDescription new accessor: #expectedRevision; kind: Integer; label: 'Expected revision'; beRequired; min: 0; yourself}
]
