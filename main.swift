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

var mmp = MMP(string: fileString)

// Ring-shaped diamondoid
//mmp.selectSubRange((UInt32(23436)...25955).map { $0 })
//mmp.selectSubRange((UInt32(42439)...45336).map { $0 })
//mmp.selectSubRange((UInt32(11757)...14276).map { $0 })

// Carbon nanotube (various positions)
//mmp.selectSubRange((UInt32(14277)...14780).map { $0 })
//mmp.selectSubRange((UInt32(14781)...15284).map { $0 })
//mmp.selectSubRange((UInt32(25956)...26483).map { $0 })

// Weird tiny piece: hole that fills mutated complex diamondoid
//mmp.selectSubRange((UInt32(26484)...27258).map { $0 })

// Unique gear
//mmp.selectSubRange((UInt32(0)...3505).map { $0 })

// Complex diamondoid
mmp.selectSubRange((UInt32(3606)...11756).map { $0 })
//mmp.selectSubRange((UInt32(34287)...42438).map { $0 })
//mmp.selectSubRange((UInt32(27259)...34286).map { $0 }) [mutated]
//mmp.selectSubRange((UInt32(15285)...23435).map { $0 }) [displaced]

print()
print("byte count:", fileData.count / 1000, "KB")
print("atom count:", mmp.topology.atoms.count)
print("bond count:", mmp.topology.bonds.count)

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

do {
  let topology = mmp.topology
  let matches = topology.match(
    topology.atoms,
    algorithm: .absoluteRadius(0.010),
    maximumNeighborCount: 30)
  
  let atomsToBondsMap = topology.map(.atoms, to: .bonds)
  
  for atomID in topology.atoms.indices {
    let atom = topology.atoms[atomID]
    let bondsMap = atomsToBondsMap[atomID]
    let bondCount = bondsMap.count
    
    let matchList = matches[atomID]
    if matchList.count > 2 {
      print(atomID, atom, bondCount, matchList)
    }
  }
}

for atomID in mmp.topology.atoms.indices {
  let atom = mmp.topology.atoms[atomID]
  application.atoms[atomID] = atom
}

@MainActor
func modifyCamera() {
  let namedView = mmp.namedViews["LastView"]
  guard let namedView else {
    fatalError("Could not retrieve named view.")
  }
  
  let rotation = Quaternion<Float>(
    angle: Float.pi / 180 * 45,
    axis: SIMD3(0, 1, 0))
  
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
  
  // NanoEngineer might be entirely orthographic projection.
  //
  // points where this breaks down
  // 1x3_beam,     20°, (350 Å) 35 nm -> 198 nm
  // 10nm_bar_pin, 10°, (140 Å) 14 nm -> 160 nm
  //
  // alternative limits to FOV
  // 1x3_beam,     35°, (350 Å) 35 nm -> 111 nm
  // 10nm_bar_pin, 20°, (140 Å) 14 nm -> 79 nm
//  let fovAngleVertical = Float.pi / 180 * 30
//  var cameraDistance = namedView.scale
//  cameraDistance /= tan(fovAngleVertical / 2)
  
  let fovAngleVertical = Float.pi / 180 * 60
  let cameraDistance = Float(20)
  
  var position = SIMD3<Float>(0, 0, 0)
  position += rotation.act(on: SIMD3(0, 0, cameraDistance))
  application.camera.position = position
  application.camera.fovAngleVertical = fovAngleVertical
}

application.run {
  modifyCamera()
  
  var image = application.render()
  image = application.upscale(image: image)
  application.present(image: image)
}
