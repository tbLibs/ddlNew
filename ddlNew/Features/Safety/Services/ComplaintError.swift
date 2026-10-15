//
//  ComplaintError.swift
//  ddlNew
//
//  Created by taobo on 2026/10/15.
//
import Foundation

enum ComplaintError: LocalizedError {
    case invalidInput(String)
    var errorDescription: String? { switch self { case .invalidInput(let message): return message } }
}
