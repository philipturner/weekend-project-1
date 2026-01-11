import HDL
import MM4

func minimize(
  parameters: MM4Parameters,
  positions: [SIMD3<Float>],
  anchors: Set<UInt32> = []
) -> [[SIMD4<Float>]] {
  var forceFieldDesc = MM4ForceFieldDescriptor()
  forceFieldDesc.parameters = parameters
  let forceField = try! MM4ForceField(descriptor: forceFieldDesc)

  var minimizationDesc = FIREMinimizationDescriptor()
  minimizationDesc.anchors = anchors
  minimizationDesc.masses = parameters.atoms.masses
  minimizationDesc.forceTolerance = 50
  minimizationDesc.positions = positions
  var minimization = FIREMinimization(descriptor: minimizationDesc)
  
  // WARNING: May approach limit of device memory.
  // 10k atoms * 16 bytes * 2000 frames = 320 MB
  var frames: [[SIMD4<Float>]] = []
  func createFrame() -> [Atom] {
    var output: [SIMD4<Float>] = []
    for atomID in positions.indices {
      let atomicNumber = parameters.atoms.atomicNumbers[atomID]
      let position = minimization.positions[atomID]
      let atom = Atom(position: position, atomicNumber: atomicNumber)
      output.append(atom)
    }
    return output
  }
  
  let maxIterationCount: Int = 500
  for trialID in 0..<maxIterationCount {
    frames.append(createFrame())
    forceField.positions = minimization.positions
    
    let forces = forceField.forces
    var maximumForce: Float = .zero
    for atomID in positions.indices {
      if anchors.contains(UInt32(atomID)) {
        continue
      }
      let force = forces[atomID]
      let forceMagnitude = (force * force).sum().squareRoot()
      maximumForce = max(maximumForce, forceMagnitude)
    }
    
    let energy = forceField.energy.potential
    print("time: \(Format.time(minimization.time))", terminator: " | ")
    print("energy: \(Format.energy(energy))", terminator: " | ")
    print("max force: \(Format.force(maximumForce))", terminator: " | ")
    
    let converged = minimization.step(forces: forces)
    if !converged {
      print("Δt: \(Format.time(minimization.Δt))", terminator: " | ")
    }
    print()
    
    if converged {
      print("converged at trial \(trialID)")
      break
    } else if trialID == maxIterationCount - 1 {
      print("failed to converge!")
    }
  }
  
  var rigidBodyDesc = MM4RigidBodyDescriptor()
  rigidBodyDesc.masses = parameters.atoms.masses
  rigidBodyDesc.positions = frames.last!.map(\.position)
  let rigidBody = try! MM4RigidBody(descriptor: rigidBodyDesc)
  
  forceField.positions = rigidBody.positions
  let energy = forceField.energy.potential
  print("energy: \(Format.energy(energy))")
  
  return frames
}
