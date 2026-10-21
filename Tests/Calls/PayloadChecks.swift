import Foundation
struct ChatContext: Equatable, Sendable {}
@main struct PayloadChecks {
 static func main() {
  let base = CallRoomDescriptor(provider: .liveKit, id: "", groupID: "g", kind: .audio)
  let listed = SDKCallPayload.response(["hash": "h", "mode": 0, "participants": ["a", "b"]], original: base, localID: "a")
  precondition(listed.id == "h" && listed.kind == .video && listed.participants.map(\.id) == ["a", "b"])
  precondition(listed.participants.first?.isLocal == true)
  let joined = SDKCallPayload.response(["hash": "h", "mode": 1, "connection": ["endpoint": "wss://invalid.test", "token": "offline", "room": "r"], "participants": [["userUid": "a", "status": 1], ["userUid": "b", "status": 0]]], original: base, localID: "a")
  precondition(joined.endpoint == "wss://invalid.test" && joined.token == "offline" && joined.roomName == "r")
  precondition(joined.participants[0].isConnected && !joined.participants[1].isConnected)
  let zego = SDKCallPayload.response(["callId": 123, "roomId": "zg", "token": "offline", "callType": 2, "receiveUserInfo": [["userUid": "b", "nickname": "B", "avatar": "b.png"]]], original: CallRoomDescriptor(provider: .zego, id: "", kind: .audio), localID: "a")
  precondition(zego.id == "123" && zego.roomName == "zg" && zego.kind == .video && zego.participants.first?.name == "B")
  let token = SDKCallPayload.response(["token": "updated"], original: zego, localID: "a")
  precondition(token.id == "123" && token.roomName == "zg" && token.token == "updated" && token.participants.count == 1)
  precondition(SDKCallPayload.flag("true") && SDKCallPayload.flag(1) && !SDKCallPayload.flag(NSNull()))
  print("Calls: response payload checks passed")
 }
}
