# !RealmFix

A small, temporary add-on for **World of Warcraft: Forever**.

Since client build **1.60.1 / 71037** (dated Nov 18 2026), `GetRealmName()` and `GetNormalizedRealmName()` can return an empty string. Add-ons that store characters by realm name, such as DataStore and Altoholic, then file characters under a blank realm, create duplicate entries, and show empty tabs.

!RealmFix fills the realm name back in, so those add-ons keep working until Blizzard or the add-on authors fix it.

## How it works

- If the game returns a real realm name, !RealmFix passes it through unchanged and remembers it for that server.
- If the game returns `""`, !RealmFix looks up the realm from the character's GUID. The first number in a GUID (`Player-<server>-<id>`) identifies the realm's server.
- If it doesn't know that server number, it leaves the name blank rather than guessing, so no character is filed on the wrong realm.
- It loads before DataStore because its folder name starts with `!`.

## Install

1. Copy the `!RealmFix` folder into `World of Warcraft\_forever_\Interface\AddOns\`.
2. **Edit `!RealmFix.lua`** and set the `SEED` table to your own realms: the server number (from your character's GUID) and the exact realm name. The included entry is the author's realm; replace or extend it. Set `DEFAULT` to your main realm, or to `""` to never guess.
3. Restart the game completely, then make sure **!RealmFix** is ticked in the AddOns list at character select.

To find a character's server number, log in on that character and type `/realmfix`.

## Commands

- `/realmfix`: shows what the game returns now, which realm name is being used, and why (`game`, `guid`, `default` or `unknown`). When the game returns realm names again, it tells you so.

## Removing it

When `/realmfix` reports that the game returns the realm name again, untick !RealmFix, restart, and check your add-ons. If everything shows, delete the folder.

Duplicate characters that DataStore created under a blank realm (`Default..<Name>`) are not removed by !RealmFix. Clean them up in Altoholic or DataStore once things are working, after making a backup of your SavedVariables.

## Notes

- It replaces `GetRealmName` and `GetNormalizedRealmName`. Replacing built-in functions can occasionally cause "action blocked" errors in Blizzard's UI; if you see any, disable !RealmFix and report it.
- A short log (up to 40 entries) is saved in `RealmFixDB` to show how the name was resolved.
- Not affiliated with Blizzard Entertainment, DataStore or Altoholic.

## License

MIT, see [LICENSE](LICENSE).
