import Testing
import Foundation
@testable import PatchTime

struct ContractModelTests {
    @Test func creerUnContratEtLeRelierAUnEmployeur() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()

        let employer = Employer(context: context)
        employer.id = UUID()
        employer.name = "Compagnie Aparté"
        employer.kmDistanceRoundTripValue = 42.0

        let contract = Contract(context: context)
        contract.id = UUID()
        contract.type = "cddu"
        contract.startDate = Date(timeIntervalSince1970: 1_700_000_000)
        contract.endDate = Date(timeIntervalSince1970: 1_705_000_000)
        contract.weeklyContractHoursValue = 24.0
        contract.weeklyContractDaysValue = 4.0
        contract.employer = employer

        try context.save()

        #expect(contract.employer?.name == "Compagnie Aparté")
        #expect(employer.contracts?.count == 1)
        #expect(contract.type == "cddu")
        #expect(contract.weeklyContractHoursValue == 24.0)
        #expect(contract.weeklyContractDaysValue == 4.0)
        #expect(contract.kmDistanceRoundTripValue == nil)
        #expect(employer.kmDistanceRoundTripValue == 42.0)
    }
}
