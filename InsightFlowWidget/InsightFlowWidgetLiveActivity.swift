import ActivityKit
import WidgetKit
import SwiftUI

struct PrivacyFlowWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var emoji: String
    }

    var name: String
}

struct PrivacyFlowWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PrivacyFlowWidgetAttributes.self) { context in
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension PrivacyFlowWidgetAttributes {
    fileprivate static var preview: PrivacyFlowWidgetAttributes {
        PrivacyFlowWidgetAttributes(name: "World")
    }
}

extension PrivacyFlowWidgetAttributes.ContentState {
    fileprivate static var smiley: PrivacyFlowWidgetAttributes.ContentState {
        PrivacyFlowWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: PrivacyFlowWidgetAttributes.ContentState {
         PrivacyFlowWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: PrivacyFlowWidgetAttributes.preview) {
   PrivacyFlowWidgetLiveActivity()
} contentStates: {
    PrivacyFlowWidgetAttributes.ContentState.smiley
    PrivacyFlowWidgetAttributes.ContentState.starEyes
}
