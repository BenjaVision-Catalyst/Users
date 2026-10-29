Class {
	#name : 'CUUsersCommitGateApplicationFixture',
	#superclass : 'CUUsersObjectApplication',
	#category : 'BVC-Users-Connect-Tests',
	#package : 'BVC-Users-Connect-Tests'
}

{ #category : 'configuration' }
CUUsersCommitGateApplicationFixture >> liveWorkClasses [
 ^ {CUCreateLiveUserGateWork. CUReadLiveUserWork. CUUpdateLiveUserWork. CURecoverLiveUserWork}
]

{ #category : 'configuration' }
CUUsersCommitGateApplicationFixture >> messageWorkClass [
 ^ CUUsersCommitGateMessageFixture
]
