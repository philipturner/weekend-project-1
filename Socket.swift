import HDL

struct Socket {
  var topology: Topology // break into parameters and rigid body
  var anchorIDs: Set<UInt32>
  
  init(topology: Topology) {
    self.topology = topology
    self.anchorIDs = Self.anchorIDs(topology: topology)
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
}
