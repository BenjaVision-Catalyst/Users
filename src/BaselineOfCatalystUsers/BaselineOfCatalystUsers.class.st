"
Portable Catalyst Users Runtime service. Production loads select Runtime's native backend; examples are opt-in. Storage and domain operations follow the Users design rather than the old README.
"
Class {
	#name : 'BaselineOfCatalystUsers',
	#superclass : 'BaselineOf',
	#category : 'BaselineOfCatalystUsers',
	#package : 'BaselineOfCatalystUsers'
}

{ #category : 'baselines' }
BaselineOfCatalystUsers >> baseline: spec [
 <baseline>
 spec for: #common do: [
  spec baseline: 'CatalystRuntime' with: [
   self runtimeRepositoryDescriptions do: [:repository | spec repository: repository].
   spec loads: #('runtime-core')].
  spec project: 'CatalystRuntime tests' copyFrom: 'CatalystRuntime' with: [spec loads: #('test-support')].
  spec baseline: 'CatalystConnect' with: [self connectRepositoryDescriptions do: [:repository | spec repository: repository]. spec loads: #('objects')].
  spec project: 'CatalystConnect tests' copyFrom: 'CatalystConnect' with: [spec loads: #('tests-objects')].
  spec package: 'BVC-Users-Core'.
  spec package: 'BVC-Users-Runtime' with: [spec requires: #('BVC-Users-Core' 'CatalystRuntime')].
  spec package: 'BVC-Users-Tests' with: [spec requires: #('BVC-Users-Runtime' 'CatalystRuntime tests')].
  spec package: 'BVC-Users-Connect-Core' with: [spec requires: #('BVC-Users-Runtime' 'CatalystConnect')].
  spec package: 'BVC-Users-Connect-Tests' with: [spec requires: #('BVC-Users-Connect-Core')].
  spec group: 'connect' with: #('runtime' 'BVC-Users-Connect-Core').
  spec group: 'tests-connect' with: #('connect' 'BVC-Users-Connect-Tests').
  spec group: 'core' with: #('BVC-Users-Core').
  spec group: 'runtime' with: #('BVC-Users-Core' 'BVC-Users-Runtime').
  spec group: 'tests' with: #('runtime' 'BVC-Users-Tests').
  spec group: 'default' with: #('runtime')].
 spec for: #pharo do: [
  spec group: 'gt' with: #('runtime').
  spec package: 'BVC-Users-Connect-Tests-GT' with: [spec requires: #('BVC-Users-Connect-Tests' 'CatalystConnect tests')].
  spec group: 'tests-connect' with: #('connect' 'BVC-Users-Connect-Tests' 'BVC-Users-Connect-Tests-GT')].
 spec for: #gemstone do: [spec group: 'gemstone' with: #('runtime')]
]

{ #category : 'dependencies' }
BaselineOfCatalystUsers >> connectRepositoryDescriptions [
 | registered |
 registered := MetacelloProjectRegistration projectSpecForClassNamed: 'BaselineOfCatalystConnect'
  ifAbsent: [^ #('github://BenjaVisionPro/CatalystConnect:main/src')].
 ^ registered repositoryDescriptions
]

{ #category : 'loading' }
BaselineOfCatalystUsers >> newProjectWithRepositoryDescription: descriptions [
"Install the service, capability and WorkUnit classes together before compiling their references."
 ^ (super newProjectWithRepositoryDescription: descriptions) loadType: #atomic; yourself
]

{ #category : 'dependencies' }
BaselineOfCatalystUsers >> runtimeRepositoryDescriptions [
| registered |
 registered := MetacelloProjectRegistration
  projectSpecForClassNamed: 'BaselineOfCatalystRuntime'
  ifAbsent: [^ #('github://BenjaVisionPro/CatalystRuntime:main/src')].
 ^ registered repositoryDescriptions
]
