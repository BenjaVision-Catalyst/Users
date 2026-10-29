Class {
	#name : 'CUUsersCommitGateApplicationFixture',
	#superclass : 'CUUsersObjectApplication',
	#category : 'BVC-Users-Connect-Tests',
	#package : 'BVC-Users-Connect-Tests'
}

{ #category : 'push updates' }
CUUsersCommitGateApplicationFixture >> liveWorkClasses [
 ^ {CUCreateLiveUserGateWork. CUReadLiveUserWork. CUUpdateLiveUserGateWork. CURecoverLiveUserWork}
]

{ #category : 'configuration' }
CUUsersCommitGateApplicationFixture >> messageWorkClass [
 ^ CUUsersCommitGateMessageFixture
]
