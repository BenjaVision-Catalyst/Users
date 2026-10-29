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

{ #category : 'tests - lookup' }
CUUsersConnectExamples >> testApplicationSelectsConfiguredLookupAndCreation [
 <gtExample>
 <return: #CUUsersObjectApplication>
 | configuration application declared response |
 configuration := self configuration allowedOperations: #(1 2 65534); yourself.
 application := CUUsersObjectApplication new.
 declared := application bindingsFor: configuration.
 self assert: (declared collect: #operation) equals: #(1 2).
 application configure: configuration.
 response := application execute: (CCQuicRequest new operation: 65534; body: #[1]; principal: 'usersAuthority'; yourself) using: nil.
 self assert: response response second equals: 400.
 self should: [application execute: (CCQuicRequest new operation: 3; yourself) using: nil] raise: Error.
 self assert: ((CUUsersObjectApplication new bindingsFor: (self configuration allowedOperations: #(1 65534); yourself)) collect: #operation) equals: #(1).
 ^ application
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

{ #category : 'tests - lookup' }
CUUsersConnectExamples >> testLookupUsesExistingUserDescriptionAndCommitCompletion [
 <gtExample>
 <return: #CCObjectBinding>
 | binding query schema result completion |
 binding := CUUsersObjectApplication new lookupBindingFor: self configuration.
 self assert: binding operation equals: 2.
 self assert: binding requiresTransaction.
 self assert: (CUUsersCapability canBeGrantedToWorkUnitClass: CUGetUserMessageWork).
 self assert: binding resultSchema revision equals: (CCObjectSchema forObject: CUUser new) revision.
 query := CUUserLookup new name: ('Ada ', #[195 169 240 159 155 176] utf8Decoded); yourself.
 schema := binding requestSchema. result := schema decode: (schema encode: query).
 self assert: result name equals: query name. self deny: result == query.
 self assert: schema revision equals: '31b7f14dece1b6bbf864672c923ae7a0170b058c053bec846e9db8be5ed0e8f1'.
 self assert: (binding statusForResult: nil) equals: 404.
 self assert: (binding statusForResult: #ambiguous) equals: 422.
 self assert: (binding statusForResult: CUUsers admin) equals: 0.
 completion := CCObjectResultCompletion new binding: binding response: CCObjectDeferredResponse new probe: false.
 self assert: completion afterCommit. self assert: completion afterFinalization. ^ binding
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
