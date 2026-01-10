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
print("bytes count:", fileData.count)

// Parsing the string:
// - Each space separates a word
// - Omit parentheses and commas

let fileString = String(data: fileData, encoding: .utf8)
guard let fileString else {
  fatalError("Could not create string.")
}
print("character count:", fileString.count)

let lines = fileString.split(separator: "\n").map(String.init)
print("line count:", lines.count)

for line in lines[0..<100] {
  let rawWords = line.split(separator: " ").map(String.init)
  for rawWord in rawWords {
    var newCharacters: [UInt8] = []
    for character in rawWord.utf8 {
      if character == 0x28 {
        continue
      }
      if character == 0x29 {
        continue
      }
      if character == 0x2C {
        continue
      }
      newCharacters.append(character)
    }
    
    let newWord = String(decoding: newCharacters, as: UTF8.self)
    print(newWord, terminator: " ")
  }
  print()
}
