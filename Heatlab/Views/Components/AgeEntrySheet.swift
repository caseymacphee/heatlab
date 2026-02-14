//
//  AgeEntrySheet.swift
//  heatlab
//
//  Modal sheet for collecting user age for heart rate zone calculation
//

import SwiftUI
import HealthKit

struct AgeEntrySheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(UserSettings.self) var settings

    @State private var selectedAge: Int = 30
    @State private var hasLoadedFromHealthKit = false

    private let healthStore = HKHealthStore()

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "heart.text.clipboard")
                        .font(.largeTitle)
                        .foregroundStyle(Color.hlAccent)

                    Text("Heart Rate Zones")
                        .font(.title2.bold())

                    Text("Enter your age to calculate personalized heart rate zones using the standard 220-age formula.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                // Age picker
                VStack(spacing: 4) {
                    Text("Age")
                        .font(.headline)

                    Picker("Age", selection: $selectedAge) {
                        ForEach(13...120, id: \.self) { age in
                            Text("\(age)").tag(age)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 150)
                }

                // Zone preview
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your Zone Ranges")
                        .font(.subheadline.bold())

                    let maxHR = ZoneCalculator.maxHeartRate(age: selectedAge)

                    ForEach(HeartRateZone.allCases, id: \.rawValue) { zone in
                        let range = zone.bpmRange(maxHR: maxHR)
                        HStack(spacing: 8) {
                            Circle()
                                .fill(zone.color)
                                .frame(width: 10, height: 10)
                            Text(zone.label)
                                .font(.caption)
                            Text(zone.intensityLabel)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(Int(range.lowerBound))–\(Int(range.upperBound)) bpm")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color.hlSurface)
                .clipShape(RoundedRectangle(cornerRadius: HLRadius.card))

                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        settings.userAge = selectedAge
                        dismiss()
                    }
                }
            }
            .onAppear {
                // Pre-populate from existing setting or HealthKit
                if let existingAge = settings.userAge {
                    selectedAge = existingAge
                } else if !hasLoadedFromHealthKit {
                    hasLoadedFromHealthKit = true
                    if let hkAge = HealthKitUtility.fetchDateOfBirth(healthStore: healthStore) {
                        selectedAge = hkAge
                        // Auto-save HealthKit age so zones work immediately
                        settings.userAge = hkAge
                    }
                }
            }
        }
    }
}

#Preview {
    AgeEntrySheet()
        .environment(UserSettings())
}
