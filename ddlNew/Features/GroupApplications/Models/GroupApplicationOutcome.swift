// Created by taobo on 2026/10/13.
import Foundation

struct GroupApplicationOutcome: Sendable {
    let successfulIDs: Set<String>
    let failedIDs: Set<String>
}
