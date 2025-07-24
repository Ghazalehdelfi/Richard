# Richard - The Talking Dictionary

Richard is a SwiftUI-based iOS application that provides a voice-activated dictionary experience. Simply speak a word, and Richard will look it up and read the definition back to you.

## Features

- **Voice Recognition**: Uses iOS Speech Recognition framework for continuous listening
- **Dictionary Lookup**: Integrates with the Free Dictionary API for comprehensive word definitions
- **Text-to-Speech**: Reads definitions aloud using AVSpeechSynthesizer

## How It Works

1. **Start Study Session**: Tap the "Start Study" button to begin listening
2. **Speak a Word**: Say any word clearly into your device's microphone
3. **Get Definition**: Richard fetches the definition and displays it on screen
4. **Hear It Spoken**: The definition is automatically read aloud
5. **Continue Learning**: The app returns to listening mode for the next word

## Architecture

The app follows the MVVM pattern with clean separation of concerns:

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   ContentView   │────│ StudyViewModel  │────│ DictionaryAPI   │
│   (SwiftUI)     │    │ (Business Logic)│    │   (Service)     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         │              ┌─────────────────┐              │
         └──────────────│ SpeechRecognizer│──────────────┘
                        │   (Service)     │
                        └─────────────────┘
                                 │
                        ┌─────────────────┐
                        │TextToSpeechService│
                        │   (Service)     │
                        └─────────────────┘
```

## File Structure

- **RichardApp.swift** - App entry point
- **ContentView.swift** - Main UI implementation with state-based views
- **Models.swift** - Data models (WordDefinition, Meaning, Definition) and StudyState enum
- **StudyViewModel.swift** - Business logic, state management, and service coordination
- **SpeechRecognizer.swift** - Speech-to-text service using iOS Speech framework
- **DictionaryAPIService.swift** - API client for fetching word definitions
- **TextToSpeechService.swift** - Text-to-speech service using AVSpeechSynthesizer
- **Info.plist** - App configuration and permissions

## Permissions

The app requires the following permissions:
- **Microphone Access** - For speech recognition
- **Speech Recognition** - For processing spoken words

These permissions are requested automatically when you start your first study session.

## API

Richard uses the [Free Dictionary API](https://dictionaryapi.dev/) which provides:
- Word definitions
- Phonetic pronunciations
- Parts of speech
- Usage examples
- No API key required

