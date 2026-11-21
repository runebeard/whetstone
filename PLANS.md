# Whetstone Beta 5 Recovery Plan

Work in this recovery checkout on `recovery/beta5`. Use the [Beta 5 release notes](recovery/Beta5-Release-Notes.txt), [recovery notes](RECOVERY.md), and the original APK when available. Custom-pack support and the post–Beta 5 in-app Homebrew Builder are outside this plan. The checklist covers the 12 app areas previously identified from the APK and release notes.

Run `flutter analyze` and the relevant Flutter tests after each implementation item. Check off an item when its relevant checks pass. Compare workflows with the APK where available and record reconstructed rules when the original behavior is uncertain.

## 1. Built-in character creation

- [x] Add built-in class selection to detailed creation with level-one HP, proficiency bonus, and class saving throws. Widget assertions passed for a Fighter with Constitution 16. Flutter reported a nonzero process exit after the test passed.
- [x] Add class skill lists and selection limits for the twelve built-in classes. Fighter widget assertions passed for eligibility and the two-choice cap. Flutter returned a nonzero process exit after reporting success.
- [x] Add level-one spell slots and Pact Magic to built-in creation, plus Bardic Inspiration, Lay on Hands, and Innate Sorcery pools. Dart analysis and focused resource recovery tests passed.
- [x] Add level-one Rage and Second Wind pools with one use recovered on a short rest. All five rest tests passed.
- [ ] Restore remaining built-in class features, equipment, and resources. Add species, background, and origin feat selection and apply their bonuses and proficiencies.
- [ ] Validate required choices and persist the results through edits, vault reloads, and portable exports. Keep manual creation available.

## 2. Ability scores and Quick Create

- [x] Verify Standard Array, Point Buy, and 4d6-drop-lowest generation in detailed creation. Flutter widget coverage passed.
- [x] Restore Standard Array swapping, preserving all six values until the user switches to manual editing. The APK exposes an array swap handler, and the Flutter widget test passed. The original interaction was reconstructed from compiled symbols.
- [ ] Restore Quick Create for built-in classes, including class and origin choices, spells, equipment preferences, review, and handoff to detailed customization.

## 3. Built-in advancement

- [ ] Restore built-in class and subclass advancement, including prerequisites, feature grants, proficiency and HP progression, and eligible multiclass entry where supported by the APK.
- [x] Add per-class subclass selection from level 3, with one Basic Rules subclass per built-in class. Persist selections and display them on Profile. The full subclass catalog and remaining feature grants are open.
- [x] Apply the Champion's 19–20 weapon critical range, increasing it to 18–20 at Fighter level 15, and apply Remarkable Athlete initiative and Athletics advantage. Log the optional movement on a critical hit for the table to resolve.
- [x] Apply Champion Survivor at Fighter level 18. Defy Death rolls with advantage and recovers 1 HP on 18–20. Heroic Rally heals a conscious Bloodied Champion when Next Turn starts their turn.
- [x] Apply Mindless Rage at Berserker level 6. Remove Charmed and Frightened on activation and prevent either condition from taking effect while raging. Focused Rage and death-save widget tests passed.
- [x] Calculate fixed level-up HP from each class's Hit Die and Constitution modifier, with the minimum gain per level. Keep current HP and allow manual changes to maximum HP.
- [x] Apply the level-based proficiency bonus from the same advancement control while allowing manual adjustments.
- [x] Validate ability score prerequisites when adding a new built-in class. Existing allocations remain editable. Focused advancement tests verified the level-up defaults and acceptance and rejection of new class levels.
- [x] Add manual class-level allocation in Advance Character for mixed Hit Dice. Validate that the primary class retains at least one level and verify the resulting die sizes through the short-rest workflow. Automatic multiclass grants and spell slots remain separate items.
- [x] Scale Rage uses with Barbarian levels and use Barbarian levels for the existing Rage automation.
- [x] Scale Second Wind uses and healing with Fighter levels. The advancement widget test verified that the previous expenditure carries over.
- [x] Show Tactical Shift after a level-5 Fighter uses Second Wind in combat. Players resolve movement at the table.
- [x] Add the Fighter's Indomitable pool and optional failed-save reroll with the Fighter-level bonus. Focused tests verified that declining preserves the use and accepting spends it. Both Fighter feature names appear in the APK.
- [x] Add Action Surge with a separate non-Magic action, a once-per-turn limit, and short-rest recovery. Turn state survives a reload. Weapon attacks can be marked manually on the extra Action chip.
- [x] Restore Tactical Mind for the latest skill check. The player enters the failed DC, and Second Wind is spent only if the d10 bonus turns the check into a success.
- [x] Scale Lay on Hands capacity with Paladin levels.
- [x] Restore Bardic Inspiration short-rest recovery at Bard level 5.
- [x] Apply Lay on Hands healing and Poisoned removal to the current character, with combat Bonus Action and pool accounting. Record healing and cleansing for allies to apply at the table.
- [x] Restore Font of Inspiration spell slot conversion at Bard level 5 and Superior Inspiration recovery on initiative at Bard level 18. Focused combat tests passed.
- [x] Add separate Cleric and Paladin Channel Divinity pools, with level-based capacities and rest recovery. Specific Channel Divinity effects still resolve at the table. Resource rules were reconstructed from the 2024 class tables.
- [ ] Restore level-up choices for feats, ability increases, and spells. Preserve previous choices and live HP, resources, equipment, and spell state when saving.
- [x] Offer Ability Score Improvement when advancement crosses a built-in class milestone. Choose +2 to one score or +1 to two under the score cap, retain existing choices, and apply Constitution HP and Dexterity initiative adjustments while preserving current HP and spent resources. The focused advancement tests passed. Other feats and spell choices remain open.

## 4. Spell slots

- [x] Verify tracked casting, cancellation, upcasting and save reloads in combat, plus progression and rest recovery for Wizard, Paladin and Warlock pools. The widget and rules tests passed.
- [x] Derive multiclass spell slots from built-in class levels in Advance Character.
- [x] Track and spend Pact Magic separately when both kinds of slot are available, including slots of the same level.
- [x] Preserve spent slots during advancement, including migration from single-class Pact Magic. Verify short-rest and long-rest recovery for both pools.

## 5. Scrolls, free casts, and summons

- [ ] Confirm full spell scroll eligibility and behavior against the Beta 5 APK. The player confirms the spell is eligible and whether an ability check is needed. Casting uses the scroll inventory and leaves spell slots intact.
- [x] Recognize level-labeled and cantrip scrolls alongside spell-named inventory entries.
- [x] Let players select which matching scroll stack to use.
- [x] Roll the spellcasting ability check at the scroll's DC when requested, and consume the scroll on failure.
- [x] Use the scroll's fixed attack bonus for spell attack rolls.
- [x] Keep a scroll attack's spell level for its follow-up damage roll, avoiding a second slot-level choice or slot expenditure. The focused test covered casting from the Spellbook and rolling damage after entering combat.
- [x] Show the scroll's save DC in the casting prompt and target save dialog. Focused scroll, slot, and free-cast tests passed.
- [ ] Verify the existing per-spell free-cast resource. Restore built-in feature-granted free casts and their limits, recovery periods, and eligibility.
- [x] Add manual spell summon tracking in the Spellbook. Save one named creature or group per spell, allow dismissal, and clear linked summons when concentration ends or the spell is removed. Focused widget tests passed. Original APK workflow and automatic casting integration remain unverified.

## 6. Concentration targets

- [x] Verify concentration target transfer and reload, including preservation of the original slot and timer. Flutter widget coverage passed.
- [x] Restore spell-specific target transfer for Hex and Hunter's Mark. A combat transfer spends a Bonus Action, keeps the slot and duration, and leaves the repeat-effect roll available. Reconstructed from APK symbols and spell text. The user confirms the tabletop trigger by moving the target. The focused widget test passed.

## 7. Weapons and ammunition

- [x] Restore weapon categories, properties, and structured ranges in the editor, details, and character saves. Focused tests passed for metadata round-trip and a two-handed critical. Properties are stored as descriptive text in this rebuild.
- [x] Link ammunition to inventory by item name, show available quantity, and spend one item when the attack is rolled. The widget test passed for depletion, blocked attacks, replenishment, and save reload. Damage-only rolls do not spend ammunition.

## 8. Weapon Mastery

- [x] Add persistent Weapon Mastery selection in the weapon editor for classes with the feature. Editor widget assertions and portable-save coverage passed. The editor test process exited nonzero after reporting success.
- [x] Limit mastery assignments by class level and distinct standard weapon types in the editor and advancement. Use the mastery property associated with the standard weapon name. Analysis and both focused tests passed.
- [x] Restore one mastery replacement after a long rest and enforce standard-weapon eligibility for built-in classes, including Rogue restrictions. The focused widget test passed. Selection uses exact normalized standard weapon names and the current weapon list.
- [ ] Restore remaining supported mastery effects and their timing. Graze, Push, Sap, Slow, Topple, and Vex have effect prompts. Automatic follow-up or expiry for target effects remains open.
- [x] Record Graze as typed damage from the attack ability modifier after a confirmed miss, without rolling weapon dice or adding other damage bonuses. Resolve Topple saves with failed, successful, or deferred outcomes in the timeline; target rolls, immunities and conditions remain at the table. Analysis and all six focused mastery widget tests passed. Mechanics reconstructed from the 2024 Basic Rules equipment chapter.
- [x] Resolve Nick with a different owned Light weapon, separate attack and damage rolls, no Bonus Action, and a saved once-per-turn limit. Preserve the original critical, omit positive ability damage bonuses, keep negative modifiers, and allow cancellation without spending the use. APK contains the Nick name; behavior reconstructed from the 2024 Basic Rules equipment chapter. Analysis and all 167 Flutter tests passed. Attack-action eligibility and any prior manual Light extra attack are player-confirmed; authored ammunition-using Nick weapons are excluded.
- [x] Resolve Cleave’s extra attack and damage after a confirmed hit, preserving the original attack’s critical damage. Save the once-per-turn limit across reloads and reset it on the next turn. Focused mastery and critical-hit tests passed.

## 9. Combat action availability

- [ ] Extend the current spell and universal-action checks to attacks, class features, and other actions supported in Beta 5. Account for extra attacks and features that change action availability.
- [x] Spend an Action for weapon attacks, persist the remaining attacks, and reset at turn/encounter transitions. Apply class-based Extra Attack (Fighter 5/11/20 and Barbarian, Monk, Paladin, Ranger 5) without multiclass stacking; Action Surge grants another Attack action. Ready Reactions and Nick/Cleave attacks do not consume or grant these attacks. Missing ammunition and damage-only rolls preserve Actions. Show the live attack budget. Analysis and all 179 Flutter tests passed. Extra Attack names were confirmed in the APK; mechanics reconstructed from the 2024 Basic Rules. Pact weapon invocations and other special attack features remain open.
- [x] Verify that canceling spell-slot selection preserves the Action and slot, a cast spends each once, and turn and encounter transitions reset action use. The combat widget test passed.

## 10. Universal and Readied Actions

- [x] Add basic Strength-based Unarmed Strike damage, Grapple, and both Shove outcomes to combat. Share the Attack action/Extra Attack budget with weapons, allow cancellation before spending an attack, use fixed damage (including Rage) without critical dice, and record target-selected Strength/Dexterity saves and outcomes. All 15 focused unarmed/attack-budget tests passed and analysis is clean. Feature names occur in the APK; mechanics reconstructed from the 2024 Basic Rules glossary. Target eligibility, rolls, immunity and conditions remain table-confirmed; Monk-specific options and readied unarmed effects remain open.
- [ ] Restore the remaining Beta 5 universal actions and effect automation. Confirm the original action list and compare outcomes with the APK.
- [x] Roll and log the Hide action's Stealth check and show whether it meets DC 15. The player and GM confirm whether hiding is possible and apply the result.
- [x] Let the player choose and roll a Wisdom skill for Search. Closing the skill picker leaves the Action available.
- [x] Add Study and roll the selected Intelligence skill. The focused combat test verified Hide, Search, Study, and their Action costs. Reconstructed the checks from the 2024 rules.
- [x] Add Influence with a choice of social skill or resolution without a roll when the GM calls for none.
- [x] Add Utilize with inventory selection and a session log entry. Resolve item effects at the table.
- [x] Apply Dodge until the next turn, with Dexterity save advantage and an explanation of incoming attack disadvantage. Clear the effect on combat exit and when tracked conditions end its benefits.
- [x] Track Dash for the current turn and log the extra-movement rule. Movement distance is resolved at the table.
- [x] Track Disengage for the current turn, show its opportunity attack rule, and retain it on reload until the turn advances.
- [x] Add the two Help options and log the selected benefit for allies to apply at the table. The focused combat widget tests passed.
- [x] Verify Ready and Trigger, Reaction expenditure, turn expiry, and persistence. Flutter widget coverage passed.
- [ ] Compare Readied Action effect resolution against the original APK and restore missing behavior.
- [x] Let Ready store a selected weapon attack or movement alongside the trigger, preserving free-text plans from earlier saves.
- [x] Resolve a readied weapon attack when the Reaction is spent, using the normal attack roll and ammunition rules.
- [x] Log readied movement when triggered and verify selected effects survive reload and clear on trigger or turn expiry. Movement distance is resolved at the table.

## 11. Class feature automation

- [x] Automate Second Wind healing, resource expenditure, and combat Bonus Action availability. The focused widget assertions passed. Flutter returned a nonzero process exit after reporting success.

- [x] Restore basic Rage activation, tracked uses and Bonus Action expenditure, weapon-attack extension, turn expiry, and concentration and casting restrictions. Dart analysis and the focused activation and expiry widget test passed.
- [x] Apply Rage resistance to selected bludgeoning, piercing, or slashing damage before temporary HP. Dart analysis and the focused Rage widget assertions passed. Flutter returned a nonzero process exit after reporting success.
- [x] Apply Rage advantage to Strength skill checks and saving throws, canceling selected disadvantage. Add a Bonus Action to extend Rage. Dart analysis and focused dice and Rage tests passed.
- [x] Apply level-scaled Rage damage to weapons marked as using Strength, including versatile damage. Analysis and all nine portable character tests passed.
- [x] Record a confirmed enemy saving throw on the current turn to extend Rage without a Bonus Action. Preserve cancellation and save elapsed Rage rounds across reloads; repeated extensions stop at 100 combat rounds. Ending Rage clears its elapsed counter. Analysis and all 20 focused Rage/rest tests passed. Reconstructed from the 2024 Basic Rules; elapsed time outside combat remains table-tracked.
- [ ] Restore the remaining Rage extension triggers and higher-level features. Reconstructed Persistent Rage duration and its optional once-per-long-rest initiative recovery, plus automatic Relentless Rage saves, increasing DC, and rest reset. The names appear in the APK and the focused Rage tests passed. Other extension triggers and higher-level interactions remain open.
- [x] Restore Wild Shape selection, resource expenditure, active form tracking, and reversion. Supports the four suggested forms and manual entry for another known Beast. The table tracks eligible known forms, duration, Beast statistics, and Beast Spells material restrictions.
- [x] Apply Druid Wild Shape use progression, one-use short rest recovery, long-rest refill and reversion, and Evergreen Wild Shape initiative recovery at level 20. Focused widget and rest tests passed.
- [x] Restore both Wild Resurgence exchanges from the Wild Shape resource menu at Druid level 5. Enforce the combat turn limit for slot-to-use conversion, track the generated level-1 slot separately, and reset slot creation on a long rest. Focused casting, rest, and persistence checks passed.
- [x] Add Wild Companion with Wild Shape or spell slot payment, familiar tracking, and long-rest cleanup. Add Land’s Aid with class-level dice scaling, healing, and table-resolved targets.
- [x] Restore the short-rest slot recovery portion of Natural Recovery and the Poisoned immunity portion of Nature’s Ward.
- [x] Persist Circle of the Land terrain selection, allow a change after a long rest, and apply Nature’s Ward resistance to the selected damage type.
- [x] Add Nature’s Sanctuary with Wild Shape and Action costs, ten-turn duration, and ground placement, cover, and ally resistance resolved at the table.
- [x] Move an active Nature’s Sanctuary as a Bonus Action, up to 60 feet to ground within 120 feet. Cancellation preserves the Bonus Action, movement keeps the existing duration, and the focused combat test verified that no extra Wild Shape use is spent.
- [x] Display terrain spell lists and let existing prepared Circle Spells share Natural Recovery’s once-per-long-rest free cast. Focused Druid and casting tests passed.
- [x] Add Nature Magician at Druid level 20. Convert available Wild Shape uses into a separate 2nd-, 4th-, 6th-, or 8th-level spell slot once per long rest.
- [x] Add Primal Order selection to built-in Druid creation and advancement. Save the choice, show it in Profile, and apply Magician’s Arcana and Nature bonus. Players still choose the extra cantrip and track Warden equipment training manually.
- [x] Add the Elemental Fury choice at Druid level 7 and persist it through edits and reloads.
- [x] Let players mark Druid cantrips in the Spellbook and apply Potent Spellcasting’s Wisdom damage bonus to marked cantrips.
- [x] Show the 300-foot Improved Potent Spellcasting range increase for marked cantrips with a qualifying range expressed in feet.
- [x] Roll Primal Strike’s chosen damage after a player confirms a weapon or Beast attack hit, including critical hits. Increase damage to 2d8 at Druid level 15.
- [x] Persist the once-per-turn Primal Strike limit and reset it on the next turn. Focused Elemental Fury and Druid tests passed.
- [x] Grant prepared Circle Spells automatically from the selected terrain and Druid level, including upgraded saves.
- [x] Reconcile grants on advancement and terrain changes, preserving independently owned spells and cleaning up removed grants and their spell state.
- [x] Expose granted spells in the Spellbook and combat casting with Wisdom, casting times, and concentration tracking.
- [x] Support damage rolls for the four granted cantrips and apply Potent Spellcasting automatically when eligible.
- [x] Integrate granted leveled spells with Natural Recovery’s shared free cast and verify restoration and replacement on a terrain change.
- [x] Add combat damage, upcasting, and appropriate attack or save handling for Burning Hands, Ray of Sickness, Fireball, Lightning Bolt, Blight, Cone of Cold, and Insect Plague. Insect Plague supports repeat rolls during concentration.
- [x] Add Blur and Fog Cloud effect text and concentration timers, plus Misty Step’s Bonus Action and teleport distance. The table resolves movement, positioning, and target conditions.
- [x] Add ranges, durations, save abilities, and effect guidance for Hold Person, Web, Sleep, Sleet Storm, Ice Storm, Stinking Cloud, Polymorph, Freedom of Movement, Wall of Stone, and Tree Stride. Concentration timers cover the applicable grants. Mixed Ice Storm damage and target condition resolution remain manual.
- [x] Prompt for target saves after casting Circle control spells, log the selected outcome, and support subsequent target saves from Concentration without spending another slot or action. Players apply target conditions at the table.
- [x] Resolve damaging save spells that deal no damage on a successful save. Acid Splash now prompts for the save, records zero on success, preserves the casting Action cost, and scales damage on failure.
- [x] Track self-targeted Freedom of Movement for 600 combat turns and allow nonmagical restraint escape for 5 feet of movement. Preserve the Action and spell-slot costs of the original casting.
- [x] Show AC, movement, physical scores, and attack details for the four suggested Wild Shape forms. Apply form AC and physical ability scores without overwriting the character’s normal stats.
- [x] Enforce the Beast Spells material restriction for costly or consumed components identified in saved spell text. Scrolls still bypass material components.
- [x] Handle explicitly unconsumed material descriptions in Beast Spells checks and verify portable exports preserve Druid forms, terrain, choices, and spent feature limits.
- [x] Reapply incapacitation cleanup when reopening a character. Remove expired-by-incapacitation Wild Shape, Sanctuary, Dodge, concentration, and concentration-linked summons from restored live state. Focused reload and combat tests passed.
- [ ] Complete remaining Druid parity, including other Beast stat blocks, Beast-specific proficiencies and attack automation, and the remaining leveled Circle Spell effects. Confirm full behavior against the Android APK.
- [x] Replace weapon controls with the suggested Beast form's attack while transformed. Support attack and damage rolls for Rat, Riding Horse, Spider, and Wolf, including the Rat's fixed damage. Wolf attack and damage passed the focused combat test. Spider damage is displayed as a combined total and target traits resolve at the table.
- [x] Apply the suggested Beast forms' Perception and Stealth bonuses when higher than the character's current modifier. Verify the Wolf's Perception check through normal exploration play.
- [x] Add Cat and Eagle form statistics and combat attacks. Enforce Druid level 8 for the built-in flying form, including selection by typed name. Cat Scratch keeps its fixed damage on critical hits.
- [x] Add Crab, Lizard, and Bat forms with physical scores, movement, senses, fixed-damage attacks, and Crab Stealth. Preserve form behavior across session reloads and require Druid level 8 for Bat flight. Analysis and all four focused form tests passed. Reconstructed from the 2024 Basic Rules creature stat blocks; known-form limits and original APK form coverage remain open.
- [x] Add Owl and Raven forms, with flying-form restrictions, fixed-damage attacks, skill bonuses, and form traits. Show Darkvision for the relevant built-in forms.
- [x] Apply Beast saving throw bonuses when higher than the Druid's retained bonus. Verified Cat's Dexterity save through the combat screen. The full recovery suite passed 157 tests before this focused save check, which also passed.
- [x] Prompt for Pack Tactics on Wolf attacks and apply advantage, including cancellation of selected disadvantage. Log the Wolf Bite Prone effect for eligible targets.
- [x] Spend an Action for a built-in Beast attack, respecting an available Action Surge action. Prevent attacks after the Action is spent.
- [x] Ready the active Beast attack and resolve it as a Reaction. Reject a form-specific readied attack if its form has ended, and preserve the Reaction when Pack Tactics selection is cancelled. Focused Beast and Ready tests passed.
- [x] Roll Spider Bite's poison dice separately from fixed piercing damage, including critical hits.
- [x] Persist Wild Shape's remaining combat turns, count down on Next Turn, and revert at expiry. Outside-combat elapsed time is tracked at the table.
- [x] Add elapsed-minute tracking from the Druid features menu, sharing the combat duration and automatically reverting at expiry. The focused test verified partial duration and final reversion.
- [x] Roll Ice Storm's two damage types separately, including slot scaling for bludgeoning and half damage on a successful save.
- [x] Preserve full spell casting metadata when copying Library spells, including components needed for Beast Spells checks.
- [x] Apply the Paladin Aura of Protection bonus to personal saving throws and concentration saves from Paladin level 6, using Charisma with a minimum of +1. Disable it while incapacitated, apply it after any Beast save minimum, and show the 10-foot/30-foot range at levels 6/18. Keep this derived modifier out of saved character definitions to prevent stacking on reload. Analysis and seven focused aura tests passed. Reconstructed from the 2024 Basic Rules; allied creatures remain table-tracked.
- [x] Restore Paladin Restoring Touch from level 14: combine healing and one or more condition removals in a single Lay on Hands Bonus Action. Charge five pool points per condition, validate total cost and self healing, preserve cancellation, and record ally effects for table resolution. Use compact counts for large resource pools so healing points fit narrow cards. Three Restoring Touch tests and three narrow-card tests passed. Mechanics reconstructed from the 2024 Basic Rules.
- [x] Restore Paladin Radiant Strikes at level 11 on Melee weapon and basic Unarmed Strike damage. Roll Radiant dice separately, double them on critical hits, and include confirmed Nick/Cleave extra hits. Infer standard legacy weapon names and respect explicit categories; unknown weapons must be categorized as Melee for automation. Analysis and all nine focused Radiant Strikes tests passed. Name confirmed in the APK; mechanics reconstructed from the 2024 Basic Rules.
- [x] Restore Divine Sense through Paladin Channel Divinity as a Bonus Action, with a saved ten-minute combat timer and incapacitation cleanup. Restore Abjure Foes at level 9 using one Channel Divinity and a Magic Action, Charisma-based target limits and save DC, optional outcome counts, and Rage extension. Action Surge cannot pay the Magic action. Five focused Channel Divinity tests passed. Divine Sense and Rage end on a completed Short or Long Rest, with Channel Divinity recovering the appropriate amount. Target detection, immunity, and conditions remain table-resolved; outside-combat elapsed time is table-tracked. Mechanics reconstructed from the 2024 Basic Rules.
- [x] Restore Rogue Reliable Talent from class level 7 on proficient skill checks, including universal-action checks and known Beast skill proficiencies. Preserve the natural die while using a minimum effective roll of 10, and explain the adjustment in roll history. Restore Slippery Mind Wisdom/Charisma save proficiency from Rogue level 15 without double-counting proficiency. Analysis and all eleven focused Rogue/dice tests passed. Tool checks and full APK parity remain open; mechanics reconstructed from the 2024 Basic Rules.
- [x] Restore Rogue Cunning Action from level 2 with Dash, Disengage, and Hide as Bonus Actions. Preserve the normal Action and Action Surge, share universal-action effects and Reliable Talent checks, block repeat Bonus Actions, and clear turn effects on Next Turn. Analysis and all ten focused Rogue tests passed. Hiding conditions and target visibility remain table-confirmed.
- [x] Restore Sneak Attack damage scaling by Rogue class level on eligible Finesse/Ranged weapon damage, including Nick extra hits and critical dice. Confirm hit/Advantage-or-ally eligibility at the table, preserve cancellation, and save the once-per-tracked-turn limit across reloads and edits. Next Turn resets it; a separate confirmed creature-turn boundary can refresh only Sneak Attack for off-turn use without restoring actions. Analysis and five focused Sneak Attack tests passed. Automatic enemy-turn tracking remains open.
- [x] Restore Rogue Uncanny Dodge from level 5 and Rogue/Monk Evasion from level 7 in combat and exploration damage entry. Confirm the visible-attacker hit or Dexterity-save outcome at the table, apply reductions before resistance and temporary HP, and use reduced damage for concentration DCs. Enforce combat Reaction availability across reloads and suppress these features while incapacitated. Cancellation preserves HP and actions. Six focused damage tests and two combat-card tests passed; the real phone-width flow also found and fixed attack-button overflow. Mechanics reconstructed from the 2024 Basic Rules.
- [x] Restore Cunning Strike Poison, Trip and Withdraw from Rogue level 5, two-effect Improved Cunning Strike from level 11, and Devious Strikes Daze, Knock Out and Obscure from level 14. Deduct dice before critical doubling, enforce effect-count and die budgets, require a carried Poisoner’s Kit for Poison, and record optional target save outcomes without changing the actor’s conditions. Five focused Cunning Strike tests and five Sneak Attack compatibility tests passed; target rolls, sizes, immunity and timers remain table-resolved. Reconstructed from the 2024 Basic Rules.
- [x] Restore Thief Fast Hands from Rogue level 3: pick pockets or use carried Thieves’ Tools with Sleight of Hand, or resolve Utilize / qualifying magic-item use as Bonus Actions. Share Reliable Talent and action tracking, preserve the normal Action and Action Surge, and validate subclass/tool eligibility. Seven Fast Hands tests and ten Rogue compatibility tests passed with clean analysis. Item requirements, charges and outcomes remain table-resolved.
- [x] Restore Rogue Steady Aim from level 3 with confirmed no prior movement, a Bonus Action, saved advantage for the next attack on the same turn, and a Speed 0 reminder. Preserve cancelled or ammunition-blocked attacks; clear advantage at turn boundaries and distinguish same-turn from off-turn readied attacks. Four focused tests and five Sneak Attack compatibility tests passed with clean analysis. Movement and positioning remain table-confirmed.
- [x] Restore Monk unarmed Martial Arts dice (d6/d8/d10/d12 by class level), improved Dexterity attack/damage and Grapple/Shove DCs, and a Bonus Action Unarmed Strike that preserves the Attack action. Confirm equipment eligibility at the table and retain basic Strength strikes when ineligible. Four focused tests passed, including critical dice, cancellation, multiclass scaling and persisted action costs. Martial Arts on Monk weapons remains open.
- [x] Restore Monk Focus Point progression from level 2, short/long rest recovery, and migration for existing Monks without the pool. Restore free and paid Patient Defense / Step of the Wind, Bonus Action costs, turn conditions and saved expenditures. Six focused tests passed, including depleted pools and cancellation. Movement remains table-resolved.
- [x] Restore Heightened Focus improvements for Patient Defense (two Martial Arts dice of Temporary HP, keeping the larger pool) and Step of the Wind (eligible ally movement reminder) from Monk level 10. Both Temporary HP tests passed. Flurry of Blows and its heightened attack count are tracked below.
- [x] Restore the Monk level-6 Empowered Strikes choice of Force damage for Unarmed Strike hits without changing action or damage accounting. The focused damage-selection test passed. Monk features are reconstructed from the 2024 Basic Rules; Martial Arts, Focus Points, Patient Defense and Step of the Wind names were confirmed in the original APK.
- [x] Restore Flurry of Blows from Monk level 2 with one Focus Point and a Bonus Action for two separate Unarmed Strikes, increasing to three at level 10. Persist pending strikes across reloads and character edits, preserve cancelled strike selections and the normal Attack action, and clear pending strikes on turn/encounter changes or incapacitation. Disable new Flurries when Focus or the Bonus Action is unavailable. Nine focused Flurry tests and five Monk attack compatibility tests passed with clean analysis.
- [x] Restore Warrior of the Open Hand Technique after confirmed Flurry attack hits: Addle blocks opportunity attacks until the target’s next turn; Push and Topple use the Wisdom-based Focus save DC with optional target outcomes. Grapple/Shove and misses do not trigger these hit effects. Names for Flurry of Blows, Heightened Focus and Open Hand Technique were confirmed in the original APK; mechanics reconstructed from the 2024 Basic Rules. Target saves, immunity, positioning and conditions remain table-resolved.
- [x] Restore Monk Deflect Attacks from level 3, Deflect Energy from level 13, and Slow Fall from level 4 through incoming damage entry. Confirm the attack type or falling trigger at the table; spend one available combat Reaction and reduce damage before resistance, Temporary HP and concentration checks. Cancellation preserves HP, Reaction and dice; saved Reaction expenditure blocks reuse. Six focused defense tests and six Evasion/Uncanny Dodge compatibility tests passed with clean analysis.
- [x] Offer fully deflected attack redirection for one Focus Point, preserving HP and Temporary HP and allowing players to keep Focus. Roll two Martial Arts dice plus Dexterity with the Wisdom-based Dexterity save DC; log damage for target resolution. Target range, cover, original damage type, save and immunity remain table-confirmed. Deflect Attacks, Deflect Energy and Slow Fall names occur in the original APK; mechanics reconstructed from the 2024 Basic Rules.
- [x] Restore Monk Uncanny Metabolism on the encounter’s first recorded initiative: optional full Focus recovery and Martial Arts die + Monk level healing, capped at maximum HP, once per Long Rest. Add the separate resource to creation/advancement and migrate missing Monk resources without duplicating existing pools. Restore Perfect Focus at Monk level 15 when Metabolism is declined or unavailable, raising Focus to 4 without lowering a larger pool. Seven focused tests passed with clean analysis, including rest recovery, cancellation, resource limits and reload/re-record protection. Names confirmed in the original APK; mechanics reconstructed from the 2024 Basic Rules. Initiative rerolls in an existing encounter do not refresh these benefits.
- [x] Restore Monk Disciplined Survivor from class level 14: all six ability-save proficiencies without stacking, proficiency on death saves while preserving natural 1/20 outcomes, and optional one-Focus rerolls for failed ability, concentration and death saves. Preserve the original roll mode, use the replacement even when lower, delay concentration loss and death-save counters until the final result, and leave action resources intact. Ten focused Survivor tests and six Evasion/Uncanny Dodge compatibility tests passed with clean analysis. For saves without a known DC, the player confirms failure. Name confirmed in the original APK; mechanics reconstructed from the 2024 Basic Rules.
- [x] Restore Monk Self-Restoration from class level 10 with explicit end-of-own-turn confirmation. Remove one Charmed, Frightened or Poisoned condition and its timer without spending actions or Focus; persist the turn-use limit across reloads and edits, resetting on Next Turn or encounter changes. Show the food/drink Exhaustion exception as a table reminder. Four focused tests passed with clean analysis, covering all three conditions, cancellation, unrelated conditions, class level and saved turn state. Name confirmed in the original APK; mechanics reconstructed from the 2024 Basic Rules. Outside-combat end-of-turn timing remains table-managed.
- [ ] Restore other built-in initiative, rest, and resource-triggered class effects confirmed by the APK. Barbarian Feral Instinct and Danger Sense use the 2024 rules. Both names appear in the APK and the focused initiative and Dexterity save widget test passed.

## 12. Mixed Hit Dice pools

- [x] Track available and spent Hit Dice by class die size. Attribute single-size legacy spending to the primary class and migrate it on the next spend.
- [x] Let users select die sizes during short rests, apply Constitution modifiers, stop rolling at maximum HP, and recover spent dice on a long rest. Verified the advancement-to-rest workflow and portable character round-trip.

## Release verification

- [ ] Complete Android device testing and original Beta 5 backup import checks. All 302 Flutter tests passed and analysis was clean after the Monk Self-Restoration recovery. The updated Recovery APK built successfully and passed signature/package checks. Its verified source was backed up with milestone/monk-restoration-2026-11-21; the APK is preserved locally. Android debug APK compilation and signature/package checks now pass; full device and Beta 5 parity verification remain open. No authorized Android device was connected on 21 November 2026.
- [x] Provision a workspace-local Android SDK/NDK and Flutter Android artifacts, regenerate missing plugin metadata to fix JNI registration, and build a signed debug APK. Verify its separate `com.runebeard.whetstone.recovery` package and Whetstone Recovery launcher label. Preserve the original Beta 5 APK with a verified SHA-256.
- [x] Add a repeatable Android build script using local toolchains and caches, restoring the caller environment on exit. Its dependency-refresh and cached build paths both produced verified APKs.
- [x] Verify older character and vault compatibility with representative version-one fixtures. All 20 persistence tests passed. Importing actual Beta 5 device backups remains part of Android release verification.

### Reconstruction sources

- Weapon mastery mechanics: https://www.dndbeyond.com/sources/dnd/br-2024/equipment
- Suggested Beast form statistics: https://www.dndbeyond.com/sources/dnd/br-2024/creature-stat-blocks

These sources support reconstructed mechanics; they do not establish identical Beta 5 UI or full feature parity.

- Class progression and Rage: https://www.dndbeyond.com/sources/dnd/br-2024/character-classes

- Basic Unarmed Strike, Grapple and Shove: https://www.dndbeyond.com/sources/dnd/br-2024/rules-glossary#UnarmedStrike

- Preserved original Beta 5 APK: `../beta5-evidence/Whetstone-0.1.0-beta.5-android.apk`; original SHA-256 and size are recorded in `recovery/Beta5-APK-Evidence.json`. The binary is preserved locally outside the Git checkout.

- Rogue milestone verification: `780eb88`, 237 tests passing, analysis clean, Android debug APK built and signature checked. Feature names for Reliable Talent, Slippery Mind, Cunning Action, Sneak Attack, Uncanny Dodge and Evasion were confirmed in the preserved Beta 5 APK; behavior was reconstructed from the 2024 Basic Rules.

- Rogue strikes milestone verification: `2d36287`, 253 tests passing, analysis clean, Android debug APK built and signature/package checked. Cunning Strike, Improved Cunning Strike, Devious Strikes, Fast Hands and Steady Aim names were confirmed in the preserved Beta 5 APK. Verified APK preserved locally as `outputs/Whetstone-recovery-strikes-2026-11-21-debug.apk` in the parent workspace, with SHA-256 and source provenance alongside it. Source backed up to GitHub; APK upload and device testing remain open.

- Monk core milestone verification: `5354471`, 266 tests passing, analysis clean, Android debug APK built and signature/package checked. Verified APK preserved locally as `outputs/Whetstone-recovery-monk-2026-11-21-debug.apk` in the parent workspace, with SHA-256 and source provenance alongside it. Source backed up under `milestone/monk-core-2026-11-21`; full Monk parity, Android device testing and original Beta 5 backup import checks remain open.

- Flurry milestone verification: `571f67b`, 275 tests passing, analysis clean, Android debug APK built and signature/package checked. Verified APK preserved locally as `outputs/Whetstone-recovery-flurry-2026-11-21-debug.apk` in the parent workspace, with SHA-256 and source provenance alongside it. Source backed up under `milestone/monk-flurry-2026-11-21`; device testing and full Beta 5 parity remain open.

- Monk defenses milestone verification: `fef8ec6`, 281 tests passing, analysis clean, Android debug APK built and signature/package checked. Verified APK preserved locally as `outputs/Whetstone-recovery-defenses-2026-11-21-debug.apk` in the parent workspace, with SHA-256 and source provenance alongside it. Source backed up under `milestone/monk-defenses-2026-11-21`; device testing and full Beta 5 parity remain open.

- Monk initiative milestone verification: `41e2d66`, 288 tests passing, analysis clean, Android debug APK built and signature/package checked. Verified APK preserved locally as `outputs/Whetstone-recovery-initiative-2026-11-21-debug.apk` in the parent workspace, with SHA-256 and source provenance alongside it. Source backed up under `milestone/monk-initiative-2026-11-21`; device testing and full Beta 5 parity remain open.

- Monk Survivor milestone verification: `44f806d`, 298 tests passing, analysis clean, Android debug APK built and signature/package checked. Verified APK preserved locally as `outputs/Whetstone-recovery-survivor-2026-11-21-debug.apk` in the parent workspace, with SHA-256 and source provenance alongside it. Source backed up under `milestone/monk-survivor-2026-11-21`; device testing and full Beta 5 parity remain open.

- Monk Self-Restoration milestone verification: `bbaf89c`, 302 tests passing, analysis clean, Android debug APK built and signature/package checked. Verified APK preserved locally as `outputs/Whetstone-recovery-restoration-2026-11-21-debug.apk` in the parent workspace, with SHA-256 and source provenance alongside it. Source backed up under `milestone/monk-restoration-2026-11-21`; device testing and full Beta 5 parity remain open.
