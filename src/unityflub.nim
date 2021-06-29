import puppy, illwill
import std/[htmlparser, xmltree, strscans, tables, strformat, strutils, os, osproc]

const
  archiveUrl = "https://unity3d.com/get-unity/download/archive"
  hubUrl = "https://public-cdn.cloud.unity3d.com/hub/prod/UnityHub.AppImage?button=onboarding-download-btn-linux"
  hubFile = "./UnityHub.appimage"
  years = ["2021", "2020", "2019", "2018", "5"]

type
  State = enum
    yearSelect
    versionSelect
  Entry = object
    url, year, subVer: string

func `$`(entry: Entry): string = entry.year & "." & entry.subver

func toGroupedTable(entries: seq[Entry]): Table[string, seq[Entry]] =
  for x in entries:
    if result.hasKeyOrPut(x.year, @[x]):
      result[x.year].add x

func getAllHubVersions(node: XmlNode): seq[Entry] =
  if node.len > 0:
    for child in node:
      result.add child.getAllHubVersions
  if node.kind == xnElement and node.tag == "a":
    var entry = Entry(url: node.attr"href")
    if node.attr"href".scanf("unityhub://$+.$+/", entry.year, entry.subVer):
      result.add entry

proc exitProc() {.noconv.} =
  illwillDeinit()
  showCursor()
  quit(0)

# Fetches and sorts the versions
let archive = fetch(archiveUrl).parseHtml.getAllHubVersions.toGroupedTable

# Get Unity Hub if it's not in this CWD
if not fileExists(hubFile):
  echo "Attempting to download UnityHub"
  let hub = fetch(hubUrl)
  writeFile(hubFile, hub)
hubFile.setFilePermissions({fpUserExec, fpUserRead, fpUserWrite})

illwillInit(fullscreen = true)
setControlCHook(exitProc)
hideCursor()

var tb = newTerminalBuffer(terminalWidth(), terminalHeight())
var
  currentState = yearSelect
  selectedVersions: seq[Entry]
  cursor = 0

while true:
  tb.clear()
  case currentState:
  of yearSelect:
    tb.write(0, 0, "Choose a major version, press Enter to confirm:")
    for i, x in years:
      if i == cursor:
        tb.setForegroundColor(fgBlue)
      else:
        tb.setForegroundColor(fgWhite)
      tb.write(1, (i + 1), x)
    case getKey()
    of W, Up, H:
      cursor = (cursor - 1 + years.len) mod years.len
    of S, Down, J:
      cursor = (cursor + 1 + years.len) mod years.len
    of Enter:
      currentState = versionSelect
      selectedVersions = archive[years[cursor]]
      cursor = 0
    of Escape, Q:
      break
    else: discard
  of versionSelect:
    tb.write(0, 0, "Choose a minor version")
    for x in 0 .. 10:
      let i = (x + cursor) mod selectedVersions.len
      if x == 0:
        tb.setForegroundColor(fgBlue)
      else:
        tb.setForegroundColor(fgWhite)
      tb.write(8, (x + 1), $selectedVersions[i])
      tb.setForegroundColor(fgWhite)
    case getKey()
    of W, Up, H:
      cursor = (cursor - 1 + selectedVersions.len) mod selectedVersions.len
    of S, Down, J:
      cursor = (cursor + 1 + selectedVersions.len) mod selectedVersions.len
    of Enter:
      discard startProcess(hubFile, getCurrentDir(), [selectedVersions[cursor].url])
      break
    of Escape, Q:
      currentState = yearSelect
    else: discard
  tb.setForegroundColor(fgWhite)
  tb.display()

exitProc()
