import Foundation

/// Lundi = 1 ... Dimanche = 7, ordre d'affichage de la semaine type.
enum Weekday: Int, CaseIterable, Identifiable {
    case monday = 1
    case tuesday
    case wednesday
    case thursday
    case friday
    case saturday
    case sunday

    var id: Int { rawValue }

    /// Convertit le `weekday` de `Calendar` (1 = dimanche ... 7 = samedi, indépendant de
    /// `firstWeekday`) vers `Weekday` (1 = lundi ... 7 = dimanche) — utilisé pour comparer la
    /// date d'une entrée réelle au patron de la Semaine type sans énumérer de dates calendaires.
    static func from(calendarWeekday: Int) -> Weekday? {
        Weekday(rawValue: calendarWeekday == 1 ? 7 : calendarWeekday - 1)
    }

    var label: String {
        switch self {
        case .monday: return "Lundi"
        case .tuesday: return "Mardi"
        case .wednesday: return "Mercredi"
        case .thursday: return "Jeudi"
        case .friday: return "Vendredi"
        case .saturday: return "Samedi"
        case .sunday: return "Dimanche"
        }
    }
}

/// Un jour de la semaine type — vue en lecture pure sur les attributs `Employer` sous-jacents,
/// pas un objet Core Data séparé (voir `Employer+TypicalWeek.swift` : la semaine type est un
/// patron 1:1 par employeur, portée directement par des attributs plats sur `Employer`, même
/// principe que `kmDistanceRoundTrip` déjà existant — pas de nouvelle entité/relation pour une
/// structure de cardinalité fixe et toujours 1:1).
struct TypicalWeekDay: Identifiable, Equatable {
    let weekday: Weekday
    var isWorked: Bool
    var hours: Double?

    var id: Int { weekday.rawValue }
}

extension Employer {
    var typicalWeekMondayHoursValue: Double? {
        get { typicalWeekMondayHours?.doubleValue }
        set { typicalWeekMondayHours = newValue.map { NSNumber(value: $0) } }
    }
    var typicalWeekTuesdayHoursValue: Double? {
        get { typicalWeekTuesdayHours?.doubleValue }
        set { typicalWeekTuesdayHours = newValue.map { NSNumber(value: $0) } }
    }
    var typicalWeekWednesdayHoursValue: Double? {
        get { typicalWeekWednesdayHours?.doubleValue }
        set { typicalWeekWednesdayHours = newValue.map { NSNumber(value: $0) } }
    }
    var typicalWeekThursdayHoursValue: Double? {
        get { typicalWeekThursdayHours?.doubleValue }
        set { typicalWeekThursdayHours = newValue.map { NSNumber(value: $0) } }
    }
    var typicalWeekFridayHoursValue: Double? {
        get { typicalWeekFridayHours?.doubleValue }
        set { typicalWeekFridayHours = newValue.map { NSNumber(value: $0) } }
    }
    var typicalWeekSaturdayHoursValue: Double? {
        get { typicalWeekSaturdayHours?.doubleValue }
        set { typicalWeekSaturdayHours = newValue.map { NSNumber(value: $0) } }
    }
    var typicalWeekSundayHoursValue: Double? {
        get { typicalWeekSundayHours?.doubleValue }
        set { typicalWeekSundayHours = newValue.map { NSNumber(value: $0) } }
    }

    func isTypicalWeekWorked(_ weekday: Weekday) -> Bool {
        switch weekday {
        case .monday: return typicalWeekMondayWorked
        case .tuesday: return typicalWeekTuesdayWorked
        case .wednesday: return typicalWeekWednesdayWorked
        case .thursday: return typicalWeekThursdayWorked
        case .friday: return typicalWeekFridayWorked
        case .saturday: return typicalWeekSaturdayWorked
        case .sunday: return typicalWeekSundayWorked
        }
    }

    func typicalWeekHours(_ weekday: Weekday) -> Double? {
        switch weekday {
        case .monday: return typicalWeekMondayHoursValue
        case .tuesday: return typicalWeekTuesdayHoursValue
        case .wednesday: return typicalWeekWednesdayHoursValue
        case .thursday: return typicalWeekThursdayHoursValue
        case .friday: return typicalWeekFridayHoursValue
        case .saturday: return typicalWeekSaturdayHoursValue
        case .sunday: return typicalWeekSundayHoursValue
        }
    }

    /// Renseigne un jour de la semaine type. Les heures ne sont conservées que si le jour est
    /// travaillé — passer `isWorked: false` efface toujours les heures existantes, pour éviter
    /// qu'une valeur orpheline (jour marqué non travaillé mais avec des heures encore stockées)
    /// ne fausse un calcul qui lirait `typicalWeekHours` sans revérifier `isTypicalWeekWorked`.
    func setTypicalWeekDay(_ weekday: Weekday, isWorked: Bool, hours: Double?) {
        let resolvedHours = isWorked ? hours : nil
        switch weekday {
        case .monday:
            typicalWeekMondayWorked = isWorked
            typicalWeekMondayHoursValue = resolvedHours
        case .tuesday:
            typicalWeekTuesdayWorked = isWorked
            typicalWeekTuesdayHoursValue = resolvedHours
        case .wednesday:
            typicalWeekWednesdayWorked = isWorked
            typicalWeekWednesdayHoursValue = resolvedHours
        case .thursday:
            typicalWeekThursdayWorked = isWorked
            typicalWeekThursdayHoursValue = resolvedHours
        case .friday:
            typicalWeekFridayWorked = isWorked
            typicalWeekFridayHoursValue = resolvedHours
        case .saturday:
            typicalWeekSaturdayWorked = isWorked
            typicalWeekSaturdayHoursValue = resolvedHours
        case .sunday:
            typicalWeekSundayWorked = isWorked
            typicalWeekSundayHoursValue = resolvedHours
        }
    }

    /// Les 7 jours, dans l'ordre lundi → dimanche.
    var typicalWeekDays: [TypicalWeekDay] {
        Weekday.allCases.map { weekday in
            TypicalWeekDay(weekday: weekday, isWorked: isTypicalWeekWorked(weekday), hours: typicalWeekHours(weekday))
        }
    }

    /// Nombre de jours travaillés par semaine type — base du calcul frais km/repas si la
    /// semaine type est choisie comme source dans le Bilan fiscal (à venir).
    var typicalWeekWorkedDaysCount: Int {
        typicalWeekDays.filter { $0.isWorked }.count
    }

    /// Somme des heures des jours travaillés qui en ont renseigné (jours travaillés sans heure
    /// saisie ignorés, pas comptés comme 0).
    var typicalWeeklyHoursTotal: Double {
        typicalWeekDays.filter { $0.isWorked }.compactMap { $0.hours }.reduce(0, +)
    }
}
