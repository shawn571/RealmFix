# Changelog

## 2.4 (2026-11-22)
- Asks at most once per realm: after you confirm a realm's name, no other character on that realm is asked.
- No popup at all for a realm in the built-in table when its name matches what Altoholic has.
- If the built-in name doesn't match Altoholic's, a popup offers Altoholic's name (filled in), the chat asks you to report it, and `/realmfix report` shows a MISMATCH line.

## 2.3 (2026-11-22)
- A realm found in Altoholic's data is no longer used automatically: a popup shows the detected name, filled in, and asks you to confirm (Confirm and reload / Not now). `/realmfix confirm` does the same.
- Warnings that the name must exactly match what Altoholic shows, or DataStore/Altoholic will create a separate realm with duplicate characters.
- `/realmfix set` is now marked advanced: a name Altoholic doesn't know needs `/realmfix set confirm`.
- Names detected by 2.2 without asking are moved back to "detected, not confirmed".
- Realm report form covers every region (Americas & Oceania, Europe, Korea, Taiwan, China).

## 2.2 (2026-11-22)
- Never guesses: `DEFAULT` is now empty, so an unknown realm stays blank instead of being filed under another realm.
- Learns realm names from DataStore's saved character list (characters it saw before the bug). On the first login after installing, it asks for one `/reload` to apply what it learned.
- New `/realmfix set <realm name>` to name the realm for the character you're playing, and `/realmfix forget <server>`.
- New `/realmfix report`: a copyable report of known realms (no character names or GUIDs) to post as a GitHub "Realm report".
- At login, tells you if the realm is unknown and what to do.

## 2.1 (2026-11-22)
- First public version. Built-in table reduced to one live realm; comments on setting your own.

## 2.0 (2026-11-20)
- Looks up the realm from the character's GUID server number and learns real names from the game.

## 1.0 (2026-11-20)
- Fixed realm name for one realm.
