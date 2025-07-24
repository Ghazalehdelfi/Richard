//
//  TextToSpeechService.swift
//  Richard
//
//  Created by Kiro on 2025-07-23.
//

import Foundation
import AVFoundation

// MARK: - Text-to-Speech Service

class TextToSpeechService: NSObject, ObservableObject {
    private nonisolated(unsafe) let speechSynthesizer = AVSpeechSynthesizer()
    private var speechRate: Float = AVSpeechUtteranceDefaultSpeechRate
    
    override init() {
        super.init()
        speechSynthesizer.delegate = self
    }
    
    /// Speaks the given text using the configured speech rate
    func speak(_ text: String) {
        guard !text.isEmpty else { return }
        
        // Configure audio session for playback and recording
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .spokenAudio, options: [.duckOthers, .defaultToSpeaker])
            try audioSession.setActive(true)
        } catch {
            print("Warning: Failed to configure audio session for text-to-speech: \(error)")
        }
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = speechRate
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        
        speechSynthesizer.speak(utterance)
    }
    
    /// Stops any current speech synthesis
    func stopSpeaking() {
        speechSynthesizer.stopSpeaking(at: .immediate)
    }
    
    /// Returns whether the speech synthesizer is currently speaking
    var isSpeaking: Bool {
        speechSynthesizer.isSpeaking
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension TextToSpeechService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
}