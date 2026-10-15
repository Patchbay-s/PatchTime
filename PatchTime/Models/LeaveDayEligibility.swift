import Foundation

extension Array where Element == Employer {
    /// Vrai si `date` doit être considérée comme un jour de CP/Récup valide compte tenu du
    /// rythme de la Semaine type : un CP/Récup ne compte (et ne s'affiche) que si le jour de la
    /// semaine concerné fait partie des jours "travaillé" de la Semaine type d'au moins un
    /// employeur qui en a une active. Si aucun employeur n'a de Semaine type active, aucune
    /// restriction — comportement historique préservé pour les utilisateurs qui n'utilisent pas
    /// cette fonctionnalité.
    func isEligibleLeaveDay(_ date: Date, calendar: Calendar = .current) -> Bool {
        let activeEmployers = filter { $0.typicalWeekEnabled }
        guard !activeEmployers.isEmpty else { return true }
        guard let weekday = Weekday.from(calendarWeekday: calendar.component(.weekday, from: date)) else { return false }
        return activeEmployers.contains { $0.isTypicalWeekWorked(weekday) }
    }
}
