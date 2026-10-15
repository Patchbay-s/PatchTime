import SwiftUI

struct RatesSettingsView: View {
    @AppStorage("vehicleFiscalPower") private var vehicleFiscalPower: Int = 5
    @AppStorage("vehicleMotorisation") private var vehicleMotorisation: String = "thermique"

    @State private var kmBareme: KmBareme = BaremeStore.kmBareme
    @State private var mealBareme: MealBareme = BaremeStore.mealBareme
    @State private var showResetConfirmation = false

    var body: some View {
        Form {
            Section(header: Text("Véhicule")) {
                Stepper("Puissance fiscale : \(vehicleFiscalPower) CV", value: $vehicleFiscalPower, in: 1...20)
                Picker("Motorisation", selection: $vehicleMotorisation) {
                    Text("Thermique").tag("thermique")
                    Text("Électrique (+20 %)").tag("electrique")
                }
            }

            Section(header: Text("Barème kilométrique"), footer: Text("Vérifié le \(kmBareme.verifiedDate) — \(kmBareme.source).")) {
                ForEach(Array(kmBareme.tiers.enumerated()), id: \.offset) { index, tier in
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(tier.fiscalPowerLabel) CV").font(.subheadline.weight(.semibold))
                        HStack {
                            Text("≤ 5000 km (coef.)")
                            Spacer()
                            TextField("", value: Binding(
                                get: { kmBareme.tiers[index].tier1Coefficient },
                                set: { setTier1Coefficient(at: index, $0) }
                            ), format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        }
                        HStack {
                            Text("5001-20000 km (coef. / fixe)")
                            Spacer()
                            TextField("coef.", value: Binding(
                                get: { kmBareme.tiers[index].tier2Coefficient },
                                set: { setTier2Coefficient(at: index, $0) }
                            ), format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                            TextField("fixe", value: Binding(
                                get: { kmBareme.tiers[index].tier2FixedAmount },
                                set: { setTier2Fixed(at: index, $0) }
                            ), format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                        }
                        HStack {
                            Text("> 20000 km (coef.)")
                            Spacer()
                            TextField("", value: Binding(
                                get: { kmBareme.tiers[index].tier3Coefficient },
                                set: { setTier3Coefficient(at: index, $0) }
                            ), format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Section(header: Text("Barème frais de repas"), footer: Text("Vérifié \(mealBareme.verifiedDate) — \(mealBareme.source).")) {
                HStack {
                    Text("Forfait repas à domicile")
                    Spacer()
                    TextField("", value: Binding(
                        get: { mealBareme.homeAllowance },
                        set: { setMealHomeAllowance($0) }
                    ), format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                }
                HStack {
                    Text("Plafond de dépense/jour")
                    Spacer()
                    TextField("", value: Binding(
                        get: { mealBareme.expenseCap },
                        set: { setMealExpenseCap($0) }
                    ), format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                }
                HStack {
                    Text("Déduction max/jour")
                    Spacer()
                    TextField("", value: Binding(
                        get: { mealBareme.maxDeduction },
                        set: { setMealMaxDeduction($0) }
                    ), format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                }
            }

            Section(header: Text("Majoration weekend / jour férié")) {
                NavigationLink(destination: EmployerListView()) {
                    Text("Se règle par profil de taux, sous chaque employeur")
                }
            }

            Section {
                Button("Réinitialiser aux valeurs par défaut 2026", role: .destructive) {
                    showResetConfirmation = true
                }
            }
        }
        .navigationTitle("Barèmes & frais")
        .alert("Réinitialiser les barèmes ?", isPresented: $showResetConfirmation) {
            Button("Annuler", role: .cancel) {}
            Button("Réinitialiser", role: .destructive) {
                BaremeStore.resetToDefaults()
                kmBareme = BaremeStore.kmBareme
                mealBareme = BaremeStore.mealBareme
            }
        } message: {
            Text("Les barèmes kilométrique et frais de repas seront restaurés aux valeurs officielles 2026. Les majorations par profil ne sont pas concernées.")
        }
    }

    // MARK: - Km bareme mutations

    private func setTier1Coefficient(at index: Int, _ value: Double) {
        updateTier(at: index) { $0 = KmBaremeTier(fiscalPowerLabel: $0.fiscalPowerLabel, tier1Coefficient: value, tier2Coefficient: $0.tier2Coefficient, tier2FixedAmount: $0.tier2FixedAmount, tier3Coefficient: $0.tier3Coefficient) }
    }

    private func setTier2Coefficient(at index: Int, _ value: Double) {
        updateTier(at: index) { $0 = KmBaremeTier(fiscalPowerLabel: $0.fiscalPowerLabel, tier1Coefficient: $0.tier1Coefficient, tier2Coefficient: value, tier2FixedAmount: $0.tier2FixedAmount, tier3Coefficient: $0.tier3Coefficient) }
    }

    private func setTier2Fixed(at index: Int, _ value: Double) {
        updateTier(at: index) { $0 = KmBaremeTier(fiscalPowerLabel: $0.fiscalPowerLabel, tier1Coefficient: $0.tier1Coefficient, tier2Coefficient: $0.tier2Coefficient, tier2FixedAmount: value, tier3Coefficient: $0.tier3Coefficient) }
    }

    private func setTier3Coefficient(at index: Int, _ value: Double) {
        updateTier(at: index) { $0 = KmBaremeTier(fiscalPowerLabel: $0.fiscalPowerLabel, tier1Coefficient: $0.tier1Coefficient, tier2Coefficient: $0.tier2Coefficient, tier2FixedAmount: $0.tier2FixedAmount, tier3Coefficient: value) }
    }

    private func updateTier(at index: Int, _ mutate: (inout KmBaremeTier) -> Void) {
        var tiers = kmBareme.tiers
        mutate(&tiers[index])
        kmBareme = KmBareme(tiers: tiers, verifiedDate: kmBareme.verifiedDate, source: kmBareme.source)
        BaremeStore.kmBareme = kmBareme
    }

    // MARK: - Meal bareme mutations

    private func setMealHomeAllowance(_ value: Double) {
        mealBareme = MealBareme(homeAllowance: value, expenseCap: mealBareme.expenseCap, maxDeduction: mealBareme.maxDeduction, verifiedDate: mealBareme.verifiedDate, source: mealBareme.source)
        BaremeStore.mealBareme = mealBareme
    }

    private func setMealExpenseCap(_ value: Double) {
        mealBareme = MealBareme(homeAllowance: mealBareme.homeAllowance, expenseCap: value, maxDeduction: mealBareme.maxDeduction, verifiedDate: mealBareme.verifiedDate, source: mealBareme.source)
        BaremeStore.mealBareme = mealBareme
    }

    private func setMealMaxDeduction(_ value: Double) {
        mealBareme = MealBareme(homeAllowance: mealBareme.homeAllowance, expenseCap: mealBareme.expenseCap, maxDeduction: value, verifiedDate: mealBareme.verifiedDate, source: mealBareme.source)
        BaremeStore.mealBareme = mealBareme
    }
}

#Preview {
    NavigationStack {
        RatesSettingsView()
    }
}
