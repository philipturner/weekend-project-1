import QuaternionModule

// Camera position information.
struct NamedView {
  var name: String
  var quat: Quaternion<Float>
  var scale: Float
  var pov: SIMD3<Float>
  var zoomFactor: Float
  
  init(words: [String]) {
    guard words.count == 10 else {
      fatalError("Unexpected word count.")
    }
    self.name = words[0]
    self.quat = Self.createQuaternion(
      words: [words[1], words[2], words[3], words[4]])
    self.scale = Float(words[5])!
    self.pov = Self.createVector(
      words: [words[6], words[7], words[8]])
    self.zoomFactor = Float(words[9])!
    
    // Unit conversions.
    scale /= 10
    pov /= 10
    
    // Fix source of rendering error.
    quat = quat.normalized!
  }
}
 
extension NamedView {
  private static func createQuaternion(
    words: [String]
  ) -> Quaternion<Float> {
    guard let real = Float(words[0]),
          let x = Float(words[1]),
          let y = Float(words[2]),
          let z = Float(words[3]) else {
      fatalError("Could not parse words.")
    }
    return Quaternion<Float>(
      real: real,
      imaginary: SIMD3(x, y, z))
  }
  
  private static func createVector(
    words: [String]
  ) -> SIMD3<Float> {
    guard let x = Float(words[0]),
          let y = Float(words[1]),
          let z = Float(words[2]) else {
      fatalError("Could not parse words.")
    }
    return SIMD3(x, y, z)
  }
}
