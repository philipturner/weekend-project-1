import HDL

struct MMP {
  var namedViews: [String: NamedView] = [:]
  var topology = Topology()
  
  init(string: String) {
    let lines = string.split(separator: "\n")
    
    // Parsing the string:
    // - Each space separates a word
    // - Omit parentheses and commas
    var newWords: [String] = []
    var pendingWord: [UInt8] = []
    for var line in lines {
      newWords.removeAll(keepingCapacity: true)
      
      line.withUTF8 { utf8 in
        for character in utf8 {
          if character == 0x20 {
            newWords.append(String(
              decoding: pendingWord, as: UTF8.self))
            pendingWord.removeAll(keepingCapacity: true)
            continue
          }
          
          if character == 0x28 {
            continue
          }
          if character == 0x29 {
            continue
          }
          if character == 0x2C {
            continue
          }
          pendingWord.append(character)
        }
        if pendingWord.count > 0 {
          newWords.append(String(
            decoding: pendingWord, as: UTF8.self))
          pendingWord.removeAll(keepingCapacity: true)
        }
      }
      guard newWords.count > 0 else {
        continue
      }
      
      if newWords[0] == "atom" {
        var position = SIMD3(
          Float(newWords[3])!,
          Float(newWords[4])!,
          Float(newWords[5])!)
        position /= 10_000
        
        let element = Float(newWords[2])!
        let atom = SIMD4(position, element)
        
        // Using 1-indexed notation.
        guard let atomID = UInt32(newWords[1]) else {
          fatalError("Could not parse word.")
        }
        guard topology.atoms.count == atomID - 1 else {
          fatalError("Unexpected topology atom count.")
        }
        topology.atoms.append(atom)
      }
      
      else if newWords[0] == "bond1" || newWords[0] == "bondg" {
        for word in newWords[1...] {
          // Using 1-indexed notation.
          let atomID = UInt32(topology.atoms.count)
          guard let otherAtomID = UInt32(word) else {
            fatalError("Could not parse word.")
          }
          guard otherAtomID < atomID else {
            fatalError("Invalid other atom ID.")
          }
          
          let bond = SIMD2(
            atomID - 1,
            otherAtomID - 1)
          topology.bonds.append(bond)
        }
      }
      
      else if newWords[0] == "csys" {
        let subsequence = Array(newWords[1...])
        let namedView = NamedView(words: subsequence)
        namedViews[namedView.name] = namedView
      }
    }
    
    // Remove troublesome zero atoms from the graphene nanotube mesh.
//    var removedIDs: [UInt32] = []
//    for atomID in topology.atoms.indices {
//      let atom = topology.atoms[atomID]
//      if atom.atomicNumber == 0 {
//        removedIDs.append(UInt32(atomID))
//      }
//    }
//    topology.remove(atoms: removedIDs)
  }
  
  mutating func selectSubRange(_ atomIDs: [UInt32]) {
    let setIncluded = Set(atomIDs)
    
    var removedIDs: [UInt32] = []
    for atomID in topology.atoms.indices.map(UInt32.init) {
      if !setIncluded.contains(atomID) {
        removedIDs.append(atomID)
      }
    }
    topology.remove(atoms: removedIDs)
  }
  
  // Validate that the topology is correct.
  func validate() {
    let atomsToBondsMap = topology.map(.atoms, to: .bonds)
    for atomID in topology.atoms.indices {
      let atom = topology.atoms[atomID]
      let bondsMap = atomsToBondsMap[atomID]
      
      func expectedBondCount(atomicNumber: UInt8) -> ClosedRange<Int> {
        if atomicNumber == 6 {
          return 3...4
        } else if atomicNumber == 1 {
          return 1...1
        } else {
          fatalError("Unexpected atomic number: \(atomicNumber)")
        }
      }
      let expected = expectedBondCount(atomicNumber: atom.atomicNumber)
      let actual = bondsMap.count
      guard expected.contains(actual) else {
        // Instead of registering 3 bonds, it seems to not annotate conjugated
        // sp2 structures at all.
        print("WARNING: Invalid atom. ID \(atomID), expected \(expected), actual \(actual)")
        continue
      }
    }
  }
}
