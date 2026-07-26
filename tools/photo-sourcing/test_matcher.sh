#!/bin/bash
# Compile and run the breed matcher outside the app.
#
# BreedPhotos.credit(for:) is pure string work, but it lives in a UIKit file, so
# building it for macOS needs the import swapped and a UIImage stand-in. The
# stub is never called — the test only exercises credit(for:).
set -euo pipefail
cd "$(dirname "$0")"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

sed 's/^import UIKit$/import Foundation/' ../../WutMutt/Models/BreedPhotos.swift > "$work/BreedPhotos.swift"
cp ../../WutMutt/Models/PhotoCredits.swift "$work/"
cp test_matcher.swift "$work/main.swift"

cat > "$work/Stub.swift" <<'SWIFT'
import Foundation
/// Stands in for UIKit's UIImage so the matcher compiles for macOS.
final class UIImage {
    init?(named: String) { return nil }
    init?(data: Data) { return nil }
}
SWIFT

swiftc -O "$work"/*.swift -o "$work/matchtest"
"$work/matchtest"
