import Foundation
import HDL
import MM4
import MolecularRenderer
import QuaternionModule
import xTB

var path = FileManager.default.currentDirectoryPath
path += "/Sources/Workspace/Diamond_Machine_Parts/Blocks/"
path += "hex_clip_pin.mmp"

let start1 = Date()
let fileData = FileManager.default.contents(atPath: path)
guard let fileData else {
  fatalError("Could not get file at path: \(path)")
}
let fileString = String(data: fileData, encoding: .utf8)
guard let fileString else {
  fatalError("Could not create string.")
}
let end1 = Date()

let start2 = Date()
let mmp = MMP(string: fileString)
let end2 = Date()

@MainActor
func profile(start: Date, end: Date) {
  let timeInterval = end.timeIntervalSince(start)

  var microsecondsPerAtom = timeInterval / 1e-6
  microsecondsPerAtom /= Double(mmp.topology.atoms.count)
  
  print("parsing latency:", Float(timeInterval / 1e-3), "ms")
  print("- throughput:", Float(microsecondsPerAtom), "μs/atom")
}

print()
print("byte count:", fileData.count / 1000, "KB")
profile(start: start1, end: end1)
profile(start: start2, end: end2)

print()
print("atom count:", mmp.topology.atoms.count)
print("bond count:", mmp.topology.bonds.count)

// TODO: Validate that the topology is correct.
