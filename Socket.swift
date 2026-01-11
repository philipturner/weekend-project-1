import HDL
import MM4

struct Socket {
  var parameters: MM4Parameters
  var rigidBody: MM4RigidBody
  var anchorIDs: Set<UInt32>
  
  init(topology: Topology) {
    (parameters, rigidBody) = Self.createRigidBody(topology: topology)
    anchorIDs = Self.anchorIDs(topology: topology)
    
    _minimize()
    
//    for atomID in anchorIDs {
//      parameters.atoms.masses[Int(atomID)] = 0
//    }
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
  
  private static func anchorIDs(topology: Topology) -> Set<UInt32> {
    var centerOfMass: SIMD3<Float> = .zero
    for atom in topology.atoms {
      centerOfMass += atom.position
    }
    centerOfMass /= Float(topology.atoms.count)
    
    let atomsToAtomsMap = topology.map(.atoms, to: .atoms)
    
    var output: Set<UInt32> = []
    for atomID in topology.atoms.indices {
      let atom = topology.atoms[atomID]
      var delta = atom.position - centerOfMass
      delta.z = 0
      
      let deltaLength = (delta * delta).sum().squareRoot()
      guard deltaLength > 2.5 else {
        continue
      }
      guard atom.atomicNumber == 1 else {
        continue
      }
      
      // Retrieve the other atom engaged in a covalent bond.
      let atomsMap = atomsToAtomsMap[atomID]
      guard atomsMap.count == 1 else {
        fatalError("This should never happen.")
      }
      let carbonID = atomsMap[0]
      let carbon = topology.atoms[Int(carbonID)]
      
      // Exclude atoms on the (0001) surface.
      var bondVector = atom.position - carbon.position
      bondVector /= (bondVector * bondVector).sum().squareRoot()
      if bondVector.z.magnitude > 0.5 {
        continue
      }
      
      output.insert(UInt32(atomID))
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
