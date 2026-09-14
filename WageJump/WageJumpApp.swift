//
//  WageJumpApp.swift
//  WageJump
//
//  Created by 蒋志聪 on 20/07/2026.
//

import SwiftUI
import WidgetKit

@main
struct WageJumpApp: App {
    @StateObject private var viewModel = DashboardViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
#if os(macOS)
                .frame(minWidth: 420, minHeight: 560)
#endif
                .background(AppColors.pageBackground.ignoresSafeArea())
                .onAppear {
                    viewModel.recalculate()
                    WidgetCenter.shared.reloadTimelines(ofKind: "WageJumpWidget")
                }
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active else { return }
                    viewModel.recalculate()
                    WidgetCenter.shared.reloadTimelines(ofKind: "WageJumpWidget")
                }
        }
#if os(macOS)
        .defaultSize(width: 520, height: 760)
        .windowResizability(.contentMinSize)
#endif
    }
}
