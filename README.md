# AirFidelity

Keep your Bluetooth headphones sounding good on macOS.

## The problem

When you connect Bluetooth headphones, macOS uses A2DP, the high-quality stereo codec (2 channels, 44.1 or 48 kHz). Everything sounds great.

Then something activates the mic. A FaceTime call, Siri, voice dictation, even some apps that request mic access without actually using it. macOS silently switches your headphones to HFP/SCO, a mono codec designed for phone calls (1 channel, 8 or 16 kHz). Your music now sounds like it's coming through a walkie-talkie, and macOS doesn't tell you it happened.

The problem is the codec switch, not the headphones. Your AirPods Pro are capable of excellent audio. macOS just won't let them use it when it thinks you need a microphone.

## What AirFidelity does

AirFidelity sits in the menu bar and redirects mic input away from your Bluetooth headphones. When you connect a Bluetooth audio device, it waits 2.5 seconds for macOS to finish its setup, then switches the system input to your Mac's built-in microphone (or another mic you choose). Your headphones stay on A2DP. You keep stereo. Your music keeps sounding like music.

If you start an actual call, AirFidelity detects the mic activity and backs off. It won't fight a FaceTime call or Zoom meeting. Once the call ends, it waits through a 5-second cooldown to make sure the call is really over, then switches back.

## Features

- Automatic input switching when Bluetooth headphones connect
- Call detection with cooldown (backs off during calls, restores after)
- Codec quality indicator in the menu bar (headphones icon for A2DP, phone icon for calls, dimmed when no Bluetooth audio)
- Status display showing current output device, input device, and codec state
- Manual "Fix Now" button for immediate switching
- Input device picker (choose any connected mic as your preferred input)
- Auto-switch toggle
- Launch at login
- No audio is recorded. AirFidelity only monitors device state changes and mic activity flags.

## Install

1. Download the latest `.dmg` from [GitHub Releases](https://github.com/vincehopf/AirFidelity/releases/latest)
2. Drag AirFidelity to Applications
3. Open it. macOS will ask for microphone permission on first launch. AirFidelity needs this to detect input device changes, not to record anything.

The app runs in the menu bar. There's no dock icon and no main window.

## How it works

AirFidelity uses CoreAudio (via [SimplyCoreAudio](https://github.com/rnine/SimplyCoreAudio)) to monitor the system audio device list. The logic is a state machine:

1. **Bluetooth device connects.** AirFidelity sees the new device in the CoreAudio device list, waits 2.5 seconds, then sets the system default input to the built-in mic (or your chosen alternative). The 2.5-second delay exists because macOS sometimes takes a moment to finalize Bluetooth audio setup, and switching too early gets overridden.

2. **Something switches input to the Bluetooth mic.** AirFidelity watches for default input device changes. If the input flips to a Bluetooth device while Bluetooth output is connected and no call is active, it switches back. A 1-second debounce prevents reacting to its own switches.

3. **A call starts.** AirFidelity polls the Bluetooth device's `isRunningSomewhere` property to detect mic usage. When it sees activity, it marks a call as active and stops interfering. The menu bar icon changes to a phone.

4. **The call ends.** Mic activity stops, but AirFidelity waits 5 seconds before declaring the call over. This cooldown prevents false positives from brief pauses in a call. After cooldown, it switches input back to the built-in mic and restores A2DP.

Codec detection works by reading the output device's sample rate and channel count. HFP/SCO shows up as 1 channel at 8 or 16 kHz. A2DP shows up as 2 channels at 44.1 or 48 kHz.

## Building from source

Requires Xcode 15+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
git clone https://github.com/vincehopf/AirFidelity.git
cd AirFidelity
xcodegen generate
open AirFidelity.xcodeproj
```

Build and run from Xcode. The app needs the `com.apple.security.device.audio-input` entitlement for microphone access, which is included in the project.

## Requirements

macOS 14 Sonoma or later.

## License

[GPL v3](LICENSE)
