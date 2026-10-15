import Testing
@testable import PatchTime

struct TauxCalculatorTests {

    @Test func zeroChampRempliNeCalculeRien() async throws {
        var calc = TauxCalculator()
        calc.fieldEdited(.brut, newValue: nil)
        #expect(calc.brut == nil)
        #expect(calc.net == nil)
        #expect(calc.pourcentage == nil)
    }

    @Test func unSeulChampRempliNeCalculeRien() async throws {
        var calc = TauxCalculator()
        calc.fieldEdited(.brut, newValue: 20.0)
        #expect(calc.brut == 20.0)
        #expect(calc.net == nil)
        #expect(calc.pourcentage == nil)
    }

    @Test func deuxChampsRemplisCalculeLeTroisieme_netDepuisBrutEtPourcentage() async throws {
        // pourcentage = taux de prélèvement : net = brut * (1 - pourcentage).
        var calc = TauxCalculator()
        calc.fieldEdited(.brut, newValue: 20.0)
        calc.fieldEdited(.pourcentage, newValue: 0.78)
        #expect(calc.brut == 20.0)
        #expect(calc.pourcentage == 0.78)
        // 20.0 * (1 - 0.78) == 4.3999999999999995 en Double (IEEE 754) : comparaison avec
        // tolérance, pas d'égalité stricte sur un résultat de multiplication en virgule flottante.
        #expect(abs((calc.net ?? .nan) - 4.4) < 0.0001)
    }

    @Test func deuxChampsRemplisCalculeLeTroisieme_pourcentageDepuisBrutEtNet() async throws {
        // pourcentage = 1 - (net / brut).
        var calc = TauxCalculator()
        calc.fieldEdited(.brut, newValue: 20.0)
        calc.fieldEdited(.net, newValue: 15.6)
        // 1 - (15.6 / 20.0) == 0.21999999999999997 en Double : tolérance, pas d'égalité stricte.
        #expect(abs((calc.pourcentage ?? .nan) - 0.22) < 0.0001)
    }

    @Test func deuxChampsRemplisCalculeLeTroisieme_brutDepuisNetEtPourcentage() async throws {
        // brut = net / (1 - pourcentage).
        var calc = TauxCalculator()
        calc.fieldEdited(.net, newValue: 15.6)
        calc.fieldEdited(.pourcentage, newValue: 0.78)
        // 15.6 / (1 - 0.78) == 70.90909090909092 en Double : tolérance, pas d'égalité stricte.
        #expect(abs((calc.brut ?? .nan) - 70.90909090909091) < 0.0001)
    }

    @Test func modifierUnChampSurTroisRecalculeCeluiEditeLeMoinsRecemment() async throws {
        // Ordre d'édition : brut, pourcentage (net calculé) puis net (brut recalculé,
        // car parmi {brut, pourcentage} c'est brut qui est le moins récent des deux
        // sources précédentes {brut, pourcentage}. On modifie donc net : les 2 derniers
        // champs édités manuellement redeviennent {net, pourcentage} -> brut est recalculé.
        var calc = TauxCalculator()
        calc.fieldEdited(.brut, newValue: 20.0)         // historique: [brut]
        calc.fieldEdited(.pourcentage, newValue: 0.78)  // historique: [pourcentage, brut] ; net calculé = brut * (1 - 0.78)
        // 20.0 * (1 - 0.78) == 4.3999999999999995 en Double : tolérance, pas d'égalité stricte.
        #expect(abs((calc.net ?? .nan) - 4.4) < 0.0001)

        calc.fieldEdited(.net, newValue: 10.0)          // historique: [net, pourcentage] ; brut recalculé (pourcentage n'a pas bougé)
        // brut = net / (1 - pourcentage) == 10.0 / (1 - 0.78) == 45.45454545454546 : tolérance.
        #expect(abs((calc.brut ?? .nan) - (10.0 / (1 - 0.78))) < 0.0001)
        #expect(calc.pourcentage == 0.78)
    }

    @Test func modifierUnChampSurTroisAvecHistoriqueDifferent() async throws {
        var calc = TauxCalculator()
        calc.fieldEdited(.brut, newValue: 20.0)         // historique: [brut]
        calc.fieldEdited(.net, newValue: 15.0)          // historique: [net, brut] ; pourcentage calculé = 1 - (15.0/20.0) = 0.25
        #expect(calc.pourcentage == 0.25)

        // On modifie brut à nouveau : historique devient [brut, net] (pourcentage n'y est pas)
        // -> le champ recalculé est celui absent des 2 sources les plus récentes : pourcentage.
        calc.fieldEdited(.brut, newValue: 30.0)
        #expect(calc.net == 15.0)             // net inchangé, c'est une source
        #expect(calc.pourcentage == 0.5)       // 1 - (15.0 / 30.0) == 0.5
    }

    @Test func divisionParZeroNeCalculePasEtNeCrashPas() async throws {
        var calc = TauxCalculator()
        calc.fieldEdited(.brut, newValue: 0.0)
        calc.fieldEdited(.net, newValue: 10.0)
        // pourcentage = 1 - (net / brut), brut == 0 -> garde, reste nil
        #expect(calc.pourcentage == nil)

        // brut = net / (1 - pourcentage) : c'est désormais pourcentage == 1 (et non plus 0)
        // qui annule le dénominateur (1 - 1 == 0) -> garde, reste nil.
        var calc2 = TauxCalculator()
        calc2.fieldEdited(.net, newValue: 10.0)
        calc2.fieldEdited(.pourcentage, newValue: 1.0)
        #expect(calc2.brut == nil)

        // À l'inverse, pourcentage == 0.0 (aucun prélèvement) ne pose plus de problème pour le
        // calcul de brut : brut = net / (1 - 0) = net.
        var calc3 = TauxCalculator()
        calc3.fieldEdited(.net, newValue: 10.0)
        calc3.fieldEdited(.pourcentage, newValue: 0.0)
        #expect(calc3.brut == 10.0)
    }

    @Test func champCalculeEstDistinctDunChampEditeManuellement() async throws {
        var calc = TauxCalculator()
        calc.fieldEdited(.brut, newValue: 20.0)
        calc.fieldEdited(.pourcentage, newValue: 0.78)
        #expect(calc.isManuallyEdited(.brut) == true)
        #expect(calc.isManuallyEdited(.pourcentage) == true)
        #expect(calc.isManuallyEdited(.net) == false)
    }

    @Test func champEcraseParUnRecalculNestPlusConsidereCommeEditeManuellement() async throws {
        // Un champ édité manuellement puis écrasé par un recalcul automatique ultérieur ne
        // doit plus être signalé comme "édité manuellement" — sinon l'indicateur visuel
        // (Task 7) mentirait sur la provenance de sa valeur affichée.
        var calc = TauxCalculator()
        calc.fieldEdited(.brut, newValue: 20.0)          // historique: [brut]
        calc.fieldEdited(.pourcentage, newValue: 0.78)   // historique: [pourcentage, brut] ; net calculé
        calc.fieldEdited(.net, newValue: 10.0)           // historique: [net, pourcentage] ; brut recalculé et évincé de l'historique

        #expect(calc.isManuallyEdited(.net) == true)
        #expect(calc.isManuallyEdited(.pourcentage) == true)
        #expect(calc.isManuallyEdited(.brut) == false)
        // brut = net / (1 - pourcentage) == 10.0 / (1 - 0.78) == 45.45454545454546 : tolérance,
        // pas d'égalité stricte sur un résultat de division en virgule flottante.
        #expect(abs((calc.brut ?? .nan) - (10.0 / (1 - 0.78))) < 0.0001)
    }

    @Test func chargementDesTroisChampsNeDeclencheAucunRecalcul() async throws {
        // Contrairement à l'ancien bug (reseed via 3x fieldEdited), charger un profil dont
        // les 3 valeurs sont déjà connues ne doit modifier AUCUNE des 3 valeurs.
        let calc = TauxCalculator(loadingBrut: 20.0, net: 15.0, pourcentage: 0.75)
        #expect(calc.brut == 20.0)
        #expect(calc.net == 15.0)
        #expect(calc.pourcentage == 0.75)
    }

    @Test func chargementSeedeLHistoriqueAvecLesDeuxPremiersChampsNonNilDansLOrdreAllCases() async throws {
        let calc = TauxCalculator(loadingBrut: 20.0, net: 15.0, pourcentage: 0.75)
        #expect(calc.isManuallyEdited(.brut) == true)
        #expect(calc.isManuallyEdited(.net) == true)
        #expect(calc.isManuallyEdited(.pourcentage) == false)
    }

    @Test func rechargerPuisEditerUnChampNePerturbePasLesAutresValeurs() async throws {
        // Reproduit le scénario exact du 3ème bug trouvé pendant le développement :
        // rechargement d'un profil avec les 3 champs déjà remplis (comme
        // EditOvertimeProfileView.init), puis modification d'un seul champ — vérifie que la
        // valeur non éditée et non recalculée (ici brut) ne dérive pas.
        var calc = TauxCalculator(loadingBrut: 20.0, net: 15.0, pourcentage: 0.75)
        calc.fieldEdited(.net, newValue: 10.0)
        // historique après chargement : [.brut, .net] (sources) -> édition de .net ->
        // historique devient [.net, .brut] -> cible recalculée = .pourcentage (absente des 2 sources)
        // 1 - (10.0 / 20.0) == 0.5, division exacte (coïncidence : 0.5 est son propre complément
        // à 1, donc identique à l'ancien calcul net/brut pour ces valeurs précises).
        #expect(calc.pourcentage == 0.5)
        #expect(calc.brut == 20.0)       // inchangé : brut n'était pas la cible du recalcul
        #expect(calc.net == 10.0)
    }

    @Test func pourcentageEstUnTauxDePrelevementPasUnRatioNetBrut() async throws {
        // Sémantique explicite et sans ambiguïté : pourcentage = taux de prélèvement
        // (charges, cotisations...), pas le ratio net/brut. brut=100, prélèvement=10% -> net=90.
        var calc = TauxCalculator()
        calc.fieldEdited(.brut, newValue: 100.0)
        calc.fieldEdited(.pourcentage, newValue: 0.10)
        #expect(calc.net == 90.0)

        // Et réciproquement : brut=100, net=90 -> le prélèvement retrouvé est bien 10%.
        // 1 - (90.0 / 100.0) == 0.09999999999999998 en Double : tolérance, pas d'égalité stricte.
        var calc2 = TauxCalculator()
        calc2.fieldEdited(.brut, newValue: 100.0)
        calc2.fieldEdited(.net, newValue: 90.0)
        #expect(abs((calc2.pourcentage ?? .nan) - 0.10) < 0.0001)
    }
}
