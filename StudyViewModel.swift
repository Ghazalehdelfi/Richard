//
//  StudyViewModel.swift
//  Richard
//
//  Created by Kiro on 2025-07-16.
//

import Foundation
import SwiftUI
import Combine
import AVFoundation



// MARK: - Study View Model

@MainActor
class StudyViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var isStudying = false
    @Published var currentWord: String?
    @Published var definition: WordDefinition?
    @Published var studyState: StudyState = .idle
    @Published var errorMessage: String?

    
    // MARK: - Services
    
    private let speechRecognizer = DefaultSpeechRecognizer()
    private let dictionaryService = DictionaryAPIService()
    private let textToSpeechService = TextToSpeechService()
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private var wasStudyingBeforeBackground = false
    
    // MARK: - Initialization
    
    init() {
        setupSpeechRecognizer()
        setupAppLifecycleObservers()
        setupAudioSessionObservers()
    }
    
    // MARK: - Setup Methods
    
    private func setupSpeechRecognizer() {
        speechRecognizer.delegate = self
    }
    

    
    private func setupAppLifecycleObservers() {
        // Observe app lifecycle notifications
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleAppWillResignActive()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleAppDidBecomeActive()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleAppDidEnterBackground()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleAppWillEnterForeground()
            }
            .store(in: &cancellables)
    }
    
    private func setupAudioSessionObservers() {
        // Observe audio session interruptions
        NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleAudioSessionInterruption(notification)
            }
            .store(in: &cancellables)
        
        // Observe audio route changes
        NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleAudioRouteChange(notification)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    func startStudySession() {
        guard !isStudying else { return }
        
        Task {
            do {
                // Clear any previous state
                clearCurrentState()
                
                // Update state to listening
                updateState(.listening)
                isStudying = true
                
                // Start speech recognition
                try await speechRecognizer.startListening()
                
            } catch {
                await handleError(error)
            }
        }
    }
    
    func stopStudySession() {
        guard isStudying else { return }
        
        // Stop all services with proper cleanup
        speechRecognizer.stopListening()
        textToSpeechService.stopSpeaking()
        
        // Reset state
        isStudying = false
        updateState(.idle)
        clearCurrentState()
    }
    
    func processDetectedWord(_ word: String) {
        guard isStudying else { return }
        
        Task {
            do {
                // Stop listening to prevent feedback loop
                speechRecognizer.stopListening()
                
                // Update state to processing
                currentWord = word
                updateState(.processing)
                
                // Fetch definition from API
                let wordDefinition = try await dictionaryService.fetchDefinition(for: word)
                
                // Update state to displaying
                definition = wordDefinition
                updateState(.displaying(wordDefinition))
                
                // Speak the definition
                let definitionText = formatDefinitionForSpeech(wordDefinition)
                textToSpeechService.speak(definitionText)
                
                // Schedule return to listening after speech finishes
                scheduleReturnToListening()
                
            } catch {
                await handleError(error)
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func updateState(_ newState: StudyState) {
        studyState = newState
        errorMessage = nil
    }
    
    private func clearCurrentState() {
        currentWord = nil
        definition = nil
        errorMessage = nil
    }
    
    private func formatDefinitionForSpeech(_ wordDefinition: WordDefinition) -> String {
        let word = wordDefinition.word
        let firstMeaning = wordDefinition.meanings.first
        let partOfSpeech = firstMeaning?.partOfSpeech ?? ""
        let firstDefinition = firstMeaning?.definitions.first?.definition ?? "No definition available"
        
        return "\(word), \(partOfSpeech). \(firstDefinition)"
    }
    

    
    func handleError(_ error: Error) async {
        let errorMessage = formatErrorMessage(error)
        
        self.errorMessage = errorMessage
        updateState(.error(errorMessage))
        
        // For certain errors, stop the study session
        if shouldStopSessionForError(error) {
            stopStudySession()
        } else {
            // For recoverable errors, return to listening after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                if self.isStudying {
                    self.updateState(.listening)
                }
            }
        }
    }
    
    private func formatErrorMessage(_ error: Error) -> String {
        switch error {
        case DictionaryAPIError.wordNotFound:
            return "Word not found in dictionary"
        case DictionaryAPIError.networkError:
            return "Check internet connection"
        case DictionaryAPIError.invalidURL, DictionaryAPIError.noData, DictionaryAPIError.decodingError:
            return "Dictionary service unavailable"
        case SpeechRecognitionError.notAuthorized:
            return "Microphone access required. Please enable in Settings."
        case SpeechRecognitionError.microphoneUnavailable:
            return "Microphone not accessible"
        case SpeechRecognitionError.recognizerUnavailable:
            return "Speech recognition unavailable"
        case SpeechRecognitionError.audioEngineUnavailable, SpeechRecognitionError.audioSessionError:
            return "Audio system error"
        case SpeechRecognitionError.recognitionFailed:
            return "Speech recognition failed"
        default:
            return "An unexpected error occurred"
        }
    }
    
    private func shouldStopSessionForError(_ error: Error) -> Bool {
        switch error {
        case SpeechRecognitionError.notAuthorized,
             SpeechRecognitionError.microphoneUnavailable,
             SpeechRecognitionError.recognizerUnavailable,
             SpeechRecognitionError.audioEngineUnavailable:
            return true
        default:
            return false
        }
    }
    
    private func isProcessingState() -> Bool {
        if case .processing = studyState {
            return true
        }
        return false
    }
    
    private func scheduleReturnToListening() {
        // Wait for text-to-speech to finish, then return to listening
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.checkAndReturnToListening()
        }
    }
    
    private func checkAndReturnToListening() {
        // Check if text-to-speech has finished
        if !textToSpeechService.isSpeaking && isStudying {
            if case .displaying = studyState {
                // Wait a bit more for user to read, then return to listening
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    if self.isStudying {
                        if case .displaying = self.studyState {
                            self.updateState(.listening)
                            // Restart speech recognition
                            Task {
                                do {
                                    try await self.speechRecognizer.startListening()
                                } catch {
                                    await self.handleError(error)
                                }
                            }
                        }
                    }
                }
            }
        } else if textToSpeechService.isSpeaking {
            // Still speaking, check again in 1 second
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.checkAndReturnToListening()
            }
        }
    }
    
    // MARK: - App Lifecycle Handlers
    
    private func handleAppWillResignActive() {
        // App is about to become inactive (e.g., incoming call, control center)
        // Pause speech recognition but don't fully stop the session
        if isStudying {
            speechRecognizer.stopListening()
            textToSpeechService.stopSpeaking()
        }
    }
    
    private func handleAppDidBecomeActive() {
        // App became active again
        // Resume speech recognition if we were studying
        if isStudying && !isProcessingState() {
            Task {
                do {
                    try await speechRecognizer.startListening()
                    if case .error = studyState {
                        updateState(.listening)
                    }
                } catch {
                    await handleError(error)
                }
            }
        }
    }
    
    private func handleAppDidEnterBackground() {
        // App entered background - stop study session to conserve resources
        if isStudying {
            wasStudyingBeforeBackground = true
            stopStudySession()
        } else {
            wasStudyingBeforeBackground = false
        }
    }
    
    private func handleAppWillEnterForeground() {
        // App is about to enter foreground
        // We'll handle resumption in didBecomeActive if needed
        // This is just preparation
    }
    
    // MARK: - Audio Session Handlers
    
    private func handleAudioSessionInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            // Audio interruption began (e.g., phone call)
            if isStudying {
                speechRecognizer.stopListening()
                textToSpeechService.stopSpeaking()
            }
            
        case .ended:
            // Audio interruption ended
            if isStudying {
                // Check if we should resume
                if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                    let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                    if options.contains(.shouldResume) {
                        // Resume after a short delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            if self.isStudying {
                                Task {
                                    do {
                                        try await self.speechRecognizer.startListening()
                                        if case .error = self.studyState {
                                            self.updateState(.listening)
                                        }
                                    } catch {
                                        await self.handleError(error)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
        @unknown default:
            break
        }
    }
    
    private func handleAudioRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        switch reason {
        case .oldDeviceUnavailable:
            // Audio device was removed (e.g., headphones unplugged)
            if isStudying {
                // Stop current speech and pause briefly
                textToSpeechService.stopSpeaking()
                speechRecognizer.stopListening()
                
                // Resume after a brief delay to allow audio route to stabilize
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    if self.isStudying {
                        Task {
                            do {
                                try await self.speechRecognizer.startListening()
                                if case .error = self.studyState {
                                    self.updateState(.listening)
                                }
                            } catch {
                                await self.handleError(error)
                            }
                        }
                    }
                }
            }
            
        default:
            // Other route changes don't require special handling
            break
        }
    }
    
    // MARK: - Cleanup
    
    deinit {
        // Ensure proper cleanup when the view model is deallocated
        // Note: deinit is not on MainActor, so we need to handle cleanup carefully
        cancellables.removeAll()
        
        // Stop services directly without going through MainActor methods
        speechRecognizer.stopListening()
        // Don't call textToSpeechService.cleanup() from deinit to avoid threading issues
    }
}

// MARK: - SpeechRecognizerDelegate

extension StudyViewModel: SpeechRecognizerDelegate {
    nonisolated func speechRecognizer(_ recognizer: any SpeechRecognizer, didDetectWord word: String) {
        Task { @MainActor in
            processDetectedWord(word)
        }
    }
    
    nonisolated func speechRecognizer(_ recognizer: any SpeechRecognizer, didEncounterError error: SpeechRecognitionError) {
        Task { @MainActor in
            await handleError(error)
        }
    }
}
