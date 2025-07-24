//
//  DictionaryAPIService.swift
//  Richard
//
//  Created by Kiro on 2025-07-23.
//

import Foundation

// MARK: - Dictionary API Error Types

enum DictionaryAPIError: Error {
    case invalidURL
    case noData
    case wordNotFound
    case networkError(Error)
    case decodingError(Error)
}

// MARK: - Dictionary API Service

class DictionaryAPIService {
    private let baseURL = "https://api.dictionaryapi.dev/api/v2/entries/en/"
    private let session = URLSession.shared
    
    func fetchDefinition(for word: String) async throws -> WordDefinition {
        guard let url = URL(string: baseURL + word.lowercased()) else {
            throw DictionaryAPIError.invalidURL
        }
        
        do {
            let (data, response) = try await session.data(from: url)
            
            // Check HTTP response status
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 404 {
                    throw DictionaryAPIError.wordNotFound
                }
                if httpResponse.statusCode != 200 {
                    throw DictionaryAPIError.networkError(NSError(domain: "HTTPError", code: httpResponse.statusCode))
                }
            }
            
            guard !data.isEmpty else {
                throw DictionaryAPIError.noData
            }
            
            // The API returns an array of definitions, we'll take the first one
            let definitions = try JSONDecoder().decode([WordDefinition].self, from: data)
            
            guard let firstDefinition = definitions.first else {
                throw DictionaryAPIError.wordNotFound
            }
            
            return firstDefinition
            
        } catch let error as DecodingError {
            throw DictionaryAPIError.decodingError(error)
        } catch let error as DictionaryAPIError {
            throw error
        } catch {
            throw DictionaryAPIError.networkError(error)
        }
    }
}