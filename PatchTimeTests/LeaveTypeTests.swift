import Testing
import Foundation
@testable import PatchTime

struct LeaveTypeTests {
    @Test func lesValeursBrutesNeCollisionnentJamaisAvecOvertimeEntryTypeRecup() async throws {
        // OvertimeEntry.type == "recup" est un concept différent et déjà existant (réduit le
        // solde d'heures sup) — LeaveType.recuperation doit rester distinguable dans le code
        // même si les deux mots français se ressemblent. Voir design doc, constat d'audit.
        #expect(LeaveType.recuperation.rawValue != "recup")
        #expect(LeaveType.congePaye.rawValue == "cp")
    }

    @Test func bridgeParDefautSurCongePayeSiValeurInconnueOuAbsente() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let leave = LeaveEntry(context: context)
        leave.id = UUID()
        leave.type = nil

        #expect(leave.leaveType == .congePaye)

        leave.type = "valeur-inattendue"
        #expect(leave.leaveType == .congePaye)

        leave.leaveType = .recuperation
        #expect(leave.type == "recuperation")
    }
}
