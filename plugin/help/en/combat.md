---
toc: FFG Skills
summary: Running a fight.
aliases:
- combat
- attack
- crit
---

# FFG Combat

Combat is tracked per room.  One person opens it, everyone joins, initiative gets rolled, and then attacks resolve against soak and wound thresholds.

## Getting Started

`combat/start` - open a combat in this room
`combat/join [<weapon>[/<armor>[/<range band>]]]` - join it
`combat/add <name>=<tier>[/<count>[/<weapon>]]` - add an NPC (staff)
`combat/initiative` - roll initiative and begin round 1 (staff)
`combat` - show the current state
`combat/next` - pass the turn to the next combatant
`combat/end` - close the combat (staff)

For example:

    combat/start
    combat/join Rifle/Padded/Long
    combat/add Stormtroopers=minion/4
    combat/initiative

## Attacking

`attack <target>[=<weapon>]`

The attack rolls the weapon's skill with difficulty for the target's range band, extra difficulty if you're shooting past your weapon's range, and setback for the target's armor.  Damage is the weapon's damage plus any characteristic it uses plus your net successes, minus the target's soak.

## Critical Injuries

If an attack got damage past soak and the roll has enough advantage left, a critical becomes available.  It costs the weapon's Crit rating in advantage:

`crit <roll id>=<target>`

The advantage comes off that recorded roll, so it can't also be spent on something else - see `help ffg spends`.  Criticals get worse as they stack: the injury roll adds 10 for every critical the target is already carrying.

## Adversary Tiers

NPCs come in three tiers, configured in `ffg_combat.yml`:

* **Minion** - grouped.  A group shares one wound pool sized by how many minions are in it.
* **Rival** - individual, but doesn't track strain.
* **Nemesis** - tracks wounds and strain like a PC.

## Automation

The `automation` config setting decides whether damage lands on sheets by itself:

* `suggest` (the default) - the attack reports the damage it would do and leaves the sheet alone, so a GM can adjust for the fiction.
* `auto` - wounds are written to the target as soon as the attack resolves.

Either way staff can set wounds and strain outright with `wounds <name>=<n>` and `strain <name>=<n>`.
