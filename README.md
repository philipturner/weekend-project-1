# Weekend Project 1

Reverse-engineer all of this (EZ)

Not actually as easy as I thought. Reducing the scope from "reproduce his latest wall tile" to just the pin geometry.

Luckily, this pin has no 4-membered rings. Only 5-membered rings in the amorphous transition between crystal phases for the hooks. This means I can simulate Tom's geometry as-is with MM4. There are also no CNTs or pi bonds. That would be another thing precluding sharing of designs.

Also, because of the 5-membered rings, the mapping from diamond to silicon carbide is not trivial. But it could be possible.

_Never underestimate the person-hours cost of real engineering._

---

Tom scaled the atom positions to larger than the actual diamond lattice constant, just to make the amorphous 5-membered ring transition easier to compile. That caused problems with energy minimization. It also artificially created a lot of thermal energy.

Alternatively, AIREBO just uses an incorrect value for equilibrium C-C bond distance. And he was optimizing for ease of use with AIREBO.
