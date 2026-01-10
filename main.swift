import Foundation
import HDL
import MM4
import MolecularRenderer
import QuaternionModule
import xTB

var path = FileManager.default.currentDirectoryPath
path += "/Sources/Workspace/Diamond_Machine_Parts/Blocks/"
path += "1x1_end_beam.mmp"

let fileData = FileManager.default.contents(atPath: path)
guard let fileData else {
  fatalError("Could not get file at path: \(path)")
}
let fileString = String(data: fileData, encoding: .utf8)
guard let fileString else {
  fatalError("Could not create string.")
}

let mmp = MMP(string: fileString)
mmp.validate()

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
  
  let rotation = namedView.quat
  application.camera.basis.0 = rotation.act(on: SIMD3(1, 0, 0))
  application.camera.basis.1 = rotation.act(on: SIMD3(0, 1, 0))
  application.camera.basis.2 = rotation.act(on: SIMD3(0, 0, 1))
  
  // NanoEngineer might be entirely orthographic projection.
  let fovAngleVertical = Float.pi / 180 * 30
  var cameraDistance = namedView.scale
  cameraDistance /= tan(fovAngleVertical / 2)
  
  var position = namedView.pov
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
