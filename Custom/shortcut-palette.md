# LaunchDeck

LaunchDeck is ZLaunch's hierarchical keyboard menu. Open it with one global
shortcut, press a letter to enter a group, then another letter to run an action.
Only the current level's choices appear. Existing command IDs and saved menu
paths are retained from the initial Shortcut Palette implementation.

## Configure inside ZLaunch

Search for **Configure LaunchDeck** in the launcher.

- **Global shortcut:** choose **Change…**, then record a chord. Changes save
  immediately; existing ZLaunch shortcut conflicts are rejected. No default chord
  is assigned by the feature. The current Dev test binding is **⌃⌥⌘K**.
- **Appearance:** a separate tab contains List, Grid or Floating Tiles, key size,
  Escape behavior and repeated-shortcut behavior. Valid edits save automatically.
- **Menu editor:** select Main menu or a submenu in the compact left navigation tree.
  The right pane shows only that menu’s immediate children in Key, Name and Action
  columns. Edit keys and names directly; row options contain Move Up, Move Down and Remove.
- **Submenus:** expand arrows in the navigation tree to reveal nested submenus.
  Open a submenu from its row or select it in the tree. The breadcrumb identifies
  its location. Switching menus preserves unfinished edits; duplicate keys are
  checked against siblings, and invalid edits never replace the saved menu.
- **Adding items:** one toolbar adds actions or submenus to the selected menu.
  A new submenu is selected immediately so its contents can be added there.
- **Changing actions:** click the row’s action selector to expand the searchable,
  categorized picker inline. Selecting a destination closes it. Cancel leaves the
  current action unchanged. Websites use an address field and Use Website button.
- **Actions:** use **Add Actions…**, tick several destinations, then add the selection
  in one step. Selections persist across searches and categories; unused letters are
  assigned automatically. Cancel creates no placeholder. The picker shows remaining
  capacity and prevents exceeding 26 items. Available destinations: open an app,
  open a website, run a ZLaunch command, use an app action, or run a shortcut/workflow.
  Results are grouped by category, with categories and actions sorted alphabetically.
  Search matches action names and category names: “Window” includes Window Management
  and Window Layouts, while “window left” narrows to matching window actions.
  Existing icons help identify destinations.
- **Websites:** choose **Add Website…** in the action picker, then enter a complete HTTP(S) address. Invalid schemes and embedded
  credentials are rejected. Websites open through ZLaunch's existing browser
  dispatcher. A new unnamed website choice gets its hostname as its label.
- **App actions:** select existing extension actions or Quicklinks. Arbitrary
  internal app commands are not universally available; an integration is needed.
- **Workflows:** select existing macOS Shortcuts or custom commands exposed in
  ZLaunch. LaunchDeck does not add a workflow engine or request credentials.
- **Autosave:** valid edits save after 650 ms idle. The header reports pending,
  saving, saved or needs attention. Invalid edits never replace the saved menu.
  Closing flushes valid pending edits; unfinished edits prompt with Keep Editing
  as the default. A write failure leaves edits in the editor and reports the error.
  This close protection applies to the setup window; force termination is not recovery.
- **Remove:** confirms before removing the selected choice and any nested contents.
  Reorder arrows move choices within the current group.
- **Try LaunchDeck:** saves a valid pending edit and opens the current menu. Escape
  returns to setup. An invalid edit stays visible with guidance instead of running.

Keys are case-insensitive A–Z and unique within each group. Menus support up to
26 choices per level and six levels, with labels of 1–80 characters. Unavailable
saved actions are preserved and fail visibly rather than dispatching another
choice. A type change requires choosing a matching destination.

## Presentation

**List** uses roomy key/label rows. **Grid** uses square keycaps inside an opaque
panel. Both retain a breadcrumb and Esc/Configure controls.

**Floating Tiles** uses only separate frosted keycaps, without a visible enclosing
panel, heading, breadcrumb or footer. Its top edge uses the launcher’s 18% screen-height
margin, placing normal one-row tiles around the upper third. Tall menus stay on-screen.
Esc still works; setup remains accessible via Configure LaunchDeck. A thin edge,
soft shadow and tinted surface provide separation. Reduce Transparency selects
solid tile surfaces. The current Dev menu uses Floating Tiles / Medium.

Small/Medium/Large tiles are 128/160/192 points. Floating menus use one horizontal
row when possible, then balanced rows; incomplete rows are centered. Grid uses
up to four columns. Layout is bounded by the usable display and scrolls when
needed, rather than shrinking letters to fit many entries. Each submenu sizes
independently. Long labels use two lines; tooltips and accessibility expose the
full label. Existing configurations without presentation fields default to List.

## Keyboard and focus

The panel activates ZLaunch and claims key-window and first-responder ownership.
Invalid and held-repeat keys do nothing. Default Esc behavior goes back one level,
then closes at root. Default repeated activation closes; setup can change it to
return to root. Clicking another app closes the panel without restoring the old
app. Actions wait for focus restoration before using existing command dispatch.

Other apps/macOS can own a global chord. The recorder checks ZLaunch's own
conflicts; test the chord physically. Dev and Release use separate settings.

## Upstream integration and data

The feature lives in `Tinycast/Features/ShortcutPalette/`. Host edits are limited
to AppCore ownership/activity state, two catalog commands and their dispatcher,
small focus helpers on the existing palette controller, the generated Xcode
project and test harness registration. Existing HotKeyManager, extension runtime,
updater, sync, signing and release identity were not changed. Host edits remain
potential merge points; no zero-conflict guarantee is made.

The saved menu remains at
`~/Library/Application Support/<bundle-id>/ShortcutPalette/shortcuts.json`.
This is an implementation detail, not a setup step. It is not included in native
backup exports. Invalid data is not overwritten on load; setup can explicitly
save a repaired starter draft. Save validation precedes atomic writes.

Build using `./Custom/build.sh`. Dev output is
`build/ZLaunchDerivedData/Build/Products/Debug/ZLaunch Dev.app`, separate from
installed ZLaunch and official Tinycast. No release installation is performed.

## Verification

- Signed Debug build, signature validation, all 85 harnesses and lint passed.
- Model tests cover nested navigation/editing, duplicate/invalid keys, Esc options,
  reordering/removal, persistence, presentation/size round trips, invalid-save
  preservation and website validation. Layout tests cover 1/4/8/12/20/26 entries,
  every mode/size, and 1440×900 plus 640×480 usable-screen scenarios.
- Actual UI: nested navigation, invalid keys, Esc back/back/close, Settings action,
  List/Grid switching, Grid restart persistence, Floating mode, group/action
  creation, rename/nesting/reorder/save/reload/removal, and shortcut changes were
  checked. Command–Space was rejected; a temporary chord was saved and the
  original ⌃⌥⌘K restored.
- Website invalid-scheme rejection, valid save/reload, browser execution, app
  filtering, extension-action listing and missing-destination validation passed.
  No workflows are configured in the Dev profile, so workflow execution was not
  exercised. Temporary test entries and the browser test tab were removed.
- Eight- and twenty-entry visual fixtures with long labels were inspected; the
  real menu was restored. Independent pixel review prompted centered larger
  letters, muted labels, improved contrast, quiet chevrons, restrained shadow and
  clearer setup. The final review found no further visual redesign necessary.

Physical global activation, repeated global triggering, old-chord unbinding,
background typing isolation and external focus restoration are not proven by
app-targeted automation. Zach reported that revised physical input seemed to
work; these remain explicit physical checks. Captures render gaps white and do
not independently prove desktop transparency. Light-mode, reduced-transparency
and busy-background runtime checks remain unverified; the fallback is implemented.

## Final setup and keycap review

Menu structure sits in a distinct sidebar, with a contextual editor alongside it.
Appearance has its own tab. There is no Save button. App icons reuse AppIconView and
IconCache at 24 points in the picker and 16 points alongside application tile labels.

Actual UI checks covered immediate-close autosave and reopen persistence, invalid
key rejection, incomplete-action/group close protection, safe default Return,
navigation with an unfinished action, removal confirmation, and preview/Escape return.
The independent reviewer inspected the final Menu, Appearance and protected-close
screens and found no meaningful visual blocker. All 85 harnesses pass, including
invalid-save preservation and write-failure tests; the signed build and lint pass.
Temporary QA choices were removed. The user's D/C/N/S menu remains intact.

Floating groups use a small stacked-square mark. Two soft shadows and 40-point
outer padding give the shadow room. Window captures show stronger unclipped shadows;
the capture service composites transparent regions onto white, so appearance against
the actual desktop still needs human confirmation.

## Emoji / Clipboard handoff

Clipboard → E maps to command:search-emoji and should open the searchable emoji and
symbol picker. It does not immediately insert a character. The picker offers pasting
into the original target application after the user selects a result.

A reproduced LaunchDeck bug made the picker disappear during the external focus
round-trip. Built-in Emoji and Clipboard pickers now hand off directly, retaining
the original paste target for the next palette presentation. Existing launcher
command dispatch still opens them. Actual LaunchDeck → C → E displayed the picker,
retained its target caption, and returned results for “rocket”; no paste was sent.
Other actions retain the guarded focus restoration path.

## Local production build 7 verification

The nested editor and batch picker were installed in `/Applications/ZLaunch.app`
as version 0.1.5 build 7 from source `cfdc2a4`. Apple notarization and Gatekeeper
accepted the build. All 85 harnesses, lint, model purity, and Debug/Release builds
passed. Tree tests cover nested identities and navigation after reordering; batch
tests cover unused keys, target isolation, and atomic rejection of overflow or
invalid actions. Placement tests cover upper-screen alignment and tall menus.

Production UI checks confirmed the expanded Window submenu, editing its Left Half
action without changing screens, Window Management results for “Window”, combined
“window left” search, and two checkbox selections retained across searches. Cancel
left the saved menu byte-identical; no duplicate test actions were added. Actual
floating frame (944 × 240 at x=1208, y=366 in screen coordinates) matched the launcher’s
18% top margin on the main display. Batch committing is covered by the model harness;
the production UI selection/cancel path was exercised without inserting test data.

The user's Left Half and Right Half actions were saved before installation. The
previous app, menu, and local release receipt are retained under the ignored
`build/launchdeck-production-receipt/` directory. No new GitHub binary release was published.

## Inline editor production verification

Local production version 0.1.5 build 9, source `0dd32a7`, replaces the separate
action editor with one collapsible menu. Row identities are transient UUIDs so
renaming keys, reordering siblings, and editing descendants do not redirect edits.
The saved JSON format and existing menu contents are unchanged.

`Custom/check.sh` passed all 85 harnesses, lint, model purity, configuration checks,
and Debug compilation. The final validation-status correction passed Debug/Release
builds and lint. Apple accepted notarization and the installed app passed Gatekeeper.
Production UI verification covered nested expansion, editable key/name fields,
inline action search and reselection, duplicate-key messages, rejection of invalid
autosaves, and immediate clearing of the warning after restoring the original key.
The menu file remained byte-identical to the pre-install backup. Build 7 rollback
and the release receipt are in ignored `build/launchdeck-inline-receipt/`.
