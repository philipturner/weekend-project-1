import MM4

func minimize(
  parameters: MM4Parameters,
  positions: [SIMD3<Float>],
  anchors: Set<UInt32> = []
) -> [SIMD3<Float>] {
  var forceFieldParameters = parameters
  for atomID in anchors {
    forceFieldParameters.atoms.masses[Int(atomID)] = 0
  }
  
  var forceFieldDesc = MM4ForceFieldDescriptor()
  forceFieldDesc.parameters = forceFieldParameters
  let forceField = try! MM4ForceField(descriptor: forceFieldDesc)

  var minimizationDesc = FIREMinimizationDescriptor()
  minimizationDesc.anchors = anchors
  minimizationDesc.masses = parameters.atoms.masses
  minimizationDesc.positions = positions
  var minimization = FIREMinimization(descriptor: minimizationDesc)
  
  let maxIterationCount: Int = 500
  for trialID in 0..<maxIterationCount {
    forceField.positions = minimization.positions
    print(forceField.positions[100])
    
    let forces = forceField.forces
    var maximumForce: Float = .zero
    for atomID in positions.indices {
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
  
  return forceField.positions
}
