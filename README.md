# Weekend Project 1

Reverse-engineer all of this (EZ)

Not actually as easy as I thought. Reducing the scope from "reproduce his latest wall tile" to just the pin geometry.

Luckily, this pin has no 4-membered rings. Only 5-membered rings in the amorphous transition between crystal phases for the hooks. This means I can simulate Tom's geometry as-is with MM4. There are also no CNTs or pi bonds. That would be another thing precluding sharing of designs.

Also, because of the 5-membered rings, the mapping from diamond to silicon carbide is not trivial. But it could be possible.

_Never underestimate the person-hours cost of real engineering._

---

Tom scaled the atom positions to larger than the actual diamond lattice constant, just to make the amorphous 5-membered ring transition easier to compile. That caused problems with energy minimization. It also artificially created a lot of thermal energy.

Alternatively, AIREBO just uses an incorrect value for equilibrium C-C bond distance. And he was optimizing for ease of use with AIREBO.

The initial strain energy is enough to raise the temperature to the following amounts. Note that each atom has 3 kT of energy: 3/2 kT in thermal kinetic energy, 3/2 kT in thermal potential energy.

| Part   | Energy (eV) | Energy (zJ) | Atom Count | Temperature (K) |
| ------ | ----------: | ----------: | ---------: | --------------: |
| pin    | 218.39      | 34990.0     | 8151       | 103.6           |
| socket | 40.13       | 6001.8      | 2898       | 53.6            |

Part of the problem, is that the pin's strain energy can only be released, if you let the handle atoms relax during the minimization. I was making the mistake of freezing them. For context, handle atoms aren't frozen during dynamics; they're just a special category distinct from anchors. Handles are the atoms on which the force is applied (net force is distributed across them).

---

No matter what I try, it just won't go in! The parts aren't made for each other! I tried messing with every variable possible, and minimizing the wobble from the constant force going off-axis.

If this specific design does work, its operation is fragile. Perhaps the act of going in the hole is just a rare thermal vibration where the prongs simultaneously move inward to avoid hitting the ring.

[Diamond pin and socket don’t become one (YouTube)](https://www.youtube.com/watch?v=VXF3BnZe0I4)
