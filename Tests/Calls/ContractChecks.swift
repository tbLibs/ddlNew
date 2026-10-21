import Foundation
@main struct Checks {
 static func main() throws {
  let a = CallRequestPayload.create(provider: .liveKit, groupID: nil, kind: .audio, ids: ["b"])
  precondition(a["to_id"] as? String == "b" && a["mode"] as? Int == 1)
  let v = CallRequestPayload.create(provider: .liveKit, groupID: "g", kind: .video, ids: ["b", "c"])
  precondition(v["to_id"] as? [String] == ["b", "c"] && v["mode"] as? Int == 0)
  let z = CallRequestPayload.create(provider: .zego, groupID: "g", kind: .video, ids: ["b"])
  precondition(z["callType"] as? String == "Video" && z["chatType"] as? String == "GROUP_CHAT")
  precondition(z["friendIds"] as? [String] == ["b"])
  let invite = CallRequestPayload.invite(provider: .liveKit, roomID: "r", ids: ["b"])
  precondition(invite["user_id"] as? [String] == ["b"] && invite["hash"] as? String == "r")
  precondition(CallPolicy.groupCanCall(active: true, prohibited: true, role: 0) == false)
  precondition(CallPolicy.groupCanCall(active: true, prohibited: true, role: 1))
  precondition(CallPolicy.groupCanCall(active: true, prohibited: true, role: 2))
  precondition(!CallPolicy.groupCanCall(active: false, prohibited: false, role: 2))
  precondition(CallPolicy.endReason(incoming: true, connected: false) == "refused")
  precondition(CallPolicy.endReason(incoming: false, connected: false) == "cancel")
  precondition(CallPolicy.endReason(incoming: true, connected: true) == "")
  print("Calls: protocol payload and policy checks passed")
 }
}
