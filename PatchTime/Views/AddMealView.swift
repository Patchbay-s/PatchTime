import SwiftUI
import CoreData

struct AddMealView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedDate = Date()
    @State private var mealType = "Déjeuner"
    @State private var selectedEmployer: Employer?
    @State private var showToast = false

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Employer.name, ascending: true)],
        animation: .default)
    private var employers: FetchedResults<Employer>

    let mealTypes = ["Déjeuner", "Dîner", "Autre"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Date")) {
                    DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                }
                
                Section(header: Text("Employeur")) {
                    Picker("Employeur", selection: $selectedEmployer) {
                        Text("Sans employeur").tag(Optional<Employer>.none)
                        ForEach(employers) { employer in
                            Text(employer.name ?? "").tag(Optional(employer))
                        }
                    }
                }
                
                Section(header: Text("Type de repas")) {
                    Picker("Type", selection: $mealType) {
                        ForEach(mealTypes, id: \.self) { type in
                            Text(type)
                        }
                    }
                }
            }
            .navigationTitle("Ajouter un repas")
            .toast(isPresented: $showToast, message: "Repas enregistré")
            .navigationBarItems(
                leading: Button("Annuler") {
                    dismiss()
                },
                trailing: Button("Ajouter") {
                    addMeal()
                }
            )
        }
    }
    
    private func addMeal() {
        CoreDataManager.shared.addMealEntry(
            date: selectedDate,
            mealType: mealType,
            category: nil,
            employerID: selectedEmployer?.id
        )
        showToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { dismiss() }
    }
}

#Preview {
    AddMealView()
        .environment(\.managedObjectContext, CoreDataManager.shared.container.viewContext)
} 