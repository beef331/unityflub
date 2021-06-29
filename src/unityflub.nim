import puppy
import std/[htmlparser, xmltree, strscans, tables, strformat, strutils, os, osproc]

const
  archiveUrl = "https://unity3d.com/get-unity/download/archive"
  hubUrl = "https://public-cdn.cloud.unity3d.com/hub/prod/UnityHub.AppImage?button=onboarding-download-btn-linux"
  hubFile = "./UnityHub.appimage"

type
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

proc subVersion(entries: seq[Entry]) =
  for i, entry in entries:
    echo fmt"{i}) {entry}"
  while true:
    let input = readLine(stdin)
    try:
      let val = parseInt(input)
      echo fmt"Installing {entries[val]}"
      discard startProcess(hubFile, getCurrentDir(), [entries[val].url])
      return
    except:
      echo "Invalid value, try again"

proc main() =
  let archive = fetch(archiveUrl).parseHtml.getAllHubVersions.toGroupedTable

  if not fileExists(hubFile):
    echo "Attempting to download UnityHub"
    let hub = fetch(hubUrl)
    writeFile(hubFile, hub)
  hubFile.setFilePermissions({fpUserExec, fpUserRead, fpUserWrite})

  while true:
    echo "Enter start version (2021, 2020, 2019, 2018, 5), then press enter."
    let input = stdin.readLine
    if input in archive:
      subVersion(archive[input])
      return
    else:
      echo "Invalid Input, try again."

main()
