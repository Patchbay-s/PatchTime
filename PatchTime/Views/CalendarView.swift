import SwiftUI
import Foundation
import CoreData

struct CalendarView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \OvertimeEntry.date, ascending: true)],
        animation: .default)
    private var overtimeEntries: FetchedResults<OvertimeEntry>
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \MealEntry.date, ascending: true)],
        animation: .default)
    private var mealEntries: FetchedResults<MealEntry>
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Employer.name, ascending: true)],
        animation: .default)
    private var employers: FetchedResults<Employer>
    // Observé directement (plutôt que dérivé via CoreDataManager.shared.fetchContracts) pour
    // que toute modification des dates d'un contrat déclenche un rafraîchissement immédiat de
    // la grille — un Contract modifié ne touche pas l'entité Employer, donc le @FetchRequest
    // ci-dessus seul ne se re-déclenchait jamais sur un simple changement de startDate/endDate
    // (Chantier A, cause du "calendrier pas à jour après modif contrat").
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Contract.startDate, ascending: true)],
        animation: .default)
    private var contracts: FetchedResults<Contract>
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \LeaveEntry.date, ascending: true)],
        animation: .default)
    private var leaveEntries: FetchedResults<LeaveEntry>
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \PublicHoliday.date, ascending: true)],
        animation: .default)
    private var holidays: FetchedResults<PublicHoliday>

    let overtimeProfiles: [OvertimeProfile]
    let currency: String

    @AppStorage("defaultProfileId") private var defaultProfileId: String = ""
    @AppStorage("holidayCountryZone") private var holidayCountryZoneRaw: String = HolidayZone.metropole.rawValue

    private var profileMap: [UUID: OvertimeProfile] {
        Dictionary(uniqueKeysWithValues: overtimeProfiles.compactMap { p in p.id.map { ($0, p) } })
    }

    private var selectedHolidayZone: HolidayZone {
        HolidayZone(rawValue: holidayCountryZoneRaw) ?? .metropole
    }

    /// `holidays` n'est pas filtré par zone au niveau du `@FetchRequest` (toutes les zones
    /// jamais synchronisées/seedées restent en base, cf. `HolidayManager`) — sans ce filtre,
    /// changer de pays dans les réglages (ex: France -> Monaco) n'effaçait aucune donnée mais
    /// le calendrier continuait d'afficher les jours fériés de l'ancienne zone en plus de la
    /// nouvelle (le 14 juillet restait marqué férié à Monaco). `@AppStorage` étant réactif,
    /// changer de zone dans les réglages met immédiatement à jour cette liste, sans redémarrage
    /// — même principe que `HolidaySettingsView.filteredHolidays` (fix B3), jamais appliqué ici.
    private var zoneFilteredHolidays: [PublicHoliday] {
        holidays.filter { $0.zone == selectedHolidayZone }
    }

    private var employerMap: [UUID: Employer] {
        Dictionary(uniqueKeysWithValues: employers.compactMap { e in e.id.map { ($0, e) } })
    }

    @State private var selectedDate: Date = Date()
    @State private var displayedMonth: Date = Calendar.current.startOfMonth(for: Date())

    var filteredOvertimeEntries: [OvertimeEntry] {
        // archived == NO et la fenêtre du mois affiché sont déjà appliqués au niveau du predicate CoreData.
        guard !defaultProfileId.isEmpty,
              let defaultProfile = overtimeProfiles.first(where: { $0.id?.uuidString == defaultProfileId })
        else { return Array(overtimeEntries) }
        return overtimeEntries.filter { $0.profileID == defaultProfile.id }
    }

    var filteredMealEntries: [MealEntry] {
        guard !defaultProfileId.isEmpty,
              let defaultProfile = overtimeProfiles.first(where: { $0.id?.uuidString == defaultProfileId }),
              let employerID = defaultProfile.employer?.id
        else { return Array(mealEntries) }
        return mealEntries.filter { $0.employerID == employerID }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Navigation mois
            HStack {
                Button(action: {
                    if let prev = Calendar.current.date(byAdding: .month, value: -1, to: displayedMonth) {
                        displayedMonth = prev
                    }
                }) {
                    Image(systemName: "chevron.left")
                }
                .accessibilityLabel("Mois précédent")
                Spacer()
                Text(formattedMonthYear(from: displayedMonth))
                    .font(.headline)
                Spacer()
                Button(action: {
                    if let next = Calendar.current.date(byAdding: .month, value: 1, to: displayedMonth) {
                        displayedMonth = next
                    }
                }) {
                    Image(systemName: "chevron.right")
                }
                .accessibilityLabel("Mois suivant")
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            // Calendrier simple (grille des jours du mois)
            CalendarMonthGrid(selectedDate: $selectedDate, displayedMonth: displayedMonth, overtimeEntries: filteredOvertimeEntries, mealEntries: filteredMealEntries, leaveEntries: Array(leaveEntries), holidays: zoneFilteredHolidays, contracts: Array(contracts))
                .padding(.horizontal)

            Divider()
                .padding(.vertical, 8)

            // Liste des entrées du jour sélectionné
            Text("Événements du \(selectedDate.formatted(date: .abbreviated, time: .omitted))")
                .font(.headline)
                .padding(.bottom, 8)

            ScrollView {
                let dayOvertimeEntries = filteredOvertimeEntries.filter { Calendar.current.isDate($0.date ?? Date(), inSameDayAs: selectedDate) }
                let dayMealEntries = filteredMealEntries.filter { Calendar.current.isDate($0.date ?? Date(), inSameDayAs: selectedDate) }
                let dayLeaveEntries = Array(employers).isEligibleLeaveDay(selectedDate)
                    ? leaveEntries.filter { $0.coversDate(selectedDate) }
                    : []
                let dayHolidays = zoneFilteredHolidays.filter { holiday in
                    guard holiday.date != nil else { return false }
                    return selectedDate.isPublicHoliday(among: [holiday])
                }
                // Statut "jour travaillé" issu de la Semaine type — affiché dans la liste
                // d'événements même quand la pastille bleue équivalente ne s'affiche pas sur la
                // grille par priorité aux heures sup réelles (Chantier C/D) : l'information
                // n'est jamais perdue, seulement masquée sur la grille quand une entrée réelle
                // existe déjà ce jour-là. Un CP/Récup ce jour-là prend le dessus de la même
                // façon : pas de ligne "Jour travaillé" contradictoire avec la ligne CP/Récup.
                let dayTypicalWeekEmployers: [Employer] = (dayOvertimeEntries.isEmpty && dayLeaveEntries.isEmpty)
                    ? typicalWeekEmployers(coveringDate: selectedDate)
                    : []

                if dayOvertimeEntries.isEmpty && dayMealEntries.isEmpty && dayLeaveEntries.isEmpty
                    && dayHolidays.isEmpty && dayTypicalWeekEmployers.isEmpty {
                    Text("Aucun événement ce jour-là")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                } else {
                    VStack(spacing: 8) {
                        ForEach(dayOvertimeEntries) { entry in
                            OvertimeCalendarRow(entry: entry, currency: currency,
                                                profile: entry.profileID.flatMap { profileMap[$0] },
                                                holidays: zoneFilteredHolidays)
                        }
                        ForEach(dayMealEntries) { entry in
                            MealCalendarRow(entry: entry, employer: entry.employerID.flatMap { employerMap[$0] })
                        }
                        ForEach(dayLeaveEntries) { entry in
                            LeaveCalendarRow(entry: entry)
                        }
                        ForEach(dayHolidays) { holiday in
                            HolidayCalendarRow(holiday: holiday)
                        }
                        ForEach(dayTypicalWeekEmployers) { employer in
                            TypicalWeekDayCalendarRow(employer: employer)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .navigationTitle("Calendrier")
        .onAppear { updateMonthPredicate() }
        .onChange(of: displayedMonth) { _, _ in updateMonthPredicate() }
    }

    /// Restreint les deux `@FetchRequest` au mois affiché (+ archived == NO) plutôt que de
    /// charger tout l'historique et de le filtrer en mémoire à chaque cellule de la grille.
    private func updateMonthPredicate() {
        let calendar = Calendar.current
        let monthStart = calendar.startOfMonth(for: displayedMonth)
        let nextMonthStart = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? monthStart

        overtimeEntries.nsPredicate = NSPredicate(
            format: "archived == NO AND date >= %@ AND date < %@",
            monthStart as NSDate, nextMonthStart as NSDate
        )
        mealEntries.nsPredicate = NSPredicate(
            format: "archived == NO AND date >= %@ AND date < %@",
            monthStart as NSDate, nextMonthStart as NSDate
        )
    }

    func formattedMonthYear(from date: Date) -> String {
        SharedFormatters.frenchMonthYear.string(from: date)
    }

    func formattedDate(from date: Date?) -> String {
        guard let date = date else { return "" }
        return SharedFormatters.frenchLongDate.string(from: date)
    }

    /// Employeurs dont la Semaine type marque `date` comme travaillée, dans la limite de la
    /// période active de leur contrat (`Contract.covers(date:)`) — même règle que la pastille
    /// grille (Chantier A), exposée ici pour la liste d'événements (Chantier D).
    private func typicalWeekEmployers(coveringDate date: Date) -> [Employer] {
        let calendar = Calendar.current
        guard let weekday = Weekday.from(calendarWeekday: calendar.component(.weekday, from: date)) else { return [] }
        let matchingEmployers = contracts.compactMap { contract -> Employer? in
            guard let employer = contract.employer, employer.typicalWeekEnabled, employer.isTypicalWeekWorked(weekday) else { return nil }
            return contract.covers(date: date, calendar: calendar) ? employer : nil
        }
        var seen = Set<NSManagedObjectID>()
        return matchingEmployers.filter { seen.insert($0.objectID).inserted }
    }
}

// Squelette d'une grille de calendrier mensuel
struct CalendarMonthGrid: View {
    @Binding var selectedDate: Date
    let displayedMonth: Date
    let overtimeEntries: [OvertimeEntry]
    let mealEntries: [MealEntry]
    let leaveEntries: [LeaveEntry]
    let holidays: [PublicHoliday]
    let contracts: [Contract]

    /// Rayon de la couronne de pastilles autour du numéro du jour, et diamètre de chaque
    /// pastille — dimensionnés pour rester lisibles avec les 5 catégories simultanées dans
    /// une cellule de ~36pt (cercle de sélection).
    private let dotRingRadius: CGFloat = 15
    private let dotDiameter: CGFloat = 6

    var calendarFR: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "fr_FR")
        cal.firstWeekday = 2 // lundi
        return cal
    }
    
    /// Un jour est présent dans la grille => un seul lookup O(1) par cellule au lieu d'un
    /// scan linéaire de tout le tableau à chaque cellule. Contrairement à l'ancien
    /// `indexByDay` (un seul item retenu par jour), ces index retiennent une présence par
    /// catégorie — plusieurs entrées le même jour ne s'écrasent plus entre elles.
    private func indexOvertimeDots(_ items: [OvertimeEntry], calendar: Calendar) -> (worked: Set<Date>, validated: Set<Date>, unvalidated: Set<Date>) {
        var worked: Set<Date> = []
        var validated: Set<Date> = []
        var unvalidated: Set<Date> = []
        for entry in items {
            guard let date = entry.date else { continue }
            let day = calendar.startOfDay(for: date)
            worked.insert(day)
            if entry.value(forKey: "isValidated") as? Bool ?? false {
                validated.insert(day)
            } else {
                unvalidated.insert(day)
            }
        }
        return (worked, validated, unvalidated)
    }

    private func indexMealDots(_ items: [MealEntry], calendar: Calendar) -> (present: Set<Date>, unvalidated: Set<Date>) {
        var present: Set<Date> = []
        var unvalidated: Set<Date> = []
        for entry in items {
            guard let date = entry.date else { continue }
            let day = calendar.startOfDay(for: date)
            present.insert(day)
            if !(entry.value(forKey: "isValidated") as? Bool ?? false) {
                unvalidated.insert(day)
            }
        }
        return (present, unvalidated)
    }

    /// Jours où la Semaine type d'un employeur prévoit un jour travaillé mais où aucune entrée
    /// réelle n'existe encore ce jour-là (`workedDays` déjà indexé) — priorité visuelle aux
    /// heures sup réelles : ce set n'ajoute la pastille "jour travaillé" (bleu) que là où elle
    /// ne s'afficherait pas déjà via une entrée réelle. Filtré par contrat actif à cette date
    /// (`Contract.covers(date:)`) — sans ce filtre, le gabarit s'appliquait à toutes les dates,
    /// y compris hors de la période réelle du contrat (Chantier A). Un jour couvert par un
    /// CP/Récup (`leaveDays`) est également exclu : le CP/Récup prend le dessus sur le statut
    /// "jour travaillé" projeté, qui ne doit plus s'afficher pour ce jour-là.
    private func indexTypicalWeekTemplateDays(gridDays: [Date], calendar: Calendar, workedDays: Set<Date>, leaveDays: Set<Date>) -> Set<Date> {
        let activeContracts = contracts.filter { $0.employer?.typicalWeekEnabled == true }
        guard !activeContracts.isEmpty else { return [] }

        var result: Set<Date> = []
        for day in gridDays {
            guard !workedDays.contains(day) else { continue }
            guard !leaveDays.contains(day) else { continue }
            guard let weekday = Weekday.from(calendarWeekday: calendar.component(.weekday, from: day)) else { continue }
            let isTemplateDay = activeContracts.contains { contract in
                guard let employer = contract.employer, employer.isTypicalWeekWorked(weekday) else { return false }
                return contract.covers(date: day, calendar: calendar)
            }
            if isTemplateDay {
                result.insert(day)
            }
        }
        return result
    }

    /// Un CP/Récup n'est retenu que si son jour de semaine fait partie du gabarit Semaine type
    /// d'au moins un employeur actif (`isEligibleLeaveDay`) — sinon aucune restriction (voir sa
    /// documentation).
    private func indexLeaveDays(_ items: [LeaveEntry], calendar: Calendar, gridDays: [Date]) -> Set<Date> {
        let employers = contracts.compactMap { $0.employer }
        var days: Set<Date> = []
        for gridDay in gridDays {
            guard employers.isEligibleLeaveDay(gridDay, calendar: calendar) else { continue }
            if items.contains(where: { $0.coversDate(gridDay, calendar: calendar) }) {
                days.insert(gridDay)
            }
        }
        return days
    }

    private func indexHolidayDays(_ items: [PublicHoliday], calendar: Calendar, gridDays: [Date]) -> Set<Date> {
        var days: Set<Date> = []
        for gridDay in gridDays {
            if gridDay.isPublicHoliday(among: items, calendar: calendar) {
                days.insert(gridDay)
            }
        }
        return days
    }

    var body: some View {
        let calendar = calendarFR
        let month = calendar.component(.month, from: displayedMonth)
        let year = calendar.component(.year, from: displayedMonth)
        let daysRange = calendar.range(of: .day, in: .month, for: displayedMonth) ?? Range(1...31)
        let daysInMonth = Array(daysRange)
        let firstOfMonth = calendar.date(from: DateComponents(year: year, month: month, day: 1))
            ?? displayedMonth
        let firstWeekday = calendar.component(.weekday, from: firstOfMonth)
        let weekdaySymbols = calendar.shortStandaloneWeekdaySymbols
        let orderedWeekdays = weekdaySymbols.shifted(soThatFirstIs: calendar.firstWeekday)
        let offset = (firstWeekday - calendar.firstWeekday + 7) % 7
        let totalCells = 42 // 6 semaines * 7 jours
        let columns = Array(repeating: GridItem(.flexible()), count: 7)
        let calendarCells: [Int?] = Array(repeating: nil, count: offset) + daysInMonth.map { Optional($0) } + Array(repeating: nil, count: max(0, totalCells - (offset + daysInMonth.count)))

        // Index calculés une seule fois par render, réutilisés pour les ~42 cellules.
        let gridDays: [Date] = daysInMonth.compactMap { day in
            calendar.date(from: DateComponents(year: year, month: month, day: day))
        }
        let (workedDays, validatedOvertimeDays, unvalidatedOvertimeDays) = indexOvertimeDots(overtimeEntries, calendar: calendar)
        let leaveDays = indexLeaveDays(leaveEntries, calendar: calendar, gridDays: gridDays)
        let typicalWeekTemplateDays = indexTypicalWeekTemplateDays(gridDays: gridDays, calendar: calendar, workedDays: workedDays, leaveDays: leaveDays)
        let (mealDays, unvalidatedMealDays) = indexMealDots(mealEntries, calendar: calendar)
        let toValidateDays = unvalidatedOvertimeDays.union(unvalidatedMealDays)
        let holidayDays = indexHolidayDays(holidays, calendar: calendar, gridDays: gridDays)
        let holidayOrLeaveDays = leaveDays.union(holidayDays)

        VStack(spacing: 4) {
            // Affichage des jours de la semaine
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(Array(orderedWeekdays.enumerated()), id: \.offset) { index, symbol in
                    Text(symbol)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            // Grille des jours
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(0..<calendarCells.count, id: \.self) { index in
                    if let day = calendarCells[index] {
                        let date = calendar.date(from: DateComponents(year: year, month: month, day: day))
                            ?? displayedMonth
                        let dayKey = calendar.startOfDay(for: date)
                        let activeCategories = CalendarDotCategory.activeCategories(
                            holidayOrLeave: holidayOrLeaveDays.contains(dayKey),
                            workedDay: workedDays.contains(dayKey) || typicalWeekTemplateDays.contains(dayKey),
                            meal: mealDays.contains(dayKey),
                            validatedOvertime: validatedOvertimeDays.contains(dayKey),
                            toValidate: toValidateDays.contains(dayKey)
                        )
                        Button(action: { selectedDate = date }) {
                            ZStack {
                                Circle()
                                    .fill(calendar.isDate(selectedDate, inSameDayAs: date) ? Color.accentColor.opacity(0.25) : Color.clear)
                                    .frame(width: 36, height: 36)
                                Text("\(day)")
                                    .foregroundColor(calendar.isDateInToday(date) ? .accentColor : .primary)
                                // Pastilles en couronne autour du numéro du jour, une par
                                // catégorie active — cumulables, pas de priorité exclusive.
                                ForEach(Array(activeCategories.enumerated()), id: \.offset) { index, category in
                                    let angle = Angle.degrees(Double(index) / Double(activeCategories.count) * 360 - 90)
                                    Circle()
                                        .fill(category.color)
                                        // Liseré discret : garde lisibles les teintes claires
                                        // (jaune) sur fond clair, et les sombres sur fond sombre.
                                        .overlay(Circle().strokeBorder(Color.primary.opacity(0.25), lineWidth: 0.5))
                                        .frame(width: dotDiameter, height: dotDiameter)
                                        .offset(
                                            x: CGFloat(cos(angle.radians)) * dotRingRadius,
                                            y: CGFloat(sin(angle.radians)) * dotRingRadius
                                        )
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    } else {
                        Color.clear.frame(height: 30)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components) ?? date
    }

    /// 1er janvier / 31 décembre de `year` — factorisé depuis `FiscalDayCounts` et
    /// `Contract+ActiveWeeks`, qui construisaient chacun ces deux dates séparément.
    func yearStart(_ year: Int) -> Date {
        date(from: DateComponents(year: year, month: 1, day: 1))!
    }

    func yearEnd(_ year: Int) -> Date {
        date(from: DateComponents(year: year, month: 12, day: 31))!
    }
}

extension Array {
    func shifted(soThatFirstIs firstIndex: Int) -> [Element] {
        guard count > 0 else { return self }
        let idx = (firstIndex - 1 + count) % count
        return Array(self[idx...] + self[..<idx])
    }
}

struct OvertimeCalendarRow: View {
    let entry: OvertimeEntry
    let currency: String
    let profile: OvertimeProfile?
    let holidays: [PublicHoliday]


    var isValidated: Bool {
        entry.value(forKey: "isValidated") as? Bool ?? false
    }
    
    var validationColor: Color {
        isValidated ? .green : .red
    }

    var body: some View {
        HStack {
            Image(systemName: "clock")
                .foregroundColor(validationColor)
            VStack(alignment: .leading) {
                HStack {
                    if let timeRange = entry.timeRangeText {
                        Text(timeRange)
                            .font(.subheadline)
                            .foregroundColor(validationColor)
                        Text(entry.type == "sup" ? "Heure Sup" : "Récupération")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(entry.type == "sup" ? Color.blue.opacity(0.2) : Color.green.opacity(0.2))
                            .foregroundColor(entry.type == "sup" ? .blue : .green)
                            .cornerRadius(4)
                        if isValidated {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                        } else {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }
                }
                if let start = entry.startTime, let end = entry.endTime {
                    let hours = end.timeIntervalSince(start) / 3600
                    Text(String(format: "%.1f heures", hours))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing) {
                if let profile = profile {
                    Text(profile.name ?? "")
                        .font(.subheadline)
                        .foregroundColor(validationColor)
                    if let start = entry.startTime, let end = entry.endTime {
                        let hours = end.timeIntervalSince(start) / 3600
                        let rate = ReportRowCalculator.bestEffortRate(for: profile)
                        let multiplier = entry.type == "recup" ? 1.0 : OvertimeSurcharge.multiplier(for: entry, profile: profile, holidays: holidays)
                        Text(formattedCurrency(hours * rate * multiplier, currency: currency))
                            .font(.caption)
                            .foregroundColor(validationColor)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
    
}

struct MealCalendarRow: View {
    let entry: MealEntry
    let employer: Employer?

    var isValidated: Bool {
        entry.value(forKey: "isValidated") as? Bool ?? false
    }
    
    var validationColor: Color {
        isValidated ? .blue : .primary
    }

    var body: some View {
        HStack {
            Image(systemName: "fork.knife")
                .foregroundColor(isValidated ? .blue : .green)
            VStack(alignment: .leading) {
                HStack {
                    Text(entry.mealType ?? "")
                        .font(.subheadline)
                        .foregroundColor(validationColor)
                    if isValidated {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                            .font(.caption)
                    }
                }
            }
            Spacer()
            VStack(alignment: .trailing) {
                if let employer = employer {
                    Text(employer.name ?? "")
                        .font(.subheadline)
                        .foregroundColor(validationColor)
                }
            }
        }
        .padding(.vertical, 4)
    }

}

struct LeaveCalendarRow: View {
    let entry: LeaveEntry

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "calendar.badge.minus")
                        .foregroundColor(.purple)
                        .font(.caption)
                    Text(entry.leaveType.label)
                        .font(.caption)
                        .foregroundColor(.purple)
                }
                if let date = entry.date {
                    if let endDate = entry.endDate {
                        Text("Du \(date.formatted(date: .abbreviated, time: .omitted)) au \(endDate.formatted(date: .abbreviated, time: .omitted))")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    } else {
                        Text(date.formatted(date: .abbreviated, time: .omitted))
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                }
                if let reason = entry.reason, !reason.isEmpty {
                    Text(reason)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct HolidayCalendarRow: View {
    let holiday: PublicHoliday

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .foregroundColor(.brown)
                        .font(.caption)
                    Text("Jour férié")
                        .font(.caption)
                        .foregroundColor(.brown)
                }
                Text(holiday.label ?? "")
                    .font(.subheadline)
                    .foregroundColor(.primary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct TypicalWeekDayCalendarRow: View {
    let employer: Employer

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundColor(.blue)
                        .font(.caption)
                    Text("Jour travaillé")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                Text("Semaine type — \(employer.name ?? "")")
                    .font(.subheadline)
                    .foregroundColor(.primary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    let context = CoreDataManager.shared.container.viewContext
    let profile1 = OvertimeProfile(context: context)
    profile1.id = UUID()
    profile1.name = "Profil Test 1"
    profile1.hourlyRate = 15.0
    let profile2 = OvertimeProfile(context: context)
    profile2.id = UUID()
    profile2.name = "Profil Test 2"
    profile2.hourlyRate = 20.0
    
    return CalendarView(overtimeProfiles: [profile1, profile2], currency: "EUR")
        .environment(\.managedObjectContext, context)
} 