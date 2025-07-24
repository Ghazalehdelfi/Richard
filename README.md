# Richard - Your Talking Dictionary

Richard is a SwiftUI-based iOS application that provides a voice-activated dictionary experience. Simply speak a word, and Richard will look it up and read the definition back to you.

## Features

- **Voice Recognition**: Uses iOS Speech Recognition framework for continuous listening
- **Dictionary Lookup**: Integrates with the Free Dictionary API for comprehensive word definitions
- **Text-to-Speech**: Reads definitions aloud using AVSpeechSynthesizer
- **Clean UI**: Simple, accessible interface with visual state indicators
- **Error Handling**: Graceful handling of network issues, permission problems, and audio interruptions

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

## Requirements

- iOS 15.0+
- Xcode 14.0+
- Swift 5.7+
- Device with microphone and speakers/headphones

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

## States

The app has five main states:

1. **Idle** - Ready to start studying
2. **Listening** - Actively listening for spoken words
3. **Processing** - Looking up word definition
4. **Displaying** - Showing and speaking the definition
5. **Error** - Handling various error conditions

## Error Handling

Richard gracefully handles various error scenarios:
- Network connectivity issues
- Words not found in dictionary
- Microphone permission denied
- Speech recognition failures
- Audio session interruptions (calls, etc.)

## Accessibility

- Full VoiceOver support
- Dynamic Type support for text scaling
- Semantic labels for all UI elements
- Reduced motion support

## Development

To run the project:

1. Clone the repository
2. Open `Richard.xcodeproj` in Xcode
3. Select a target device or simulator
4. Build and run (⌘+R)

For testing on device, ensure you have:
- Valid Apple Developer account
- Device registered for development
- Proper code signing configured

## Contributing

This project follows standard iOS development practices:
- MVVM architecture pattern
- SwiftUI for UI implementation
- Async/await for asynchronous operations
- Combine for reactive programming
- Protocol-oriented design for services

## License

[Add your license information here]

## Support

For issues or questions, please [create an issue](link-to-issues) in the repository.
