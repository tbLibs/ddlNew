//
//  CommunityFilters.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import SwiftUI

struct CommunityFilters<Filter: CaseIterable & Identifiable & RawRepresentable & Hashable>: View where Filter.RawValue == String, Filter.AllCases: RandomAccessCollection {
    @Binding var selection: Filter
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
            ForEach(Filter.allCases) { item in
                Button { selection = item } label: {
                    Text(item.rawValue).font(.subheadline.weight(selection == item ? .semibold : .regular))
                        .foregroundColor(selection == item ? .white : ClubTheme.secondary)
                        .padding(.horizontal, 22).frame(minHeight: 44)
                        .background(selection == item ? ClubTheme.darkTeal : ClubTheme.card)
                        .clipShape(Capsule())
                }.accessibilityAddTraits(selection == item ? .isSelected : [])
            }
            }
        }
    }
}
