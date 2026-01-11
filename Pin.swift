import HDL

struct Pin {
  var topology: Topology // break into parameters and rigid body
  var handleIDs: Set<UInt32>
  
  init(topology: Topology) {
    self.topology = topology
    self.handleIDs = Self.handleIDs(topology: topology)
  }
  
  private static func handleIDs(topology: Topology) -> Set<UInt32> {
    var output: Set<UInt32> = []
    for atomID in topology.atoms.indices {
      let atom = topology.atoms[atomID]
      if atom.position.z < 7 {
        output.insert(UInt32(atomID))
      }
    }
    return output
  }
}
