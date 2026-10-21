import SwiftUI
import UIAdapter

struct CallGroupBanner: View {
    let room: CallGroupRoom
    let join: () -> Void
    @State private var expanded = false

    var body: some View {
        VStack(spacing: 0) {
            Button { expanded.toggle() } label: {
                HStack {
                    Image(systemName: room.kind == .audio ? "phone.fill" : "video.fill")
                    Text("\(room.participants.count)人正在\(room.kind == .audio ? "语音" : "视频")通话").font(.subheadline)
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                }.padding(.horizontal, 16.zoom()).frame(minHeight: 44)
            }.buttonStyle(.plain)
            if expanded {
                HStack {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8.zoom()) {
                            ForEach(room.participants) { member in
                                CallAvatar(name: member.name, resource: member.avatar, size: 36.zoom())
                                    .accessibilityLabel(member.name).accessibilityHidden(false)
                            }
                        }
                    }
                    Button("加入", action: join).buttonStyle(.borderedProminent).frame(minHeight: 44)
                }.padding(.horizontal, 16.zoom()).padding(.bottom, 8.zoom())
            }
        }.foregroundStyle(MessagingTheme.accent).background(MessagingTheme.accent.opacity(0.08))
    }
}
