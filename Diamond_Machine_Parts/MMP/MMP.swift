import HDL

struct MMP {
  var namedViews: [String: NamedView] = [:]
  var topology = Topology()
  
  init(string: String) {
    // Parsing the string:
    // - Each space separates a word
    // - Omit parentheses and commas
    let lines = string.split(separator: "\n").map(String.init)
    for line in lines[0..<100] {
      let rawWords = line.split(separator: " ").map(String.init)
      var newWords: [String] = []
      
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
        newWords.append(newWord)
      }
      guard newWords.count > 0 else {
        continue
      }
      
      if newWords[0] == "csys" {
        let subsequence = Array(newWords[1...])
        let namedView = NamedView(words: subsequence)
        namedViews[namedView.name] = namedView
      }
      
      if newWords[0] == "atom" {
        let subsequence = Array(newWords[2...])
        let atom = Self.createAtom(words: subsequence)
        
        // WARNING: Serialized MMP files are 1-indexed.
        guard let atomID = UInt32(newWords[1]) else {
          fatalError("Could not parse word.")
        }
        guard topology.atoms.count == atomID - 1 else {
          fatalError("Unexpected topology atom count.")
        }
        topology.atoms.append(atom)
      }
      
      if newWords[0] == "bond" {
        let subsequence = Array(newWords[1...])
        for word in subsequence {
          // Using 1-index notation.
          let atomID = topology.atoms.count
          guard let otherAtomID = UInt32(word) else {
            fatalError("Could not parse word.")
          }
          guard otherAtomID < atomID else {
            fatalError("Invalid other atom ID.")
          }
        }
      }
    }
  }
}

extension MMP {
  private static func createAtom(
    words: [String]
  ) -> Atom {
    guard let element = Float(words[0]),
          let x = Float(words[1]),
          let y = Float(words[2]),
          let z = Float(words[3]) else {
      fatalError("Could not parse words.")
    }
    
    // Unit conversions.
    var position = SIMD3(x, y, z)
    position /= 10_000
    
    return Atom(
      position: position,
      atomicNumber: UInt8(element))
  }
}
