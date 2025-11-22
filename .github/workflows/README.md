# GitHub Actions Workflows

This repository includes automated GitHub Actions workflows for building Android APKs and creating releases.

## Workflows

### 1. Build Android APK (`android-build.yml`)

This workflow builds an unsigned Android APK that can be installed and run on Android devices.

**Triggers:**
- **Manual dispatch**: You can manually trigger this workflow from the Actions tab and select which branch to build from
- **Push to main**: Automatically builds when code is pushed to the `main` branch
- **Pull requests**: Builds APK for pull requests targeting the `main` branch
- **Tags**: Builds when tags starting with `v` are pushed (e.g., `v1.0.0`)

**Outputs:**
- APK artifact named `ficbatch-apk` containing `FicBatch-v{version}.apk`
- APK artifact named `app-release` containing `app-release.apk`
- Artifacts are retained for 30 days

**To manually trigger:**
1. Go to the "Actions" tab in GitHub
2. Select "Build Android APK" workflow
3. Click "Run workflow"
4. Select the branch you want to build from
5. Click "Run workflow" button

### 2. Create Release (`release.yml`)

This workflow automatically creates a GitHub release with the built APK when a version tag is pushed.

**Triggers:**
- Push of tags starting with `v` (e.g., `v1.0.0`, `v2.1.0`)

**Outputs:**
- Creates a new GitHub Release
- Attaches both `FicBatch-v{version}.apk` and `app-release.apk` to the release
- Includes installation instructions in the release notes

**To create a release:**

```bash
# Tag the current commit
git tag v1.0.0

# Push the tag to GitHub
git push origin v1.0.0
```

The workflow will automatically:
1. Build the Android APK
2. Create a new release named "FicBatch v1.0.0"
3. Attach the APK files to the release
4. Add installation instructions to the release description

## Installation Instructions for Users

When downloading APKs from releases:

1. Download the `FicBatch-v{version}.apk` file from the latest release
2. Enable "Install from Unknown Sources" in your Android settings:
   - Go to Settings → Security → Unknown Sources (or Install unknown apps)
   - Enable installation from your browser or file manager
3. Open the downloaded APK file
4. Follow the installation prompts
5. You may see a warning about unsigned apps - this is normal for development builds

**Note:** These are unsigned APKs built for testing and distribution purposes. Android will show a warning during installation, which is expected behavior for unsigned applications.

## Requirements

The workflows use:
- Java 17 (Temurin distribution)
- Flutter latest stable channel (auto-updated to match SDK requirements)
- Ubuntu latest runner

## Version Management

The version is automatically extracted from `pubspec.yaml` file. Make sure to update the version number in `pubspec.yaml` before creating a new release:

```yaml
version: 1.0.0+1
```

The version before the `+` sign (e.g., `1.0.0`) will be used for the release.
