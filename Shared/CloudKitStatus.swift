//
//  CloudKitStatus.swift
//  heatlab
//
//  Monitors iCloud account status for CloudKit sync
//

import CloudKit
import Observation

@Observable
@MainActor
final class CloudKitStatus {
    var accountStatus: CKAccountStatus = .couldNotDetermine
    var isAvailable: Bool { accountStatus == .available }
    
    init() {
        Task {
            await checkAccountStatus()
            observeAccountChanges()
        }
    }
    
    func checkAccountStatus() async {
        do {
            accountStatus = try await CKContainer(identifier: "iCloud.com.macpheelabs.heatlab").accountStatus()
        } catch {
            accountStatus = .couldNotDetermine
        }
    }
    
    private func observeAccountChanges() {
        NotificationCenter.default.addObserver(
            forName: .CKAccountChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.checkAccountStatus()
            }
        }
    }
}

