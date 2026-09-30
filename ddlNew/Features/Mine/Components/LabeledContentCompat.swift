//
//  LabeledContentCompat.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import SwiftUI

struct LabeledContentCompat: View {
    let title: String
    let value: String
    var body: some View { HStack { Text(title); Spacer(); Text(value).foregroundColor(ClubTheme.secondary) } }
}
