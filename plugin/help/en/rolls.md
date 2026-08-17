---
toc: FFG Skills
summary: Rolling abilities.
aliases:
- roll
---

# FFG Rolls

Rolling abilities simulates virtual die rolls to tell you the outcome of challenges.  You can make an open-ended roll:

`roll <dice string>`

The dice string can be either an ability name (e.g. `roll Melee`), some dice codes (see below), or a combination of the two.

You can add in extra dice to reflect bonuses and challenges.  

* Positive dice include Boost (B), Ability (A), and Proficiency (P).
* Negative dice include Setback (S), Difficulty (D) and Challenge (C).

So to roll an ability with 2 extra boost dice and 3 extra difficulty dice, you could do:  `roll Melee+2B+3D`.  To roll for a NPC, you could use dice codes like: `roll 2A+1P`.

You can also roll force dice (F) to determine the result of force talents.  For example:  `roll 2F`

## Upgrading and Downgrading

Many talents upgrade a die rather than adding one - turning an ability die into a proficiency die, or a difficulty die into a challenge die.

* `UA` upgrades your ability dice.  `roll Melee+1UA` turns one ability die into a proficiency die.
* `UD` upgrades the difficulty.  `roll Melee+2D+1UD` turns one of those difficulty dice into a challenge die.

A negative count downgrades instead, turning the stronger die back into the weaker one:  `roll Melee+2P-1UA` rolls with one of those proficiency dice knocked back down to an ability die.

If there's nothing left to upgrade, an upgrade adds a basic die instead, and a downgrade with nothing left to downgrade removes one.

## Spending Advantage and Threat

Every roll is recorded and its number shown in the result, e.g. `[roll #42]`.  See `help ffg spends` for how to spend the advantage, threat, triumph and despair it generated.

## Opposed Rolls

You can automatically factor in an opponent's skill as difficulty dice when doing an opposed skill roll.

`roll <ability>[+<other dice>] vs <character>/<ability>`

> Note: If you're just rolling against an NPC, you can factor their dice into the dice string (e.g. `roll Malee+2D+1C`) and don't need to use the opposed version of the command.