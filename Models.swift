//
//  Models.swift
//  Richard
//
//  Created by Kiro on 2025-07-23.
//

import Foundation

// MARK: - Data Models

struct WordDefinition: Codable {
    let word: String
    let phonetic: String?
    let meanings: [Meaning]
}

struct Meaning: Codable {
    let partOfSpeech: String
    let definitions: [Definition]
}

struct Definition: Codable {
    let definition: String
    let example: String?
}

// MARK: - Study State

enum StudyState {
    case idle
    case listening
    case processing
    case displaying(WordDefinition)
    case error(String)
}