# Changelog

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
