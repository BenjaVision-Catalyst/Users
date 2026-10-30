"
Explicit volatile fixture for portable completion ordering. Native durability is qualified separately through the configured default transactional worker.
"
Class {
	#name : 'CUUsersPublicationTestWorker',
	#superclass : 'CRFinalizedResultTestWorker',
	#category : 'BVC-Users-Connect-Tests',
	#package : 'BVC-Users-Connect-Tests'
}

{ #category : 'initialization' }
CUUsersPublicationTestWorker >> initialize [
 super initialize. localStrategy := CRWorkUnitExecutionStrategy new
]
