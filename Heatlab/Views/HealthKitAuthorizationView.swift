//
//  HealthKitAuthorizationView.swift
//  heatlab
//
//  Onboarding view for HealthKit permissions
//

import SwiftUI
import HealthKit

struct HealthKitAuthorizationView: View {
    @State private var isAuthorizing = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    let onComplete: () -> Void
    
    private let healthStore = HKHealthStore()
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.red.opacity(0.8), .orange.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(.white)
            }
            
            // Title
            Text("Connect to Health")
                .font(.title.bold())
            
            // Description
            Text("Heatlab needs access to your health data to track workouts and heart rate during your hot yoga sessions.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            // Data types
            VStack(alignment: .leading, spacing: 16) {
                DataTypeRow(icon: "heart.fill", color: .red, title: "Heart Rate", description: "Track intensity during sessions")
                DataTypeRow(icon: "flame.fill", color: .orange, title: "Active Calories", description: "Measure energy expenditure")
                DataTypeRow(icon: "figure.yoga", color: .purple, title: "Workouts", description: "Log your yoga sessions")
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)
            
            Spacer()
            
            // Enable button
            Button {
                requestAuthorization()
            } label: {
                HStack {
                    if isAuthorizing {
                        ProgressView()
                            .tint(.white)
                    }
                    Text("Enable HealthKit")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        colors: [.orange, .red],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(isAuthorizing)
            .padding(.horizontal)
            
            // Skip button
            Button("Skip for Now") {
                onComplete()
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.bottom)
        }
        .alert("Authorization Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
    }
    
    private func requestAuthorization() {
        isAuthorizing = true
        
        let typesToShare: Set<HKSampleType> = [.workoutType()]
        let typesToRead: Set<HKObjectType> = [
            .workoutType(),
            HKQuantityType(.heartRate),
            HKQuantityType(.activeEnergyBurned)
        ]
        
        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { success, error in
            DispatchQueue.main.async {
                isAuthorizing = false
                
                if let error = error {
                    errorMessage = error.localizedDescription
                    showError = true
                } else {
                    onComplete()
                }
            }
        }
    }
}

struct DataTypeRow: View {
    let icon: String
    let color: Color
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    HealthKitAuthorizationView {
        print("Authorization complete")
    }
}

