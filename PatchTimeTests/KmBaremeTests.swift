import Testing
import Foundation
@testable import PatchTime

struct KmBaremeTests {
    @Test func tranche1SousCinqMilleKm() async throws {
        let bareme = KmBareme.default2026
        // 4 CV, 3000 km : 3000 * 0.606 = 1818.0
        let result = bareme.deduction(distanceKm: 3000, fiscalPower: 4, isElectric: false)
        #expect(result == 1818.0)
    }

    @Test func tranche2EntreCinqMilleEtVingtMilleKm() async throws {
        let bareme = KmBareme.default2026
        // 5 CV, 10000 km : (10000 * 0.357) + 1395 = 4965.0
        let result = bareme.deduction(distanceKm: 10000, fiscalPower: 5, isElectric: false)
        #expect(result == 4965.0)
    }

    @Test func tranche3AuDelaDeVingtMilleKm() async throws {
        let bareme = KmBareme.default2026
        // 6 CV, 25000 km : 25000 * 0.447 = 11175.0
        let result = bareme.deduction(distanceKm: 25000, fiscalPower: 6, isElectric: false)
        #expect(result == 11175.0)
    }

    @Test func vehiculeElectriqueAppliqueUneMajorationDeVingtPourcent() async throws {
        let bareme = KmBareme.default2026
        // 4 CV, 3000 km, électrique : 1818.0 * 1.2 = 2181.6
        let result = bareme.deduction(distanceKm: 3000, fiscalPower: 4, isElectric: true)
        #expect(abs(result - 2181.6) < 0.001)
    }

    @Test func puissanceFiscaleDeTroisOuMoinsUtiliseLaPremiereTranche() async throws {
        let bareme = KmBareme.default2026
        // 2 CV traité comme 3 CV et moins : 1000 * 0.529 = 529.0
        let result = bareme.deduction(distanceKm: 1000, fiscalPower: 2, isElectric: false)
        #expect(result == 529.0)
    }

    @Test func puissanceFiscaleDeHuitOuPlusUtiliseLaDerniereTranche() async throws {
        let bareme = KmBareme.default2026
        // 8 CV traité comme 7 CV et plus : 1000 * 0.697 = 697.0
        let result = bareme.deduction(distanceKm: 1000, fiscalPower: 8, isElectric: false)
        #expect(result == 697.0)
    }

    @Test func distanceNulleDonneUneDeductionNulle() async throws {
        let bareme = KmBareme.default2026
        #expect(bareme.deduction(distanceKm: 0, fiscalPower: 5, isElectric: false) == 0.0)
    }

    @Test func cinqMilleKmPileUtiliseLaTranche1() async throws {
        let bareme = KmBareme.default2026
        // "≤ 5 000 km" -> tranche 1, pas la tranche 2. 6 CV, 5000 km : 5000 * 0.665 = 3325.0
        // (la tranche 2 donnerait (5000*0.374)+1457 = 3327.0, une différence de 2€ révélatrice
        // d'une frontière mal placée si jamais elle réapparaît).
        let result = bareme.deduction(distanceKm: 5000, fiscalPower: 6, isElectric: false)
        #expect(result == 3325.0)
    }

    @Test func vingtMilleKmPileUtiliseLaTranche2() async throws {
        let bareme = KmBareme.default2026
        // "5 001 à 20 000 km" -> tranche 2 jusqu'à et y compris 20000. 5 CV, 20000 km :
        // (20000 * 0.357) + 1395 = 8535.0
        let result = bareme.deduction(distanceKm: 20000, fiscalPower: 5, isElectric: false)
        #expect(result == 8535.0)
    }

    @Test func majorationElectriqueSurLaTranche2() async throws {
        let bareme = KmBareme.default2026
        // 5 CV, 10000 km, électrique : 4965.0 * 1.2 = 5958.0
        let result = bareme.deduction(distanceKm: 10000, fiscalPower: 5, isElectric: true)
        #expect(abs(result - 5958.0) < 0.001)
    }

    @Test func distanceNegativeDonneUneDeductionNulle() async throws {
        let bareme = KmBareme.default2026
        #expect(bareme.deduction(distanceKm: -100, fiscalPower: 5, isElectric: false) == 0.0)
    }
}
