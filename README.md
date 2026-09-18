# AIR Viewer

**AIR Viewer** (Apple Intelligence Reports Viewer) is a native macOS app for privately exploring Apple Intelligence Report exports. It runs entirely on your Mac: reports are imported into memory, parsed locally, and never uploaded.

<img src="AIRViewer/Assets.xcassets/AppIcon.appiconset/AIRViewer-512.png" width="96" alt="AIR Viewer app icon">

## Download and install

Download `AIRViewer.dmg` from the latest [GitHub Release](../../releases/latest), open it, then drag **AIR Viewer** to **Applications**.

Until a Developer ID signing certificate and notarization credentials are configured for releases, macOS may ask you to confirm that you want to open the app. Control-click the app, choose **Open**, then confirm.

## What you can do

- Import an `Apple_Intelligence_Report.json` export from macOS, iOS, or iPadOS.
- Browse Prompts, Thread entries, readable decoded strings, Tools, and Private Cloud Compute (PCC) records.
- Search report text, model identifiers, and tool metadata; filter entries by role.
- Inspect source JSON with selectable text.
- Review large reports without sending their contents to a server.

## Export a report

1. On an Apple Intelligence-enabled device, open **System Settings → Privacy & Security → Apple Intelligence Report**.
2. Set a report duration and use Siri or another Apple Intelligence feature.
3. Choose **Export Activity** and save the JSON file.
4. Open AIR Viewer and choose **Import report**.
5. Select the exported JSON file.

If **Export Activity** is unavailable, use an Apple Intelligence feature first, then return to this screen. A longer report duration is more likely to capture useful activity.

## Your privacy

Apple Intelligence Reports can include personal prompts, messages, names, and device context. AIR Viewer keeps your report on your Mac:

- It does not upload your report.
- It does not use a database or cloud account.
- It processes the report only for the current app session.

AIR Viewer can remember a **Recent Reports** list so you can reopen files later. If the original JSON file remains at its saved location, AIR Viewer reopens it automatically. This history stores only each file’s name, import date, location, and—when macOS permits it—local access permission. It does not store a copy of the report or any parsed report content. Control-click a report in the list and choose **Forget Report** to remove its history entry.

Please keep exported report files private and do not add them to source-control repositories.

## What the sections mean

- **Prompts**: instructions and prompts sent to the model.
- **Thread**: message-like request segments grouped by role.
- **Decoded Strings**: readable text found within the export, including supported Base64 values.
- **Tools**: tool and function metadata made available to the model.
- **PCC**: Private Cloud Compute-related records and attestations.

Some records are technical and may not be readable. AIR Viewer preserves their source JSON for inspection.

## Help

AIR Viewer is a native macOS app and requires macOS 26 or later on a Mac that supports Apple Intelligence reporting. If an export will not import, ensure it is the JSON file created by **Export Activity** and try exporting again.
