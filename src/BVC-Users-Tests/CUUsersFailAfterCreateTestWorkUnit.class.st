"
Native transaction qualification fixture: raises after Users creation so the actual Runtime transaction must roll back the stored user.
"
Class {
	#name : 'CUUsersFailAfterCreateTestWorkUnit',
	#superclass : 'CUCreateUserWorkUnit',
	#category : 'BVC-Users-Tests',
	#package : 'BVC-Users-Tests'
}

{ #category : 'execution' }
CUUsersFailAfterCreateTestWorkUnit >> executeInContext: context [
 super executeInContext: context.
 self error: 'Users transaction rollback probe.'
]
