Class {
	#name : 'CUUsersConnectExamples',
	#superclass : 'TestCase',
	#category : 'BVC-Users-Connect-Tests',
	#package : 'BVC-Users-Connect-Tests'
}

{ #category : 'fixtures' }
CUUsersConnectExamples >> configuration [
 ^ CCQuicConfiguration new identifier: #connect; principal: 'usersAuthority'; bindings: {CRServiceBindingConfiguration new identifier: #users; label: 'Users'; serviceIdentifier: #users; runtimeIdentifier: 'usersAuthority'; connectServiceIdentifier: #connect; yourself}; yourself
]

{ #category : 'tests' }
CUUsersConnectExamples >> testClientBeforeReadinessDoesNotCreateAUser [
 <gtExample>
 <return: #CCObjectFuture>
 | client future binding |
 binding := CUUsersObjectApplication new bindingFor: self configuration.
 client := CUUsersClient new endpoint: (CCObjectEndpoint new binding: binding transport: CCQuicService new).
 future := client createUser: (CUUser new name: 'Not submitted'; yourself).
 self assert: future state equals: #unavailable. ^ future
]

{ #category : 'tests' }
CUUsersConnectExamples >> testConfiguredBindingRetainsUsersTransactionAndCapabilityContracts [
 <gtExample>
 <return: #CCObjectBinding>
 | binding completion envelope |
 binding := CUUsersObjectApplication new bindingFor: self configuration.
 self assert: binding requiresTransaction.
 self assert: (CUUsersCapability canBeGrantedToWorkUnitClass: CUCreateUserMessageWork).
 self assert: CUCreateUserMessageWork serviceClass == CUUsersService.
 completion := CCObjectResultCompletion new binding: binding response: CCObjectDeferredResponse new probe: false.
 envelope := CUCreateUserMessageWork new asEnvelope resultCompletion: completion; yourself.
 self assert: completion afterCommit. self assert: completion afterFinalization.
 self deny: CUCreateUserMessageWork allowsConflictReplay. ^ binding
]

{ #category : 'tests' }
CUUsersConnectExamples >> testNativeUserDescriptionRoundTrip [
 <gtExample>
 <return: #CUUser>
 | original schema result |
 original := CUUser new name: 'Client-created user'; yourself.
 schema := CCObjectSchema forObject: original. result := schema decode: (schema encode: original).
 self assert: result class == CUUser. self assert: result name equals: original name.
 self deny: result isSuperUser. self deny: result == original. ^ result
]

{ #category : 'tests' }
CUUsersConnectExamples >> testPlatformQualificationRetainsCommitContract [
 <gtExample>
 <return: #CCObjectBinding>
 | binding completion |
 binding := CUUsersCommitGateApplicationFixture new bindingFor: self configuration.
 self assert: binding requiresTransaction.
 self assert: (CUUsersCapability canBeGrantedToWorkUnitClass: CUUsersCommitGateMessageFixture).
 self assert: CUUsersCommitGateMessageFixture serviceClass == CUUsersService.
 completion := CCObjectResultCompletion new binding: binding response: CCObjectDeferredResponse new probe: false.
 self assert: completion afterCommit. self assert: completion afterFinalization.
 ^ binding
]

{ #category : 'tests' }
CUUsersConnectExamples >> testUnicodeUserDescriptionRoundTrip [
 <gtExample>
 <return: #CUUser>
 | user schema result |
 user := CUUser new name: ('Ada ', #[195 169 240 159 155 176] utf8Decoded, '/"'); yourself.
 schema := CCObjectSchema forObject: user. result := schema decode: (schema encode: user).
 self assert: result name equals: user name. self deny: result isSuperUser.
 self assert: schema revision equals: '742282f3bd6d47c824c6c12a2244dcb79ac5b13ba1d94aa4bd60b843608185cb'.
 ^ result
]

{ #category : 'tests' }
CUUsersConnectExamples >> testWrongConfiguredPeerCannotCreateUsersEndpoint [
 <gtExample>
 <return: #CCQuicConfiguration>
 | configuration |
 configuration := self configuration principal: 'anotherAuthority'; yourself.
 self should: [CUUsersObjectApplication new bindingFor: configuration] raise: Error. ^ configuration
]

{ #category : 'tests' }
CUUsersConnectExamples >> testWrongConnectServiceCannotCreateUsersEndpoint [
 <gtExample>
 <return: #CCQuicConfiguration>
 | configuration |
 configuration := self configuration identifier: #anotherConnect; yourself.
 self should: [CUUsersObjectApplication new bindingFor: configuration] raise: Error. ^ configuration
]
