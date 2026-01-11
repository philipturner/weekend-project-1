import Foundation
import HDL
import MM4
import MolecularRenderer
import QuaternionModule
import xTB

// MARK: - User-Facing Options

let renderingOffline: Bool = false

// The net force, in piconewtons.
let netForce = SIMD3<Float>(0, 0, 1)

// The simulation time per frame, in picoseconds. Frames are recorded and
// nominally played back at 60 FPS.
let frameSimulationTime: Double = 10.0 / 60
let frameCount: Int = 60 * 2
let gifFrameSkipRate: Int = 1

// MARK: - Compile Atoms

var path = FileManager.default.currentDirectoryPath
path += "/Sources/Workspace/Diamond_Machine_Parts/Blocks/"
path += "8_tooth_gear_clip_bushing.mmp"

let fileData = FileManager.default.contents(atPath: path)
guard let fileData else {
  fatalError("Could not get file at path: \(path)")
}
let fileString = String(data: fileData, encoding: .utf8)
guard let fileString else {
  fatalError("Could not create string.")
}

let mmp = MMP(string: fileString)

// # Have I found a rule to reverse-engineer the image?
//
// Ring 6 tall
// Stub 4-5 tall
//
// Ring 4 tall
// Stub 2-3 tall
//
// Now that I look, since it's very hard to make out the layer count,
// there's a very good chance the images are 6 layers thick.
//
// Test an MD simulation with the exact parts from the file, no extra
// compilation needed. The bond topology is compatible with MM4.
//
// # Parsed the needed components from 8Tooth.mmp
//
// Pin
// mol (pin1) def
// mmp.selectSubRange((UInt32(3606)...11756).map { $0 })
//
// Socket, 6 atomic layers
// mol (socket1) def
// mmp.selectSubRange((UInt32(23436)...25955).map { $0 })
//
// Socket, 7 atomic layers
// mol (socket template-copy1) def
// mmp.selectSubRange((UInt32(42439)...45336).map { $0 }) [thick]
//
// # YouTube data
//
// Ring: 7 + vdW gap + 7
// Stub: 13
//
// Ring: 7
// Stub: 5
//
// Example from this file: stub is indeed 5 layers tall

@MainActor
func createPart(range: ClosedRange<UInt32>) -> Topology {
  var topology = mmp.topology
  let setIncluded = Set(range)
  
  var removedIDs: [UInt32] = []
  for atomID in topology.atoms.indices.map(UInt32.init) {
    if !setIncluded.contains(atomID) {
      removedIDs.append(atomID)
    }
  }
  topology.remove(atoms: removedIDs)
  
  return topology
}

@MainActor
func createPin() -> Pin {
  let pinTopology = createPart(range: 3606...11756)
  return Pin(topology: pinTopology)
}

@MainActor
func createSocket() -> Socket {
  let socket7Topology = createPart(range: 42439...45336)
  return Socket(topology: socket7Topology)
}

let pin = createPin()
let socket = createSocket()

// MARK: - Run Simulation

@MainActor
func createForceField() -> (MM4Parameters, MM4ForceField) {
  var parameters = MM4Parameters()
  parameters.append(contentsOf: pin.parameters)
  parameters.append(contentsOf: socket.parameters)
  
  var forceFieldDesc = MM4ForceFieldDescriptor()
  forceFieldDesc.integrator = .multipleTimeStep
  forceFieldDesc.parameters = parameters
  let forceField = try! MM4ForceField(descriptor: forceFieldDesc)
  
  var positions: [SIMD3<Float>] = []
  positions += pin.rigidBody.positions
  positions += socket.rigidBody.positions
  forceField.positions = positions
  
  return (parameters, forceField)
}
let (parameters, forceField) = createForceField()

func apply(
  netForce: SIMD3<Float>,
  forceField: MM4ForceField,
  masses: [Float],
  handleIDs: Set<UInt32>
) {
  var totalMass: Float = 0
  for atomID in handleIDs {
    let mass = masses[Int(atomID)]
    totalMass += mass
  }
  
  // F = m * a
  // a = F / m
  let acceleration: SIMD3<Float> = netForce / totalMass
  
  var externalForces = [SIMD3<Float>](
    repeating: .zero, count: masses.count)
  for atomID in handleIDs {
    let mass = masses[Int(atomID)]
    let force: SIMD3<Float> = mass * acceleration
    externalForces[Int(atomID)] = force
  }
  forceField.externalForces = externalForces
}
apply(
  netForce: netForce,
  forceField: forceField,
  masses: parameters.atoms.masses,
  handleIDs: pin.handleIDs)

var frames: [[Atom]] = []
@MainActor
func createFrame() -> [Atom] {
  var output: [SIMD4<Float>] = []
  for atomID in parameters.atoms.indices {
    let atomicNumber = parameters.atoms.atomicNumbers[atomID]
    let position = forceField.positions[atomID]
    let atom = Atom(position: position, atomicNumber: atomicNumber)
    output.append(atom)
  }
  return output
}
frames.append(createFrame())

print(pin.rigidBody.positions.count)
print(socket.rigidBody.positions.count)
exit(0)

/*
for frameID in 1...frameCount {
  forceField.simulate(time: frameSimulationTime)
  
  let time = Double(frameID) * frameSimulationTime
  print("t = \(String(format: "%.3f", time)) ps")
  frames.append(createFrame())
}
 */

// MARK: - Launch Application

// Input: time in seconds
// Output: atoms
func interpolate(
  frames: [[Atom]],
  time: Float
) -> [Atom] {
  guard frames.count >= 1 else {
    fatalError("Need at least one frame to know size of atom list.")
  }
  
  let multiple60Hz = time * 60
  var lowFrame = Int(multiple60Hz.rounded(.down))
  var highFrame = lowFrame + 1
  var lowInterpolationFactor = Float(highFrame) - multiple60Hz
  var highInterpolationFactor = multiple60Hz - Float(lowFrame)
  
  if lowFrame < -1 {
    fatalError("This should never happen.")
  }
  if lowFrame >= frames.count - 1 {
    lowFrame = frames.count - 1
    highFrame = frames.count - 1
    lowInterpolationFactor = 1
    highInterpolationFactor = 0
  }
  
  var output: [Atom] = []
  for atomID in frames[0].indices {
    let lowAtom = frames[lowFrame][atomID]
    let highAtom = frames[highFrame][atomID]
    
    var position: SIMD3<Float> = .zero
    position += lowAtom.position * lowInterpolationFactor
    position += highAtom.position * highInterpolationFactor
    
    var atom = lowAtom
    atom.position = position
    output.append(atom)
  }
  return output
}

@MainActor
func createApplication() -> Application {
  // Set up the device.
  var deviceDesc = DeviceDescriptor()
  deviceDesc.deviceID = Device.fastestDeviceID
  let device = Device(descriptor: deviceDesc)
  
  // Set up the display.
  var displayDesc = DisplayDescriptor()
  displayDesc.device = device
  if renderingOffline {
    displayDesc.frameBufferSize = SIMD2<Int>(1280, 720)
  } else {
    displayDesc.frameBufferSize = SIMD2<Int>(1920, 1080)
  }
  if !renderingOffline {
    displayDesc.monitorID = device.fastestMonitorID
  }
  let display = Display(descriptor: displayDesc)
  
  // Set up the application.
  var applicationDesc = ApplicationDescriptor()
  applicationDesc.device = device
  applicationDesc.display = display
  if renderingOffline {
    applicationDesc.upscaleFactor = 1
  } else {
    applicationDesc.upscaleFactor = 3
  }
  
  applicationDesc.addressSpaceSize = 4_000_000
  applicationDesc.voxelAllocationSize = 500_000_000
  applicationDesc.worldDimension = 64
  let application = Application(descriptor: applicationDesc)
  
  return application
}
let application = createApplication()

@MainActor
func createTime() -> Float {
  if renderingOffline {
    let elapsedFrames = gifFrameSkipRate * application.frameID
    let frameRate: Int = 60
    let seconds = Float(elapsedFrames) / Float(frameRate)
    return seconds
  } else {
    let elapsedFrames = application.clock.frames
    let frameRate = application.display.frameRate
    let seconds = Float(elapsedFrames) / Float(frameRate)
    return seconds
  }
}

// Extra animation frames bring the pin into position, from farther away.
// Start at -5 nm, and at -3 nm.
// Then replay the MD simulation.
//
// Repeat the above twice: from 110°, then 0°.
@MainActor
func modifyAtoms() {
  let time = createTime()
  
  if time < 1 {
    let atomsToRender = frames[0]
    for atomID in atomsToRender.indices {
      let atom = atomsToRender[atomID]
      application.atoms[atomID] = atom
    }
  } else {
    let atoms = interpolate(
      frames: frames,
      time: time - 1)
    for atomID in atoms.indices {
      let atom = atoms[atomID]
      application.atoms[atomID] = atom
    }
  }
}

@MainActor
func modifyCamera() {
  let focalPoint = SIMD3<Float>(2, 2.8, 7)
  let rotation = Quaternion<Float>(
    angle: Float.pi / 180 * 110,
    axis: SIMD3(0, 1, 0))
  let cameraDistance: Float = 15
  
  func rotate(_ vector: SIMD3<Float>) -> SIMD3<Float> {
    var output = rotation.act(on: vector)
    
    // Fix source of rendering error. Now the limiting factor is probably
    // internal to the renderer itself. Unsure exactly what's happening at
    // large distances.
    output /= (output * output).sum().squareRoot()
    return output
  }
  application.camera.basis.0 = rotate(SIMD3(1, 0, 0))
  application.camera.basis.1 = rotate(SIMD3(0, 1, 0))
  application.camera.basis.2 = rotate(SIMD3(0, 0, 1))
  application.camera.fovAngleVertical = Float.pi / 180 * 30
  
  var position = focalPoint
  position += rotation.act(on: SIMD3(0, 0, cameraDistance))
  application.camera.position = position
}

application.run {
  modifyAtoms()
  modifyCamera()
  
  var image = application.render()
  image = application.upscale(image: image)
  application.present(image: image)
}
