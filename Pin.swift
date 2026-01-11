import HDL
import MM4

struct Pin {
  var parameters: MM4Parameters
  var rigidBody: MM4RigidBody
  var handleIDs: Set<UInt32>
  
  init(topology: Topology) {
    (parameters, rigidBody) = Self.createRigidBody(topology: topology)
    handleIDs = Self.handleIDs(topology: topology)
    
    _minimize()
    
    rigidBody.centerOfMass += SIMD3(0, 0, -2.4)
  }
  
  var atoms: [Atom] {
    var output: [Atom] = []
    for atomID in parameters.atoms.indices {
      let atomicNumber = parameters.atoms.atomicNumbers[atomID]
      let position = rigidBody.positions[atomID]
      let atom = Atom(position: position, atomicNumber: atomicNumber)
      output.append(atom)
    }
    return output
  }
  
  private mutating func _minimize() {
    let frames = minimize(
      parameters: parameters,
      positions: rigidBody.positions)
    
    var rigidBodyDesc = MM4RigidBodyDescriptor()
    rigidBodyDesc.masses = parameters.atoms.masses
    rigidBodyDesc.positions = frames.last!.map(\.position)
    rigidBody = try! MM4RigidBody(descriptor: rigidBodyDesc)
  }
  
  private static func handleIDs(topology: Topology) -> Set<UInt32> {
    var centerOfMass: SIMD3<Float> = .zero
    for atom in topology.atoms {
      centerOfMass += atom.position
    }
    centerOfMass /= Float(topology.atoms.count)
    
    var output: Set<UInt32> = []
    for atomID in topology.atoms.indices {
      let atom = topology.atoms[atomID]
      if atom.position.z > 7,
         atom.position.z < 7.3 {
        var delta = atom.position - centerOfMass
        delta.z = 0
        
        let deltaLength = (delta * delta).sum().squareRoot()
        if deltaLength < 2 {
          output.insert(UInt32(atomID))
        }
      }
    }
    return output
  }
  
  private static func createRigidBody(
    topology: Topology
  ) -> (MM4Parameters, MM4RigidBody) {
    var paramsDesc = MM4ParametersDescriptor()
    paramsDesc.atomicNumbers = topology.atoms.map(\.atomicNumber)
    paramsDesc.bonds = topology.bonds
    let parameters = try! MM4Parameters(descriptor: paramsDesc)
    
    var rigidBodyDesc = MM4RigidBodyDescriptor()
    rigidBodyDesc.masses = parameters.atoms.masses
    rigidBodyDesc.positions = topology.atoms.map(\.position)
    let rigidBody = try! MM4RigidBody(descriptor: rigidBodyDesc)
    
    return (parameters, rigidBody)
  }
}
