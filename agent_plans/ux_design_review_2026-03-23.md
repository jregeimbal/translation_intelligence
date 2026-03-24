OmniaLingo UX/Design Review
1. Monolithic Main File — Cognitive Overload Risk
main.dart is ~1,824 lines containing MyApp, ProviderSettingsDialog, DebouncedMessageDispatcher, and _MyHomePageState all in one file. The settings dialog alone is 450+ lines of widget build code. This makes it harder to iterate on individual UX surfaces. Extract ProviderSettingsDialog and the language bar into dedicated widget files.

2. No Onboarding or First-Run Experience
There's zero onboarding, welcome screen, or tutorial. A real-time voice translation tool requires users to understand:

Which mode to use (Group vs. 2-way)
How source/target language selection works
What the microphone button does and how to grant permissions
What "primary speaker" means
Recommendation: Add a brief first-launch walkthrough or coach-marks overlay — even a single "Get Started" sheet explaining the two modes.

3. Two-Way Chat: Inverted Guest Panel is Disorienting
In two_way_chat.dart:33-38, the guest panel is rendered with Transform.rotate(angle: math.pi) — flipping it 180 degrees. While this mimics a "face-to-face across a table" metaphor, it means:

Text is upside-down from the user holding the device
Dropdown menus, scroll interactions, and buttons are inverted
There's no visual cue explaining why it's flipped
Recommendation: Add a visual divider or "flip device" prompt when entering 2-way mode. Consider an alternative layout (split-screen with separate orientations per half) that doesn't invert UI controls.

4. Accessibility — Zero Semantic Annotations
The grep for Semantics, semanticLabel, or ExcludeSemantics returned zero results across the entire lib directory. This means:

Screen readers have no meaningful labels for the mic FAB, language dropdowns, speaker chips, or control buttons
The circular waveform CustomPaint in recording_toggle_button.dart has no semantic description
Icon-only buttons (refresh, visibility, volume) rely solely on tooltips
Recommendation: Add Semantics widgets to all interactive elements, label the custom waveform painter, and ensure the FloatingActionButton has an accessibilityLabel.

5. No Responsive/Adaptive Layout
The only MediaQuery usage is a single maxWidth: MediaQuery.of(context).size.width * 0.88 constraint on chat_message.dart:231. There are no breakpoints, LayoutBuilder usage, or adaptive layouts. On tablets or desktop:

The settings dialog (height: 320 fixed) will feel cramped
Chat bubbles at 88% width will be excessively wide on large screens
The bottom navigation bar pattern is mobile-only; desktop users expect a sidebar or top nav
Recommendation: Introduce responsive breakpoints — at minimum, constrain the max content width on wide screens (e.g., 600-800px center column) and consider a NavigationRail for tablet/desktop.

6. Settings Dialog is Dense and Technical
The ProviderSettingsDialog exposes raw technical concepts: "Deepgram Model", "Deepgram Language", "Google Locale", "STT Provider", "Translation Provider", "TTS Provider". For non-technical users:

The distinction between "STT provider" and "Translation provider" is opaque
Changing the Deepgram model triggers a dependent language reset with no explanation
The 3-tab dialog (Providers / Audio / Display) with a fixed 320px height causes scrolling within a dialog
Recommendation:

Rename tabs: "Voice Recognition", "Audio Devices", "Appearance"
Hide provider-level choices behind an "Advanced" toggle
Surface only what users care about front-and-center: source language, target language, and listening device
Use a full-screen settings page instead of a cramped dialog
7. Error Handling UX is Minimal
Initialization errors show a raw error string: _initializationError = '$error' — no user-friendly messaging
The error state at main.dart:1650-1668 is a plain centered text + retry button with no visual hierarchy
Speech errors in the footer are truncated with TextOverflow.ellipsis — users lose information
Mic permission denied errors are localized but there's no guided recovery (e.g., "Open Settings" link)
Recommendation: Add error categorization with user-friendly messages and actionable recovery steps.

8. Group Mode Footer is Cluttered
The SpeechFooter at footer.dart packs into a 64px bar:

Primary Speaker dropdown (160px wide)
Speech error text
Clear chat button
Hide/show original toggle
Audio playback toggle
The mic FAB
These controls compete for space. On narrow screens, the speaker dropdown and error text will collide. The "Hide original" toggle icon switches between visibility_outlined and visibility_off_outlined with no text label — its purpose is unclear at a glance.

Recommendation: Move secondary controls (clear, hide original, audio playback) into an overflow menu or a collapsible toolbar. Keep the footer focused: mic button + listening status.

9. Language Selection Bar Doesn't Indicate Active State
The _buildGroupLanguageBar shows Source and Target dropdowns with a swap button. However:

When "Multi (Auto)" is selected, the swap button is disabled with a tooltip but no visual indicator of why
The currently-detected language during a listening session isn't surfaced in the UI — users don't know what language the system is actually hearing
Recommendation: Show the resolved/detected language as a subtitle or chip below the source dropdown during active listening.

10. Theme System is Over-Duplicated
HyperListenTheme and HyperLinguistTheme are nearly identical — same text theme, same structure, same token shapes — differing only in seed color (0xFF00E5FF vs 0xFF4F46E5). The resolver in app_theme_resolver.dart manually bridges between them. This means any UX change (e.g., adjusting bubble body font size) must be duplicated.

Recommendation: Consolidate into a single parametric theme factory that accepts a seed color and optional overrides.

11. No Empty-State Guidance in 2-Way Mode
When both panels have no messages in _SpeakerPanel, the placeholder just says "No messages yet" or "Listening..." — there's no guidance about:

Which panel belongs to which person
How to switch the active speaker
That only one speaker can talk at a time
Recommendation: Add contextual empty-state guidance: "Press the mic button below to speak as [Primary/Guest]."

12. No Haptic or Audio Feedback
The mic button toggles between listening/stopped without any haptic feedback or audio cue. For a hands-free translation scenario, auditory or vibration cues are essential — the user may not be looking at the screen.

Recommendation: Add a brief haptic pulse (HapticFeedback.mediumImpact()) and optional audio chime on listening start/stop.

Summary Priority Matrix
Priority	Issue	Impact
High	No accessibility / semantic labels	Excludes screen-reader users entirely
High	No onboarding	Users don't understand the two modes or controls
High	Settings expose raw technical internals	Confuses non-technical users
Medium	No responsive layout	Poor experience on tablet/desktop
Medium	Inverted guest panel UX	Disorienting without context
Medium	Cluttered footer controls	UI overwhelm on small screens
Medium	Minimal error recovery UX	Users stuck with no guidance
Low	Theme duplication	Developer friction, not user-facing
Low	No haptic/audio feedback	Polish item for production
Low	Monolithic main.dart	Code maintainability