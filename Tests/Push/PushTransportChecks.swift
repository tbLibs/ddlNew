import Foundation
@main struct TransportChecks {
 @MainActor static func main() async {
  let lane=PushRequestLane(); var starts:[Int]=[]
  var finish: ((Result<Bool,Error>)->Void)?
  let first=Task { try await lane.perform { done in starts.append(1); finish=done } }
  for _ in 0..<30 { await Task.yield() }
  first.cancel()
  let second=Task { try await lane.perform { done in starts.append(2); done(.success(true)) } }
  for _ in 0..<50 { await Task.yield() }
  precondition(starts == [1],"Swift cancellation must not release actual transport lane")
  finish?(.success(true)); finish?(.success(true))
  _ = try? await first.value; _ = try? await second.value
  precondition(starts == [1,2],"next request starts only after terminal callback")
  print("Push transport lane: 2 checks passed")
 }
}
