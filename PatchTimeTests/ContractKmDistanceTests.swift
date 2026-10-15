import Testing
import Foundation
@testable import PatchTime

struct ContractKmDistanceTests {
    @Test func distanceDuContratPrioritaireSurCelleDeLEmployeur() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let employer = Employer(context: context)
        employer.id = UUID()
        employer.name = "Compagnie Aparté"
        employer.kmDistanceRoundTripValue = 30.0

        let contract = Contract(context: context)
        contract.id = UUID()
        contract.employer = employer
        contract.kmDistanceRoundTripValue = 12.0

        #expect(contract.effectiveKmDistanceRoundTrip == 12.0)
    }

    @Test func replisSurLaDistanceDeLEmployeurSiContratNeLaPrecisePas() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let employer = Employer(context: context)
        employer.id = UUID()
        employer.name = "Compagnie Aparté"
        employer.kmDistanceRoundTripValue = 30.0

        let contract = Contract(context: context)
        contract.id = UUID()
        contract.employer = employer
        contract.kmDistanceRoundTripValue = nil

        #expect(contract.effectiveKmDistanceRoundTrip == 30.0)
    }

    @Test func nilSiNiLeContratNiLEmployeurNOntDeDistance() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let employer = Employer(context: context)
        employer.id = UUID()
        employer.name = "Compagnie Aparté"

        let contract = Contract(context: context)
        contract.id = UUID()
        contract.employer = employer

        #expect(contract.effectiveKmDistanceRoundTrip == nil)
    }

    @Test func nilSiLeContratNAAucunEmployeur() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let contract = Contract(context: context)
        contract.id = UUID()

        #expect(contract.effectiveKmDistanceRoundTrip == nil)
    }
}
