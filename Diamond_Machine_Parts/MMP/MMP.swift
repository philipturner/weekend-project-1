import HDL

struct MMP {
  var namedViews: [String: NamedView] = [:]
  var topology = Topology()
  
  init(string: String) {
    // Parsing the string:
    // - Each space separates a word
    // - Omit parentheses and commas
    
    let lines = string.split(separator: "\n")
    
    var pendingWord: [UInt8] = []
    for var line in lines {
      var newWords: [String] = []
      
      line.withUTF8 {
        for character in $0 {
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
      
      if newWords[0] == "csys" {
        let subsequence = Array(newWords[1...])
        let namedView = NamedView(words: subsequence)
        namedViews[namedView.name] = namedView
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
      
      if newWords[0] == "bond1" {
        let subsequence = Array(newWords[1...])
        for word in subsequence {
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
    }
  }
}
