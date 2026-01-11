import Foundation
import HDL
import MM4
import MolecularRenderer
import QuaternionModule
import xTB

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

func createPin()

let pin = createPart(range: <#T##ClosedRange<UInt32>#>)
let pinTopology = createPart(range: 3606...11756)
let socket6Topology = createPart(range: 23436...25955)
let socket7Topology = createPart(range: 42439...45336)

// TODO: Abstract this away into separate files, "Pin.swift" and
// "Socket.swift". Each accepts the raw topology and encapsulates the
// atom selection.


// MARK: - Run Simulation

// Create a rigid body to assist in simulation setup.
func createRigidBody(
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

// MARK: - Launch Application

@MainActor
func createApplication() -> Application {
  // Set up the device.
  var deviceDesc = DeviceDescriptor()
  deviceDesc.deviceID = Device.fastestDeviceID
  let device = Device(descriptor: deviceDesc)
  
  // Set up the display.
  var displayDesc = DisplayDescriptor()
  displayDesc.device = device
  displayDesc.frameBufferSize = SIMD2<Int>(1620, 1620)
  displayDesc.monitorID = device.fastestMonitorID
  let display = Display(descriptor: displayDesc)
  
  // Set up the application.
  var applicationDesc = ApplicationDescriptor()
  applicationDesc.device = device
  applicationDesc.display = display
  applicationDesc.upscaleFactor = 3
  
  applicationDesc.addressSpaceSize = 4_000_000
  applicationDesc.voxelAllocationSize = 500_000_000
  applicationDesc.worldDimension = 64
  let application = Application(descriptor: applicationDesc)
  
  return application
}
let application = createApplication()

@MainActor
func modifyAtoms() {
  for atomID in pinTopology.atoms.indices {
    let atom = pinTopology.atoms[atomID]
    application.atoms[atomID] = atom
  }
  
  for atomID in socketTopology.atoms.indices {
    let atom = socketTopology.atoms[atomID]
    
    let offset = pinTopology.atoms.count
    application.atoms[offset + atomID] = atom
  }
}

@MainActor
func modifyCamera() {
  let focalPoint = SIMD3<Float>(2, 2.5, 7)
  let rotation = Quaternion<Float>(
    angle: Float.pi / 180 * 90,
    axis: SIMD3(0, 1, 0))
  let cameraDistance: Float = 20
  
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
  application.camera.fovAngleVertical = Float.pi / 180 * 60
  
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
