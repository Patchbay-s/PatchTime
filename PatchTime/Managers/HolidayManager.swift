import Foundation
import SwiftUI

@MainActor
class HolidayManager: ObservableObject {
    private static let apiBaseURL = "https://calendrier.api.gouv.fr/jours-feries"

    private func syncTimestampKey(zone: HolidayZone, year: Int) -> String {
        "holidaySync_\(zone.rawValue)_\(year)"
    }

    /// Format exact renvoyé par `calendrier.api.gouv.fr` : un objet JSON plat
    /// `{"2026-01-01": "1er janvier", ...}`. Fonction pure (aucun accès réseau/état),
    /// testable indépendamment de `URLSession` — même principe que
    /// `ThresholdManager.crossing(current:limit:)`.
    nonisolated static func parseAPIResponse(_ json: [String: String]) -> [(date: Date, label: String)] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.locale = Locale(identifier: "en_US_POSIX")

        return json.compactMap { key, label in
            guard let date = formatter.date(from: key) else { return nil }
            return (date: date, label: label)
        }
    }

    /// Vrai si `existing` contient déjà un jour férié pour le même jour civil, la même zone
    /// et la même source que `date`/`zone`/`source`. Sert à dédoublonner les insertions
    /// automatiques (`.seed`/`.api`, dans `seedMonacoIfNeeded()` / `syncIfNeeded(...)`) avant
    /// `CoreDataManager.addPublicHoliday` : `PublicHoliday` réplique via CloudKit
    /// (`NSPersistentCloudKitContainer`, voir `CoreDataManager.swift`), mais
    /// les guards anti-doublon (`monacoHolidaysSeeded_v1`, `holidaySync_<zone>_<year>`) sont
    /// des `UserDefaults` locaux à l'appareil — un second appareil peut re-seeder/re-sync
    /// après avoir reçu les entrées du premier via CloudKit. Un `uniquenessConstraint` Core
    /// Data n'est pas une option ici (non supporté par `NSPersistentCloudKitContainer`), d'où
    /// ce contrôle applicatif. Fonction pure — testable indépendamment de
    /// `CoreDataManager.shared` avec des `PublicHoliday` construits sur un contexte en
    /// mémoire (même principe que `parseAPIResponse`/`monacoSeedHolidays` ci-dessus). Les
    /// ajouts manuels de l'utilisateur (`.custom`, voir `HolidaySettingsView`) ne passent
    /// jamais par ce contrôle et peuvent toujours créer autant d'entrées que voulu.
    nonisolated static func isDuplicate(
        date: Date,
        zone: HolidayZone,
        source: HolidaySource,
        among existing: [PublicHoliday],
        calendar: Calendar = Calendar.current
    ) -> Bool {
        let dayStart = calendar.startOfDay(for: date)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return false }
        return existing.contains { holiday in
            holiday.zone == zone &&
            holiday.sourceValue == source &&
            (holiday.date.map { $0 >= dayStart && $0 < dayEnd } ?? false)
        }
    }

    /// Interroge Core Data pour un doublon potentiel avant insertion. Restreint la requête à
    /// la zone/source visée (petit volume, une douzaine d'entrées par an) puis délègue la
    /// comparaison du jour civil à `isDuplicate(...)`, seule source de vérité pour cette
    /// logique — voir sa documentation pour le contexte CloudKit.
    private func isDuplicateHoliday(date: Date, zone: HolidayZone, source: HolidaySource) -> Bool {
        let predicate = NSPredicate(format: "countryZone == %@ AND source == %@", zone.rawValue, source.rawValue)
        let candidates = CoreDataManager.shared.fetchPublicHolidays(predicate: predicate)
        return Self.isDuplicate(date: date, zone: zone, source: source, among: candidates)
    }

    private let monacoSeedKey = "monacoHolidaysSeeded_v1"

    /// Jours fériés officiels de Monaco pour 2026, sourcés (gouvernement princier /
    /// monservicepublic.gouv.mc, recoupé le 2026-07-26 — voir design doc chantier 3). Monaco
    /// n'a pas d'API équivalente à calendrier.api.gouv.fr : liste codée en dur, éditable par
    /// l'utilisateur (isUserEdited) dans les réglages "Pays / jours fériés". Les 4 fêtes
    /// mobiles (Pâques, Ascension, Pentecôte, Fête-Dieu) sont ici enumérées pour 2026
    /// uniquement — à mettre à jour manuellement chaque année (pas de calcul de la date de
    /// Pâques implémenté, hors scope de ce plan).
    nonisolated static func monacoSeedHolidays(forYear year: Int) -> [(date: Date, label: String)] {
        guard year == 2026 else { return [] }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!

        func date(_ month: Int, _ day: Int) -> Date {
            calendar.date(from: DateComponents(year: year, month: month, day: day))!
        }

        return [
            (date(1, 1), "Jour de l'An"),
            (date(1, 27), "Sainte Dévote"),
            (date(4, 6), "Lundi de Pâques"),
            (date(5, 1), "Fête du Travail"),
            (date(5, 14), "Jeudi de l'Ascension"),
            (date(5, 25), "Lundi de Pentecôte"),
            (date(6, 4), "Fête-Dieu"),
            (date(8, 15), "Assomption"),
            (date(11, 1), "Toussaint"),
            (date(11, 19), "Fête Nationale"),
            (date(12, 8), "Immaculée Conception"),
            (date(12, 25), "Noël")
        ]
    }

    func seedMonacoIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: monacoSeedKey) else { return }
        let year = Calendar.current.component(.year, from: Date())
        let seed = Self.monacoSeedHolidays(forYear: year)
        guard !seed.isEmpty else { return } // année non couverte par le seed statique

        for entry in seed {
            guard !isDuplicateHoliday(date: entry.date, zone: .monaco, source: .seed) else { continue }
            CoreDataManager.shared.addPublicHoliday(
                date: entry.date, label: entry.label, zone: .monaco, source: .seed, isUserEdited: false
            )
        }
        UserDefaults.standard.set(true, forKey: monacoSeedKey)
    }

    /// - Parameter force: si `true`, ignore le cache `holidaySync_<zone>_<year>` et relance la
    ///   synchronisation même si elle a déjà eu lieu (bouton "Rafraîchir" dans
    ///   `HolidaySettingsView`) ; le timestamp de cache est tout de même remis à jour en cas de
    ///   succès, comme pour un appel normal. Par défaut (`false`), comportement inchangé : un
    ///   seul fetch par zone/année (appelé automatiquement au lancement dans
    ///   `PatchTimeApp.swift`). Sûr à répéter dans les deux cas car chaque insertion passe
    ///   par `isDuplicateHoliday` avant `addPublicHoliday`.
    func syncIfNeeded(zone: HolidayZone, year: Int, force: Bool = false) async {
        guard zone.isFetchableFromAPI else { return }
        let key = syncTimestampKey(zone: zone, year: year)
        if !force {
            guard UserDefaults.standard.object(forKey: key) == nil else { return }
        }
        guard let url = URL(string: "\(Self.apiBaseURL)/\(zone.rawValue)/\(year).json") else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let json = try JSONDecoder().decode([String: String].self, from: data)
            let parsed = Self.parseAPIResponse(json)
            for entry in parsed {
                guard !isDuplicateHoliday(date: entry.date, zone: zone, source: .api) else { continue }
                CoreDataManager.shared.addPublicHoliday(
                    date: entry.date, label: entry.label, zone: zone, source: .api, isUserEdited: false
                )
            }
            UserDefaults.standard.set(Date(), forKey: key)
        } catch {
            // Échec réseau/offline : dégradation gracieuse, pas d'alerte bloquante — la liste
            // en cache (si elle existe déjà pour une année précédente) reste utilisable, et la
            // clé de cache n'est pas marquée pour permettre un nouvel essai plus tard.
            print("HolidayManager — échec de synchronisation \(zone.rawValue)/\(year): \(error.localizedDescription)")
        }
    }
}
