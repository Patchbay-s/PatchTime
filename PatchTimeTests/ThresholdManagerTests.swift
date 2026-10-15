import Testing
@testable import PatchTime

struct ThresholdManagerTests {

    // MARK: - Seuil mensuel (même logique pour hebdo et annuel)

    @Test func en_dessous_80_pourcent_aucun_seuil() {
        let result = ThresholdManager.crossing(current: 27.65, limit: 35.0)  // 79,0%
        #expect(result == .none)
    }

    @Test func exactement_80_pourcent_approche() {
        let result = ThresholdManager.crossing(current: 28.0, limit: 35.0)  // 80,0%
        #expect(result == .approaching)
    }

    @Test func entre_80_et_100_pourcent_approche() {
        let result = ThresholdManager.crossing(current: 28.35, limit: 35.0)  // 81,0%
        #expect(result == .approaching)
    }

    @Test func exactement_100_pourcent_atteint() {
        let result = ThresholdManager.crossing(current: 35.0, limit: 35.0)  // 100,0%
        #expect(result == .reached)
    }

    @Test func au_dela_100_pourcent_atteint() {
        let result = ThresholdManager.crossing(current: 35.35, limit: 35.0)  // 101,0%
        #expect(result == .reached)
    }

    @Test func limite_zero_retourne_none() {
        let result = ThresholdManager.crossing(current: 100.0, limit: 0.0)
        #expect(result == .none)
    }

    @Test func current_zero_retourne_none() {
        let result = ThresholdManager.crossing(current: 0.0, limit: 35.0)
        #expect(result == .none)
    }

    // MARK: - Seuil annuel (507h)

    @Test func seuil_annuel_507h_a_80_pourcent() {
        let limit = 507.0
        let at80 = limit * 0.80  // 405,6h
        #expect(ThresholdManager.crossing(current: at80 - 0.1, limit: limit) == .none)
        #expect(ThresholdManager.crossing(current: at80,       limit: limit) == .approaching)
        #expect(ThresholdManager.crossing(current: at80 + 0.1, limit: limit) == .approaching)
    }

    @Test func seuil_annuel_507h_a_100_pourcent() {
        let limit = 507.0
        #expect(ThresholdManager.crossing(current: limit - 0.01, limit: limit) == .approaching)
        #expect(ThresholdManager.crossing(current: limit,         limit: limit) == .reached)
        #expect(ThresholdManager.crossing(current: limit + 1.0,  limit: limit) == .reached)
    }
}
