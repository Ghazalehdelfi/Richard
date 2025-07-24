//
//  SpeechRecognizer.swift
//  Richard
//
//  Created by Kiro on 2025-07-16.
//

import Foundation
import Speech
import AVFoundation

// MARK: - Speech Recognition Error Types

enum SpeechRecognitionError: Error {
    case notAuthorized
    case recognizerUnavailable
    case audioEngineUnavailable
    case microphoneUnavailable
    case recognitionFailed(Error)
    case audioSessionError(Error)
}

// MARK: - Speech Recognizer Protocol

protocol SpeechRecognizer: AnyObject {
    var delegate: SpeechRecognizerDelegate? { get set }
    var isListening: Bool { get }
    var hasPermission: Bool { get }
    
    func startListening() async throws
    func stopListening()
    func requestPermissions() async -> Bool
}

// MARK: - Speech Recognizer Delegate Protocol

protocol SpeechRecognizerDelegate: AnyObject {
    func speechRecognizer(_ recognizer: any SpeechRecognizer, didDetectWord word: String)
    func speechRecognizer(_ recognizer: any SpeechRecognizer, didEncounterError error: SpeechRecognitionError)
}

// MARK: - Speech Recognizer Service

class DefaultSpeechRecognizer: NSObject, SpeechRecognizer, ObservableObject {
    weak var delegate: SpeechRecognizerDelegate?
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    @Published var isListening = false
    @Published var hasPermission = false
    
    override init() {
        super.init()
        speechRecognizer?.delegate = self
        checkPermissions()
    }
    
    // MARK: - Permission Handling
    
    func requestPermissions() async -> Bool {
        // Request speech recognition permission
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        
        guard speechStatus == .authorized else {
            await MainActor.run {
                hasPermission = false
            }
            delegate?.speechRecognizer(self, didEncounterError: .notAuthorized)
            return false
        }
        
        // Request microphone permission using iOS 17+ API
        let microphoneStatus: Bool
        if #available(iOS 17.0, *) {
            microphoneStatus = await withCheckedContinuation { continuation in
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        } else {
            microphoneStatus = await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        }
        
        guard microphoneStatus else {
            await MainActor.run {
                hasPermission = false
            }
            delegate?.speechRecognizer(self, didEncounterError: .microphoneUnavailable)
            return false
        }
        
        await MainActor.run {
            hasPermission = true
        }
        return true
    }
    
    private func checkPermissions() {
        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        let microphoneStatus: Bool
        
        if #available(iOS 17.0, *) {
            microphoneStatus = AVAudioApplication.shared.recordPermission == .granted
        } else {
            microphoneStatus = AVAudioSession.sharedInstance().recordPermission == .granted
        }
        
        hasPermission = speechStatus == .authorized && microphoneStatus
    }
    
    // MARK: - Speech Recognition Control
    
    func startListening() async throws {
        // Check if already listening
        guard !isListening else { return }
        
        // Ensure we have permissions
        if !hasPermission {
            let permissionGranted = await requestPermissions()
            guard permissionGranted else {
                throw SpeechRecognitionError.notAuthorized
            }
        }
        
        // Check if speech recognizer is available
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            throw SpeechRecognitionError.recognizerUnavailable
        }
        
        // Stop any existing session first
        stopListening()
        
        // Configure audio session
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            throw SpeechRecognitionError.audioSessionError(error)
        }
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw SpeechRecognitionError.recognizerUnavailable
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        // Create recognition task
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let error = error {
                self.delegate?.speechRecognizer(self, didEncounterError: .recognitionFailed(error))
                self.stopListening()
                return
            }
            
            if let result = result {
                let transcription = result.bestTranscription.formattedString
                
                // Process the transcription to detect individual words
                self.processTranscription(transcription, isFinal: result.isFinal)
            }
        }
        
        // Configure audio input safely
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        // Remove any existing tap first (this is safe to call even if no tap exists)
        inputNode.removeTap(onBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        // Start audio engine
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            // Clean up on failure
            inputNode.removeTap(onBus: 0)
            recognitionRequest.endAudio()
            self.recognitionRequest = nil
            recognitionTask?.cancel()
            self.recognitionTask = nil
            throw SpeechRecognitionError.audioEngineUnavailable
        }
        
        await MainActor.run {
            isListening = true
        }
    }
    
    func stopListening() {
        // Update isListening first
        DispatchQueue.main.async { [weak self] in
            self?.isListening = false
        }
        
        // Stop audio engine safely
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        
        // Remove tap safely with error handling
        do {
            audioEngine.inputNode.removeTap(onBus: 0)
        } catch {
            print("Warning: Error removing audio tap: \(error)")
        }
        
        // Cancel recognition request and task
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Clear word detection state
        lastProcessedWords.removeAll()
        wordDetectionTimer?.invalidate()
        wordDetectionTimer = nil
        
        // Reset audio session with proper error handling (do this last)
        cleanupAudioSession()
    }
    
    private func cleanupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            // Log error but don't throw since we're cleaning up
            print("Warning: Error deactivating audio session during cleanup: \(error)")
        }
    }
    
    // MARK: - Word Detection
    
    private var lastProcessedWords: Set<String> = []
    private var wordDetectionTimer: Timer?
    
    private func processTranscription(_ transcription: String, isFinal: Bool) {
        // Extract individual words from the transcription
        let words = transcription.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .compactMap { word in
                // Clean the word of punctuation and ensure it's not empty
                let cleanedWord = word.trimmingCharacters(in: .punctuationCharacters)
                return cleanedWord.isEmpty ? nil : cleanedWord
            }
        
        // Find new words that haven't been processed yet
        let newWords = Set(words).subtracting(lastProcessedWords)
        
        // Process each new word
        for word in newWords {
            // Only process words that are at least 2 characters long
            if word.count >= 2 {
                delegate?.speechRecognizer(self, didDetectWord: word)
            }
        }
        
        // Update the set of processed words
        lastProcessedWords.formUnion(newWords)
        
        // If this is a final result, reset the processed words after a delay
        // to allow for new word detection in the continuous session
        if isFinal {
            wordDetectionTimer?.invalidate()
            wordDetectionTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
                self?.lastProcessedWords.removeAll()
            }
        }
    }
    
    deinit {
        stopListening()
        wordDetectionTimer?.invalidate()
    }
}

// MARK: - SFSpeechRecognizerDelegate

extension DefaultSpeechRecognizer: SFSpeechRecognizerDelegate {
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if !available && isListening {
            delegate?.speechRecognizer(self, didEncounterError: .recognizerUnavailable)
            stopListening()
        }
    }
}