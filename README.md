# !RealmFix

A small, temporary add-on for **World of Warcraft: Forever**.

Since client build **1.60.1 / 71037** (dated Nov 18 2026), `GetRealmName()` and `GetNormalizedRealmName()` can return an empty string. Add-ons that store characters by realm name, such as DataStore and Altoholic, then file characters under a blank realm, create duplicate entries, and show empty tabs.

!RealmFix fills the realm name back in, so those add-ons keep working until Blizzard or the add-on authors fix it.

## How it works

- If the game returns a real realm name, !RealmFix passes it through unchanged and remembers it for that server.
- If the game returns `""`, !RealmFix looks up the realm from the character's GUID. The first number in a GUID (`Player-<server>-<id>`) identifies the realm's server. It knows a server's name from, in order: a name the game gave earlier, a name you confirmed or set, or its built-in table.
- If it finds the realm in Altoholic's data (DataStore's saved list of characters from before the bug), it shows a popup with that name filled in and asks you to confirm it. Nothing from Altoholic is used until you confirm.
- If it doesn't know that server number, it leaves the name blank rather than guessing, so no character is filed on the wrong realm.
- It loads before DataStore because its folder name starts with `!`.

## Install

1. Copy the `!RealmFix` folder into `World of Warcraft\_forever_\Interface\AddOns\`.
2. Restart the game completely, then make sure **!RealmFix** is ticked in the AddOns list at character select.
3. Log in. If your realm isn't built in but Altoholic knows it, a popup shows the detected realm name. Check it and click **Confirm and reload**.
4. If your realm isn't known at all, please send a realm report (below) so it can be built in for everyone.

> **Warning:** the realm name must exactly match the name Altoholic shows (spelling, capitals and spaces). If it doesn't, DataStore/Altoholic will file your characters under a new, separate realm, with duplicate characters. Only change the detected name, or use `/realmfix set`, if you know exactly what you're doing.

## Commands

- `/realmfix`: shows what the game returns now, which realm name is being used, and why (`game`, `guid` or `unknown`). When the game returns realm names again, it tells you so.
- `/realmfix confirm`: accepts the realm name detected from Altoholic for the character you're playing (the same as the popup's Confirm).
- `/realmfix set <realm name>` (advanced): names the realm for the character you're playing. If the name doesn't match a realm Altoholic has saved, it warns you and asks you to repeat with `/realmfix set confirm`.
- `/realmfix forget <server number>`: removes a saved name.
- `/realmfix report`: opens a window with a report of the realms your copy knows, ready to copy (Ctrl+C).

## Help build the realm table

Reports from **every region** (Americas & Oceania, Europe, Korea, Taiwan, China) are welcome. Add-ons can't send anything over the internet, so reports are copy and paste:

1. Type `/realmfix report` and press Ctrl+C.
2. Open a **Realm report** issue at [github.com/shawn571/RealmFix/issues](https://github.com/shawn571/RealmFix/issues/new/choose) and paste it.

The report contains realm names and server numbers only: no character names, no GUIDs. Reports from players with characters created **before Nov 18 2026** on any realm are especially useful, because DataStore saved those realms' real names.

## Removing it

When `/realmfix` reports that the game returns the realm name again, untick !RealmFix, restart, and check your add-ons. If everything shows, delete the folder.

Duplicate characters that DataStore created under a blank realm (`Default..<Name>`) are not removed by !RealmFix. Clean them up in Altoholic or DataStore once things are working, after making a backup of your SavedVariables.

## Notes

- It replaces `GetRealmName` and `GetNormalizedRealmName`. Replacing built-in functions can occasionally cause "action blocked" errors in Blizzard's UI; if you see any, disable !RealmFix and report it.
- A short log (up to 40 entries) is saved in `RealmFixDB` to show how the name was resolved.
- Not affiliated with Blizzard Entertainment, DataStore or Altoholic.

## License

MIT, see [LICENSE](LICENSE).
