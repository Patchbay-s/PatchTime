# Contributing to PatchTime

Contributions are welcome. Please open an issue to discuss substantial changes before starting work.

## Development

1. Open `PatchTime.xcodeproj` in Xcode 16 or later.
2. Copy `Local.xcconfig.example` to `Local.xcconfig` and set your own Apple Developer Team ID if signing requires it. The local file is ignored by Git.
3. Build and run the `PatchTime` scheme on an iOS 18.4+ simulator or device.
4. Run the `PatchTimeTests` and `PatchTimeUITests` test targets.
5. Keep user-facing app text in French and update related documentation when behavior changes.

## Developer Certificate of Origin

By contributing to this project, you certify that you wrote the contribution or have the right to submit it under the project's license. You agree that the contribution is submitted under the GPL-3.0-or-later license and the PatchTime App Store exception described in `LICENSE`.

Sign off each commit with `git commit -s`. The `Signed-off-by` line records your certification under the Developer Certificate of Origin (DCO). Do not sign off a contribution you are not authorized to submit.

## Pull requests

Keep changes focused, explain user-visible effects, and include tests or manual verification steps where applicable. Do not include credentials, personal records, generated exports, or signing files.
