"
Abstract base for inert Users application work. Concrete operations declare bounded data and their Runtime transaction requirements. No transport state or storage implementation belongs in this base.
"
Class {
	#name : 'CUUsersWorkUnit',
	#superclass : 'CRWorkUnit',
	#category : 'BVC-Users-Runtime',
	#package : 'BVC-Users-Runtime'
}

{ #category : 'contracts' }
CUUsersWorkUnit class >> requiredCapabilities [
^ {CUUsersCapability}
]

{ #category : 'contracts' }
CUUsersWorkUnit class >> serviceClass [
^ CUUsersService
]
