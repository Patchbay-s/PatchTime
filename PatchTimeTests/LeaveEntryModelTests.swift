import Testing
import Foundation
@testable import PatchTime

struct LeaveEntryModelTests {
    @Test func creerUneEntreeCongePayeSurPlusieursJours() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let employerID = UUID()

        let leave = LeaveEntry(context: context)
        leave.id = UUID()
        leave.date = Date(timeIntervalSince1970: 1_700_000_000)
        leave.endDate = Date(timeIntervalSince1970: 1_700_400_000)
        leave.type = "cp"
        leave.employerID = employerID
        leave.reason = "Vacances d'été"
        leave.archived = false
        leave.setValue(false, forKey: "isValidated")

        try context.save()

        #expect(leave.type == "cp")
        #expect(leave.employerID == employerID)
        #expect(leave.endDate != nil)
        #expect((leave.value(forKey: "isValidated") as? Bool) == false)
    }
}
