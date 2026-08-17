---
toc: FFG Skills
summary: Spending advantage, threat, triumph and despair.
aliases:
- spend
- spends
- advantage
- threat
---

# Spending Advantage and Threat

In FFG, whether you succeed is only half the story.  The advantage, threat, triumph and despair a roll generates are a currency you spend on everything from recovering strain to complicating the scene.

Every roll is recorded and its number shown in the result, e.g. `[roll #42]`.

## Seeing What You Can Spend

`spends` - options for your most recent roll
`spends <roll id>` - options for a specific roll

## Spending

`spend <roll id>=<name>`
`spend <roll id>=<name>/<target>` - for spends that affect someone else

You can use `last` in place of the roll id to mean your most recent roll:  `spend last=Recover Strain`

Some examples:

    spends
    spend 42=Recover Strain
    spend 42=Boost Ally/Neela
    spend last=Add A Fact

## Boost and Setback Dice

Spends that hand someone a boost or setback die attach it to that character.  The next check they make picks it up automatically and shows it in the roll string.

## How Long Rolls Last

Rolls are kept for a while and then cleaned up, so spend them in the scene they happened in.  How long is set by the `roll_history_hours` config setting.

## Configuration

The spend menu is entirely configurable in `ffg_spends.yml`.  Each entry sets a name, what it costs, what it does, and who it targets.  See the comments in that file for the available effects.

The `automation` setting controls how much the system does on its own:

* `suggest` (the default) - nothing mechanical happens unless somebody asks for it.  Leftover threat waits for a GM or player to decide what it means.
* `auto` - leftover threat is applied automatically when the roll resolves, using the threat entry marked `auto` in the config.
