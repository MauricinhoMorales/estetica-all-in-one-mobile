# FlutterApp

## Flutter Environment Setup (Ubuntu / Linux)

### Requirements

- Ubuntu 24.04 LTS (x86_64)
- Target platform: Android

### Step 1 — Install Flutter

```bash
sudo snap install flutter --classic
```

### Step 2 — Install JDK 17

```bash
sudo apt update && sudo apt install -y openjdk-17-jdk
```

### Step 3 — Install Android command-line tools

```bash
sudo apt install -y wget unzip
mkdir -p ~/Android/Sdk/cmdline-tools
cd ~/Android/Sdk/cmdline-tools
wget https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip
unzip commandlinetools-linux-11076708_latest.zip
mv cmdline-tools latest
```

### Step 4 — Set environment variables

Add the following to your `~/.bashrc` or `~/.zshrc`:

```bash
export ANDROID_HOME=$HOME/Android/Sdk
export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin
export PATH=$PATH:$ANDROID_HOME/platform-tools
export PATH=$PATH:$HOME/snap/flutter/common/flutter/bin
```

Then reload your shell:

```bash
source ~/.bashrc
```

### Step 5 — Install Android SDK components

```bash
sdkmanager --install "platform-tools" "platforms;android-36" "build-tools;36.0.0"
```

### Step 6 — Accept Android licenses

```bash
flutter doctor --android-licenses
```

### Step 7 — Verify the installation

```bash
flutter doctor
```

All items should show a checkmark. Fix any issues reported before proceeding.

> **Non-blocking warnings you can ignore:**
> - `Unable to access driver information using 'eglinfo'` — only needed for Linux desktop GPU info, not Android development.
> - `Device emulator-5554 is offline` — the emulator isn't running; it will appear available when started.

### Step 8 — Install dependencies and run the app

```bash
flutter pub get
flutter run
```

Select the device where the app should be launched when prompted.

---

## Usage

Open a Device from AndroidStudio or use Edge as a Device

Execute:
```
flutter run 
```
and select the device where the display is going to be executed
 
## Distribution

### Components

Contains all the componenets for the application

* Navigator: It handles the BottomTabbar navigation


### Pages

Contains all the views of the application

* HomePage: This is a default page


### Theme

Contains the themes for the application

* Themes: Contains the colors and font sizes for the light and dark themes


### Utilities

Contains some functions that can be reused
