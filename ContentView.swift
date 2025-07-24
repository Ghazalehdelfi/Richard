//
//  ContentView.swift
//  Richard
//
//  Created by Ghazaleh Delfi on 2025-07-16.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = StudyViewModel()
    
    var body: some View {
        VStack(spacing: 30) {
            // Status indicator at the top
            if viewModel.isStudying {
                statusIndicator
                    .padding(.top)
            }
            
            Spacer()
            
            // Status indicator and main content area
            switch viewModel.studyState {
            case .idle:
                idleStateView
            case .listening:
                listeningStateView
            case .processing:
                processingStateView
            case .displaying(let definition):
                displayingStateView(definition: definition)
            case .error(let message):
                errorStateView(message: message)
            }
            
            Spacer()
            
            // Study/Stop button
            studyButton
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Status Indicator
    
    private var statusIndicator: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
                .scaleEffect(viewModel.isStudying ? 1.2 : 1.0)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: viewModel.isStudying)
            
            Text(statusText)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var statusColor: Color {
        switch viewModel.studyState {
        case .idle:
            return .gray
        case .listening:
            return .green
        case .processing:
            return .orange
        case .displaying:
            return .blue
        case .error:
            return .red
        }
    }
    
    private var statusText: String {
        switch viewModel.studyState {
        case .idle:
            return "Ready"
        case .listening:
            return "Listening..."
        case .processing:
            return "Processing word..."
        case .displaying:
            return "Speaking definition"
        case .error:
            return "Error"
        }
    }
    
    // MARK: - State Views
    
    private var idleStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "book.circle")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            Text("Richard")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Your Talking Dictionary")
                .font(.title2)
                .foregroundColor(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Richard, Your Talking Dictionary. Ready to start studying.")
    }
    
    private var listeningStateView: some View {
        VStack(spacing: 20) {
            // Animated listening indicator
            ZStack {
                Circle()
                    .stroke(Color.green.opacity(0.3), lineWidth: 4)
                    .frame(width: 120, height: 120)
                
                Circle()
                    .fill(Color.green)
                    .frame(width: 80, height: 80)
                    .scaleEffect(viewModel.isStudying ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: viewModel.isStudying)
                
                Image(systemName: "mic.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.white)
            }
            
            Text("Listening...")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.green)
            
            Text("Say a word to get its definition")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Listening for words. Say a word to get its definition.")
    }
    
    private var processingStateView: some View {
        VStack(spacing: 20) {
            // Processing indicator
            ZStack {
                Circle()
                    .stroke(Color.orange.opacity(0.3), lineWidth: 4)
                    .frame(width: 120, height: 120)
                
                Circle()
                    .fill(Color.orange)
                    .frame(width: 80, height: 80)
                
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
            }
            
            Text("Processing...")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.orange)
            
            if let word = viewModel.currentWord {
                Text("Looking up \"\(word)\"")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Processing. Looking up \(viewModel.currentWord ?? "word")")
    }
    
    private func displayingStateView(definition: WordDefinition) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Word header
                VStack(alignment: .leading, spacing: 8) {
                    Text(definition.word.capitalized)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    if let phonetic = definition.phonetic {
                        Text(phonetic)
                            .font(.title3)
                            .foregroundColor(.secondary)
                            .italic()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Divider()
                
                // Meanings and definitions
                ForEach(Array(definition.meanings.enumerated()), id: \.offset) { index, meaning in
                    VStack(alignment: .leading, spacing: 12) {
                        // Part of speech
                        Text(meaning.partOfSpeech.capitalized)
                            .font(.headline)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                        
                        // Definitions
                        ForEach(Array(meaning.definitions.prefix(2).enumerated()), id: \.offset) { defIndex, definition in
                            VStack(alignment: .leading, spacing: 8) {
                                Text("\(defIndex + 1). \(definition.definition)")
                                    .font(.body)
                                    .foregroundColor(.primary)
                                
                                if let example = definition.example {
                                    Text("Example: \(example)")
                                        .font(.callout)
                                        .foregroundColor(.secondary)
                                        .italic()
                                        .padding(.leading, 16)
                                }
                            }
                        }
                    }
                    .padding(.bottom, index < definition.meanings.count - 1 ? 16 : 0)
                }
                
                // Audio indicator
                HStack {
                    Image(systemName: "speaker.wave.2.fill")
                        .foregroundColor(.green)
                    Text("Playing definition...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .cornerRadius(12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Definition for \(definition.word). \(formatDefinitionForAccessibility(definition))")
    }
    
    private func errorStateView(message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.red)
            
            Text("Error")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.red)
            
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Error: \(message)")
    }
    
    // MARK: - Study Button
    
    private var studyButton: some View {
        Button(action: {
            if viewModel.isStudying {
                viewModel.stopStudySession()
            } else {
                viewModel.startStudySession()
            }
        }) {
            HStack(spacing: 12) {
                Image(systemName: viewModel.isStudying ? "stop.fill" : "play.fill")
                    .font(.title2)
                
                Text(viewModel.isStudying ? "Stop Study" : "Start Study")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 40)
            .padding(.vertical, 16)
            .background(viewModel.isStudying ? Color.red : Color.blue)
            .cornerRadius(25)
        }
        .accessibilityLabel(viewModel.isStudying ? "Stop study session" : "Start study session")
        .accessibilityHint(viewModel.isStudying ? "Stops listening for words" : "Begins listening for words to define")
    }
    
    // MARK: - Helper Methods
    
    private func formatDefinitionForAccessibility(_ definition: WordDefinition) -> String {
        let firstMeaning = definition.meanings.first
        let partOfSpeech = firstMeaning?.partOfSpeech ?? ""
        let firstDefinition = firstMeaning?.definitions.first?.definition ?? ""
        
        return "\(partOfSpeech). \(firstDefinition)"
    }
}

#Preview {
    ContentView()
}
