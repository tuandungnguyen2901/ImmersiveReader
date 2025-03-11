//
//  ImmersiveReaderApp.swift
//  ImmersiveReader
//
//  Created by admin on 11/3/25.
//

import SwiftUI

@main
struct ImmersiveReaderApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
