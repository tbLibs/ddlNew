//
//  GroupRole.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Foundation

/// 与SDK群角色数字保持一致，不能将未知角色当作管理员。
nonisolated enum GroupRole: Int, Sendable { case member = 0, administrator = 1, owner = 2 }
