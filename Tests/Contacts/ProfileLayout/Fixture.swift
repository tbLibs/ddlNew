import SwiftUI
import UIAdapter

enum MessagingTheme {
    static let background = Color.white
    static let surface = Color.white
    static let accent = Color.green
    static let text = Color.black
    static let secondaryText = Color.gray
    static let pressed = Color.gray
    static let divider = Color.gray
    static let primaryAction = Color.green
    static let onPrimaryAction = Color.white
}
struct ProfileFixture: View {
    let description: String
    var remarks = ""
    var contact: ProfileContact? { ProfileContact(description: description, remarks: remarks) }
    var cachedContact: ProfileContact? { contact }
    let groupAccessAllowed = true
    let wasFriend = false
    let isFriend = true
    let fileHost: URL? = nil
    let sourceGroupID: String? = nil
    let contactID = "test-peer"
    let businessStore = ProfileBusiness()
    let permissions = ProfilePermissions()
    @State private var editing = false
    var body: some View {
        // PRODUCTION_PROFILE_CONTENT
    }
    private func copyAccount(_ contact: ProfileContact) {}
    private func sendMessage(to contact: ProfileContact) {}
    private func applicationAction(_ contact: ProfileContact) -> some View { EmptyView() }
    // PRODUCTION_DETAIL
}
struct ProfileContact {
    let description: String
    let remarks: String
    var displayName: String { remarks.isEmpty ? nickname : remarks }
    let id = "test-peer", nickname = "匿名好友", account = "test-account", roleID = "0"
    let isDeleted = false, isOnline = true
    let userType = 0
}
struct ProfileBusiness {
    struct Identity { let userUID = "test-self" }
    let identity: Identity? = Identity()
    let blackStates = ["test-peer": false]
    let isSubmitting = false, isLoading = false
    func roleName(roleID: String, isDeleted: Bool) -> String? { nil }
    func groupNickname(in group: String, for id: String) -> String? { nil }
}
struct ProfilePermissions {
    struct Permission { func allows(_ key: String) -> Bool { false } }
    let current: Permission? = Permission()
}
struct ContactRecordAvatar: View {
    let contact: ProfileContact
    let fileHost: URL?
    let size: CGFloat
    var body: some View { Circle().fill(Color.gray).frame(width: size, height: size) }
}
struct EmptyClubState: View {
    let title: String, message: String
    var body: some View { Text(title + message) }
}
