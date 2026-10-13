# Rangeln Worldwide Loot Tracker
Tracks raid loot

## Slash-Commands
 * /rwloottracker
 * /rwl

## Functions
 * Loot tracking in raids based on difficulty
 * Calendar with loot history
 * Loot-View is optimized for copy-paste into calculation sheets (Google Sheet, MS Excel, ...)

## Overview and export
Open the calendar with /rwl. Select a day to see its loot entries in a paged
overview. Hover over an item for the game tooltip. Click a loot row to add a
comment or transfer the item to another player. The "Für Sheets exportieren"
button opens the selected day's tab-separated data; press Ctrl+C and paste it
into Google Sheets. "Kommentar" is the first export column; the previous
13 columns follow in their original order.

The minimap button uses the addon logo: left-click opens the loot calendar,
right-click opens addon options, and dragging moves it around the normal minimap.
When a UI addon groups the button, that UI addon controls its position.
Its position and visibility are saved in addon options. The options group
general controls, raid difficulties, the raid-leader filter, and maintenance.
The button uses LibDBIcon 1.0 with LibDataBroker, CallbackHandler and LibStub
bundled in the addon; no separately installed library is needed. The saved
visibility is applied after ADDON_LOADED and at PLAYER_LOGIN. A disabled
button is hidden, and collectors can finish closing an open flyout before
the visibility change is applied to their layout. The previous button angle
is migrated once to LibDBIcon's saved minimap position. EllesmereUI's flyout
can raise its black backdrop above a button's direct texture after a click;
the library-owned icon sits in a deeper child frame to keep it visible.

New drops reference a compact snapshot of the raid roster from when the winner
was recorded. Identical rosters on the same day share one snapshot. Thus a
recipient can still be selected after the raid disbands. Old entries lack that
historical roster: the editor offers winners from that day, a search among
known players in the database, and manual name entry. A manually entered
recipient without a known GUID is exported with an empty GUID. Original winner
details are kept with a transferred entry; roll method and roll value continue
to describe the original loot roll.

If an item changes hands several times, its automatic comment still names the
initial winner. Selecting that initial winner again restores the original
player details and removes the automatic transfer comment. Manually written
notes remain until removed in the editor.
