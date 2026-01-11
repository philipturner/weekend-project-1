import HDL
import MM4

func minimize(
  parameters: MM4Parameters,
  positions: [SIMD3<Float>],
  anchors: Set<UInt32> = []
) -> [[SIMD4<Float>]] {
  var forceFieldParameters = parameters
  for atomID in anchors {
    forceFieldParameters.atoms.masses[Int(atomID)] = 0
  }
  
  var forceFieldDesc = MM4ForceFieldDescriptor()
  forceFieldDesc.parameters = parameters
  let forceField = try! MM4ForceField(descriptor: forceFieldDesc)

  var minimizationDesc = FIREMinimizationDescriptor()
//  minimizationDesc.anchors = anchors
  minimizationDesc.masses = parameters.atoms.masses
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
  
  let maxIterationCount: Int = 2000
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
      frames.append(createFrame())
      break
    } else if trialID == maxIterationCount - 1 {
      print("failed to converge!")
    }
  }
  
  return frames
}
