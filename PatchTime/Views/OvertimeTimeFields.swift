import SwiftUI

/// Contenu de la section « Date et Heures » partagé par l'ajout et la modification d'heures :
/// boutons rapides, date, roues début / fin, choix Même jour / Lendemain (+1 j), erreur,
/// réinitialisation de la fin et durée. Toute la logique est dans `OvertimeTimeInput`.
struct OvertimeTimeFields: View {
    @Binding var input: OvertimeTimeInput

    private var durationText: String {
        let range = input.range()
        return formattedDuration(from: overtimeDuration(from: range.start, to: range.end))
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                quickActionBubble(title: "+15 min") { input.extendEnd(byMinutes: 15) }
                quickActionBubble(title: "+1 h") { input.extendEnd(byMinutes: 60) }
                quickActionBubble(title: "Copier début → fin") { input.copyStartToEnd() }
            }
            .padding(.vertical, 4)
        }

        DatePicker("Date", selection: $input.day, displayedComponents: .date)

        timeWheelRow(
            label: "Heure de début",
            minutes: Binding(get: { input.startMinutes }, set: { input.setStart($0) })
        )
        timeWheelRow(
            label: "Heure de fin",
            minutes: Binding(get: { input.endMinutes }, set: { input.setEnd($0) })
        )

        VStack(alignment: .leading, spacing: 8) {
            Picker("Jour de fin", selection: Binding(get: { input.endsNextDay }, set: { input.setEndsNextDay($0) })) {
                Text("Même jour").tag(false)
                Text("Lendemain (+1 j)").tag(true)
            }
            .pickerStyle(.segmented)

            HStack(spacing: 6) {
                if input.endsNextDay {
                    Image(systemName: "moon.stars")
                        .foregroundStyle(.secondary)
                }
                Text(input.endText)
                    .fontWeight(.semibold)
                Spacer()
                Text("fin le \(SharedFormatters.frenchLongDate.string(from: input.endDay()))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)

            if let problem = input.problem {
                Label(problem.message, systemImage: "exclamationmark.circle.fill")
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)

        Button {
            input.resetEnd()
        } label: {
            Label("Réinitialiser la fin", systemImage: "arrow.uturn.backward")
        }

        HStack {
            Text("Durée")
            Spacer()
            Text(durationText)
                .foregroundColor(input.isValid ? .green : .red)
                .fontWeight(.semibold)
        }
    }

    private func quickActionBubble(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
    }

    private func timeWheelRow(label: String, minutes: Binding<Int>) -> some View {
        let hour = minutes.wrappedValue / 60
        let minute = minutes.wrappedValue % 60
        // 23:59 (réinitialisation) ou saisie ancienne hors pas de 15 min : valeur affichée telle quelle.
        let minuteOptions = Set([0, 15, 30, 45, minute]).sorted()

        return VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack(spacing: 0) {
                Picker("Heures", selection: Binding(
                    get: { hour },
                    set: { minutes.wrappedValue = $0 * 60 + minute }
                )) {
                    ForEach(0...23, id: \.self) { value in
                        Text(String(format: "%02d", value)).tag(value)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
                .clipped()

                Picker("Minutes", selection: Binding(
                    get: { minute },
                    set: { minutes.wrappedValue = hour * 60 + $0 }
                )) {
                    ForEach(minuteOptions, id: \.self) { value in
                        Text(String(format: "%02d", value)).tag(value)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
                .clipped()
            }
            .frame(height: 120)
        }
    }
}
