---
title: File search
description: Find files and folders through a private local index, with previews and useful-file filtering.
---

Search file and folder names in the folders you choose, using a private index stored on this Mac.

Turn it on in **Settings → File Search**. It's **off** by default. While it's off, there's no
command, and ZLaunch stops indexing and removes its index.

Open it with the **Search Files** command, its own global shortcut, or the **Search Files** row under
"Use … with" at the bottom of any launcher search. The last option opens with your text already
typed.

## Full Disk Access

File Search requires **Full Disk Access** before it indexes your configured folders.
The settings pane links to Privacy & Security and shows whether access is available.
Hidden files and bundle contents can be indexed; editable ignore patterns determine
what is excluded. No file contents are uploaded.

## The screen

With nothing typed, **Recent Files** shows up to 20 recently modified files from
ordinary home and cloud folders. It does not represent a history of opened files.

When you type, the list changes to **Results**. Each row shows the file's icon and name. Folders also
show their parent folder's name, dimmed, which helps when many folders share a name like `src`.

The right side previews the selected file: the file itself, followed by its name, location, type,
size and dates. You can play video and audio there. Nothing plays until you press play.

### Filtering by type

<kbd>⌘</kbd><kbd>P</kbd>, or the **Useful Files** button, narrows the search:

**Useful Files** · **Everything** · **Folders** · **Documents** · **Images** · **Audio** · **Videos** · **Archives**

The filter is applied during index search, before the result limit. Your selection is remembered, including after restarting the app.

Useful Files is the default. It includes documents, media, folders, source code, Markdown and common
project/configuration files. It hides generated artifacts, temporary files and logs. Everything includes
unfamiliar types and those generated files; your ignore patterns and the existing folder rules still apply.
The recent list in Useful Files omits source/configuration churn; typing searches project files normally.

## Actions

| Action                  | Shortcut                             |
| ----------------------- | ------------------------------------ |
| Open File / Open Folder | <kbd>return</kbd>                    |
| Show in Finder          | <kbd>⌘</kbd><kbd>return</kbd>        |
| Copy File               | <kbd>⇧</kbd><kbd>⌘</kbd><kbd>C</kbd> |
| Paste File to …         | <kbd>⇧</kbd><kbd>⌘</kbd><kbd>V</kbd> |
| Copy Name               | <kbd>⌥</kbd><kbd>⌘</kbd><kbd>C</kbd> |
| Copy Path               | <kbd>⌃</kbd><kbd>⌘</kbd><kbd>C</kbd> |
| Move to Trash           | <kbd>⌃</kbd><kbd>X</kbd>             |

- **Copy File** copies the file itself to the clipboard, so you can paste it into Finder or Mail.
- **Paste File to …** pastes the file into the app you opened the palette over.
- **Copy Name** and **Copy Path** keep the palette open, so you can copy several in a row.
- **Move to Trash** doesn't ask for confirmation, because you can always restore files from the
  Trash.

**Exclude Enclosing Folder** (or **Exclude Contents of This Folder**) and **Exclude .extension Files**
add ignore patterns. Remove those patterns in File Search settings to undo an exclusion.

Copies made here appear in your [clipboard history](/docs/features/clipboard) like any other copy.

## In the launcher

Turn on **Show in launcher**, under the File Search switch, to see files in launcher searches too.
It's **off** by default.

When your search has three or more characters, a **Files** section lists up to five matches. It sits
below the apps and commands, so <kbd>return</kbd> still opens the top result. Each row shows the
name, the folder it's in, and whether it's a file or a folder.

The rows have the same actions as this screen. To see every match, choose the
**Search Files** row under "Use … with".

## Search scopes

Set these in **Settings → File Search → Search Scopes**. By default, ZLaunch searches your home
folder.

The index crawls only your configured roots. Hidden files are ranked below ordinary
home files, and default ignore patterns omit common caches and private app stores.

**An empty scope list searches nothing.** ZLaunch doesn't fall back to your home folder.

Scopes are saved with your home folder written as `~`, so a backup still works on another Mac.

## Ignore patterns

Set these in **Settings → File Search → Ignore Patterns**. There are three kinds:

| Pattern          | Checked against    | Example          |
| ---------------- | ------------------ | ---------------- |
| Plain word       | Any folder or name | `node_modules`   |
| With `*` `?` `[` | Any folder or name | `*.tmp`          |
| Containing `/`   | The whole path     | `**/[Cc]ache/**` |

Matching isn't case-sensitive, and `*` also matches `/`, so a `**/…/**` pattern works as written.

The list includes shipped defaults and your additions. Defaults can be removed and restored.

## How search works

Every word you type must appear in the file name, in any order. `annual report` finds
"Report – annual 2025.pdf". Exact filename matches rank before prefixes and other matches.
Ordinary home and cloud files rank above hidden and system files.

At most **200** results are shown. The index searches immediately and coalesces pending
queries. Filesystem changes update the index; changing scopes or ignores rebuilds it.

## Messages you might see

| You see                          | It means                                     |
| -------------------------------- | -------------------------------------------- |
| Type to search files and folders | Nothing recent in your search scopes         |
| No files found                   | The search finished without a match          |
| No images found                  | The same, with the Images filter on          |
| Full Disk Access required        | Grant access before indexing                 |
| Couldn’t build the file index     | Use Rebuild Index in File Search settings     |
