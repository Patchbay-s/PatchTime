import WidgetKit
import SwiftUI

@main
struct PatchTimeWidgetBundle: WidgetBundle {
    var body: some Widget {
        PatchTimeWidget()
        LockScreenWidget()
        if #available(iOS 17.0, *) {
            EmployerWidget()
        }
    }
}
