import Foundation
import HDL
import MM4
import MolecularRenderer
import QuaternionModule
import xTB

var path = FileManager.default.currentDirectoryPath
path += "/Sources/Workspace/Diamond_Machine_Parts/Blocks/"
path += "10nm_bar_pin.mmp"

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
  applicationDesc.worldDimension = 384
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
  
//  let rotation = namedView.quat
  
  var axis = SIMD3<Float>(0.011551, -0.677199, -0.007701)
  axis /= (axis * axis).sum().squareRoot()
  var rotation = Quaternion<Float>(
    angle: Float.pi / 180 * 85.3,
    axis: axis
  )
  rotation = namedView.quat
//  rotation = rotation.normalized!
  
  /*
   
   (0.7355061, 0.011554015, -0.67737573, -0.0077030105)
   (0.735668, 0.011551, -0.677199, -0.007701)
   1.0
   1.0
   0.9999999
   SIMD3<Float>(0.08220553, -0.026984042, 0.99625003)
   SIMD3<Float>(-0.0043215957, 0.99961436, 0.027431762)
   SIMD3<Float>(-0.996606, -0.006560432, 0.08205721)
   SIMD3<Float>(-81.34206, -0.115432054, 13.531528)
   
   (0.735668, 0.011551, -0.677199, -0.007701)
   (0.735668, 0.011551, -0.677199, -0.007701)
   0.9999973
   0.99999726
   0.9999973
   SIMD3<Float>(0.08268306, -0.02697541, 0.9962094)
   SIMD3<Float>(-0.0043138918, 0.99961317, 0.02742562)
   SIMD3<Float>(-0.9965652, -0.0065651825, 0.08253482)
   SIMD3<Float>(-81.3388, -0.11581215, 13.569738)
   
   (0.7356685, 0.011551008, -0.6771994, -0.0077010053)
   (0.735668, 0.011551, -0.677199, -0.007701)
   0.9999998
   0.9999997
   0.9999999
   SIMD3<Float>(0.082683146, -0.026975445, 0.99621063)
   SIMD3<Float>(-0.0043138973, 0.9996144, 0.027425658)
   SIMD3<Float>(-0.9965665, -0.006565192, 0.08253491)
   SIMD3<Float>(-81.3389, -0.11581281, 13.569745)
   */
  
  application.camera.basis.0 = rotation.act(on: SIMD3(1, 0, 0))
  application.camera.basis.1 = rotation.act(on: SIMD3(0, 1, 0))
  application.camera.basis.2 = rotation.act(on: SIMD3(0, 0, 1))
  print()
  print(rotation)
  print(namedView.quat)
  print((application.camera.basis.0 * application.camera.basis.0).sum())
  print((application.camera.basis.1 * application.camera.basis.1).sum())
  print((application.camera.basis.2 * application.camera.basis.2).sum())
  print(application.camera.basis.0)
  print(application.camera.basis.1)
  print(application.camera.basis.2)
  
  // NanoEngineer might be entirely orthographic projection.
//  let fovAngleVertical = Float.pi / 180 * 20
  var cameraDistance = namedView.scale
  cameraDistance = 80
//  cameraDistance /= tan(fovAngleVertical / 2)
//  print(cameraDistance)
  
  var position = namedView.pov
  position += rotation.act(on: SIMD3(0, 0, cameraDistance))
  application.camera.position = position
  application.camera.fovAngleVertical = Float.pi / 180 * 20
  print(position)
}

application.run {
  modifyCamera()
  
  var image = application.render()
  image = application.upscale(image: image)
  application.present(image: image)
}
