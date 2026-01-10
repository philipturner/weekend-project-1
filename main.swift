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
print("byte count:", fileData.count)

let fileString = String(data: fileData, encoding: .utf8)
guard let fileString else {
  fatalError("Could not create string.")
}
let mmp = MMP(string: fileString)

for (key, value) in mmp.namedViews {
  print(key, value)
}
