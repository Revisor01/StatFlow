//
//  PrivacyFlowWidget.swift
//  PrivacyFlowWidget
//

import WidgetKit
import SwiftUI

// MARK: - Widget

struct PrivacyFlowWidget: Widget {
    let kind: String = "PrivacyFlowWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigureWidgetIntent.self, provider: Provider()) { entry in
            if #available(iOS 17.0, *) {
                PrivacyFlowWidgetEntryView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                PrivacyFlowWidgetEntryView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("widget.displayName")
        .description("widget.description")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview(as: .systemSmall) {
    PrivacyFlowWidget()
} timeline: {
    StatsEntry(date: .now, data: .placeholder, configuration: ConfigureWidgetIntent())
}

#Preview(as: .systemMedium) {
    PrivacyFlowWidget()
} timeline: {
    StatsEntry(date: .now, data: .placeholder, configuration: ConfigureWidgetIntent())
}
