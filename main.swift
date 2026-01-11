import Foundation
import GIFModule
import HDL
import MM4
import MolecularRenderer
import QuaternionModule
import xTB

// MARK: - User-Facing Options

let renderingOffline: Bool = false

// The net force, in piconewtons.
let netForce1 = SIMD3<Float>(0, 0, 10_000)
let netForce2 = SIMD3<Float>(0, 0, 0)

// The simulation time per frame, in picoseconds. Frames are recorded and
// nominally played back at 60 FPS.
let frameSimulationTime: Double = 10.0 / 60
let frameCount1: Int = 60 * 7
let frameCount2: Int = 60 * 0
let gifFrameSkipRate: Int = 1

let frameCount = 60 + 60 + frameCount1 + 60
let cameraAngleDegrees: Float = 110

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
  forceFieldDesc.integrator = .verlet // doesn't spawn spurious vibrations
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

#if true
apply(
  netForce: netForce1,
  forceField: forceField,
  masses: parameters.atoms.masses,
  handleIDs: pin.handleIDs)
for frameID in 1...frameCount1 {
  forceField.simulate(time: frameSimulationTime)
  frames.append(createFrame())
  
  let time = Double(frameID) * frameSimulationTime
  let energy = forceField.energy.potential
  
  let forces = forceField.forces
  let positions = forceField.positions
  var maximumForce: Float = .zero
  for atomID in positions.indices {
    let mass = parameters.atoms.masses[atomID]
    if mass == 0 {
      continue
    }
    
    let force = forces[atomID]
    let forceMagnitude = (force * force).sum().squareRoot()
    maximumForce = max(maximumForce, forceMagnitude)
  }
  
  print("time: \(Format.timePs(time))", terminator: " | ")
  print("energy: \(Format.energy(energy))", terminator: " | ")
  print("max force: \(Format.force(maximumForce))", terminator: " | ")
  print()
}
forceField.velocities = [SIMD3<Float>](
  repeating: .zero, count: parameters.atoms.count)

//apply(
//  netForce: netForce2,
//  forceField: forceField,
//  masses: parameters.atoms.masses,
//  handleIDs: pin.handleIDs)
//for frameID in 1...frameCount2 {
//  forceField.simulate(time: frameSimulationTime)
//  frames.append(createFrame())
//  
//  let time = Double(frameID) * frameSimulationTime
//  let energy = forceField.energy.potential
//  
//  let forces = forceField.forces
//  let positions = forceField.positions
//  var maximumForce: Float = .zero
//  for atomID in positions.indices {
//    let mass = parameters.atoms.masses[atomID]
//    if mass == 0 {
//      continue
//    }
//    
//    let force = forces[atomID]
//    let forceMagnitude = (force * force).sum().squareRoot()
//    maximumForce = max(maximumForce, forceMagnitude)
//  }
//  
//  print("time: \(Format.timePs(time))", terminator: " | ")
//  print("energy: \(Format.energy(energy))", terminator: " | ")
//  print("max force: \(Format.force(maximumForce))", terminator: " | ")
//  print()
//}
#endif

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

#if true
// Extra animation frames bring the pin into position, from farther away.
// Start at -5 nm, and at -3 nm.
// Then replay the MD simulation.
//
// Repeat the above twice: from 110°, then 0°.
// Just use two separate GIFs (two separate program executions).
@MainActor
func modifyAtoms() {
  let time = createTime()
  
  let freezeTimestamp: Float = 1
  let moveTimestamp: Float = freezeTimestamp + 1
  
  if time < freezeTimestamp {
    var pinCopy = pin
    let positionDelta = SIMD3<Float>(0, 0, -2.7)
    pinCopy.rigidBody.centerOfMass += SIMD3<Double>(positionDelta)
    
    let atomsToRender = pinCopy.atoms + socket.atoms
    for atomID in atomsToRender.indices {
      let atom = atomsToRender[atomID]
      application.atoms[atomID] = atom
    }
  } else if time < moveTimestamp {
    var progress = (moveTimestamp - time)
    progress /= (moveTimestamp - freezeTimestamp)
    
    var pinCopy = pin
    let positionDelta = SIMD3<Float>(0, 0, -2.7) * progress
    pinCopy.rigidBody.centerOfMass += SIMD3<Double>(positionDelta)
    
    let atomsToRender = pinCopy.atoms + socket.atoms
    for atomID in atomsToRender.indices {
      let atom = atomsToRender[atomID]
      application.atoms[atomID] = atom
    }
  } else {
    let atoms = interpolate(
      frames: frames,
      time: time - moveTimestamp)
    for atomID in atoms.indices {
      let atom = atoms[atomID]
      application.atoms[atomID] = atom
    }
  }
}
#else

@MainActor
func modifyAtoms() {
  var atoms = pin.atoms
  let anchorIDs = pin.handleIDs
  for atomID in anchorIDs {
    atoms[Int(atomID)].atomicNumber = 8
  }
  
  for atomID in atoms.indices {
    let atom = atoms[atomID]
    application.atoms[atomID] = atom
  }
}
#endif

@MainActor
func modifyCamera() {
  let focalPoint = SIMD3<Float>(2, 2.8, 7)
  let rotation = Quaternion<Float>(
    angle: Float.pi / 180 * cameraAngleDegrees,
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

// Enter the run loop.
if !renderingOffline {
  application.run {
    modifyAtoms()
    modifyCamera()
    
    var image = application.render()
    image = application.upscale(image: image)
    application.present(image: image)
  }
} else {
  let frameBufferSize = application.display.frameBufferSize
  var gif = GIF(
    width: frameBufferSize[0],
    height: frameBufferSize[1])
  
  // Overall latency summary for offline mode:
  //
  // throughput @ 1440x1080, 60 FPS
  // macOS: 22.8 minutes / minute of content
  // Windows: 31.3 minutes / minute of content
  //
  // throughput @ 1280x720, 60 FPS
  // macOS: 13.5 minutes / minute of content
  // Windows: 18.5 minutes / minute of content
  //
  // Costs are probably agnostic to level of detail in the scene. On macOS, the
  // encoding latency was identical for an accidentally 100% black image.
  print("rendering frames")
  for _ in 0..<(frameCount / gifFrameSkipRate) {
    let loopStartCheckpoint = Date()
    modifyAtoms()
    modifyCamera()
    
    // GPU-side bottleneck
    // throughput @ 1440x1080, 64 AO samples
    // macOS: 14-18 ms/frame
    // Windows: 50-70 ms/frame
    let image = application.render()
    
    // single-threaded bottleneck
    // throughput @ 1440x1080
    // macOS: 5 ms/frame
    // Windows: 47 ms/frame
    var gifImage = GIFModule.Image(
      width: frameBufferSize[0],
      height: frameBufferSize[1])
    for y in 0..<frameBufferSize[1] {
      for x in 0..<frameBufferSize[0] {
        let address = y * frameBufferSize[0] + x
        
        // Leaving this in the original SIMD4<Float16> causes a CPU-side
        // bottleneck on Windows.
        let pixel = SIMD4<Float>(image.pixels[address])
        
        // Don't clamp to [0, 255] range to avoid a minor CPU-side bottleneck.
        // It theoretically should never go outside this range; we just lose
        // the ability to assert this.
        let scaled = pixel * 255
        
        // On the Windows machine, '.toNearestOrEven' causes a massive
        // CPU-side bottleneck.
        let rounded = (scaled + 0.5).rounded(.down)
        
        // Avoid massive CPU-side bottleneck for unknown reason when casting
        // floating point vector to integer vector.
        let r = UInt8(rounded[0])
        let g = UInt8(rounded[1])
        let b = UInt8(rounded[2])
        
        let color = Color(
          red: r,
          green: g,
          blue: b)
        
        gifImage[y, x] = color
      }
    }
    
    // single-threaded bottleneck
    // throughput @ 1440x1080
    // macOS: 76 ms/frame
    // Windows: 271 ms/frame
    let quantization = OctreeQuantization(fromImage: gifImage)
    
    // For some reason, DaVinci Resolve imports 20 FPS clips as 25 FPS. So I
    // change delayTime to 4 when exporting to DaVinci Resolve.
    let frame = Frame(
      image: gifImage,
      delayTime: 4,
      localQuantization: quantization)
    gif.frames.append(frame)
    
    let loopEndCheckpoint = Date()
    print(loopEndCheckpoint.timeIntervalSince(loopStartCheckpoint))
  }
  
  // multi-threaded bottleneck
  // throughput @ 1440x1080
  // macOS: 252 ms/frame
  // Windows: 174 ms/frame (abnormally fast compared to macOS)
  print("encoding GIF")
  let encodeStartCheckpoint = Date()
  let data = try! gif.encoded()
  let encodeEndCheckpoint = Date()
  
  let encodedSizeRepr = String(format: "%.1f", Float(data.count) / 1e6)
  print("encoded size:", encodedSizeRepr, "MB")
  print(encodeEndCheckpoint.timeIntervalSince(encodeStartCheckpoint))
  
  // SSD access bottleneck
  //
  // latency @ 1440x1080, 10 frames, 2.1 MB
  // macOS: 1.6 ms
  // Windows: 16.3 ms
  //
  // latency @ 1440x1080, 60 frames, 12.4 MB
  // macOS: 4.1 ms
  // Windows: 57.7 ms
  //
  // Order of magnitude, 1 minute of video is 1 GB of GIF.
  let packagePath = FileManager.default.currentDirectoryPath
  let label = "\(Int(cameraAngleDegrees))"
  let filePath = "\(packagePath)/.build/video_\(label).gif"
  let succeeded = FileManager.default.createFile(
    atPath: filePath,
    contents: data)
  guard succeeded else {
    fatalError("Could not write to file.")
  }
}
