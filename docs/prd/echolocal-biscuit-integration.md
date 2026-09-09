# EchoLocal on Biscuit Minimal Base

## Problem Statement

The framework-free Biscuit minimal base boots reliably, provides root ADB, Wi-Fi/DHCP, MTK radio support, logging, and the native audio foundations needed by EchoLocal. It does not yet provide a reproducible EchoLocal product.

The upstream `echoctl install` workflow targets rooted Fire OS devices. It flashes a Fire OS boot image, hides Amazon packages, takes over Amazon services, changes animation wrappers, provisions device-specific secrets, and configures Wi-Fi. Running that installer unchanged against the minimal CM12 image would be unsafe and would duplicate or conflict with image-owned behavior.

Users need a separate, framework-free Biscuit image that runs the official EchoLocal daemon from boot, preserves the useful installer contract, does not embed credentials, and remains reproducible from this repository.

## Solution

Provide a separate EchoLocal Biscuit product based on the existing minimal base. It will preinstall a verified static AArch64 `echod` artifact, run it under the compatible `ledcontroller` init service identity, create and preserve EchoLocal state, seed wake-word models without overwriting user data, and keep Wi-Fi provisioning as an explicit host-side EchoLocal operation.

The initial MVP will use the verified official EchoLocal 0.0.6 release artifact. A later equivalent source-build path will be added only after the release artifact has been validated on Biscuit.

## User Stories

1. As a Biscuit owner, I want a dedicated EchoLocal image, so that I can run EchoLocal without the Android framework or Amazon applications.
2. As a Biscuit owner, I want the existing generic minimal image to remain available, so that EchoLocal experimentation does not replace the stable base product.
3. As a builder, I want the EchoLocal daemon artifact pinned by release and digest, so that every build uses an identifiable, verified binary.
4. As a builder, I want artifact validation to reject the wrong architecture or a dynamically linked binary, so that an invalid daemon never reaches an OTA.
5. As a Biscuit owner, I want EchoLocal to start automatically after boot, so that it is usable without manually launching a process through ADB.
6. As EchoLocal, I want the expected `ledcontroller` service identity, so that supported service-control behavior remains compatible.
7. As a Biscuit owner, I want no Amazon stock LED controller installed, so that there is one unambiguous owner of the LED ring.
8. As a Biscuit owner, I want the generic boot LED hook absent from the EchoLocal product, so that it cannot compete with EchoLocal for LED-ring control.
9. As EchoLocal, I want writable persistent state, so that settings, models, provisioning data, recordings, and update state can survive reboots and OTAs.
10. As a Biscuit owner, I want wake-word starter models present on first boot, so that basic wake detection works before Home Assistant supplies replacements.
11. As a Biscuit owner, I want existing downloaded or user-selected models preserved, so that an OTA never overwrites personal configuration.
12. As a user, I want my device identity derived from its factory MAC address, so that new devices receive a stable unique Echo Dot-style name.
13. As a Home Assistant user, I want the default node slug to follow the `echo-dot-XXXXXX` convention, so that multiple Biscuit devices remain distinguishable.
14. As a privacy-conscious user, I want the MVP to run without a preinstalled ESPHome PSK, so that no shared secret is baked into the ROM.
15. As a provisioner, I want to add a PSK later if needed, so that stronger pairing can be enabled per device without rebuilding the image.
16. As a user, I want Wi-Fi credentials to remain outside the ROM, so that image artifacts and build logs never contain my network password.
17. As a provisioner, I want to use `echoctl wifi` from the host, so that EchoLocal performs persistent Wi-Fi configuration, association, and DHCP verification through ADB.
18. As a user, I want saved Wi-Fi configuration to survive ordinary OTA updates, so that testing a new image does not require re-entering network credentials.
19. As an operator, I want ordinary daemon logs and state properties available after boot, so that failures can be diagnosed without an Android framework.
20. As a builder, I want the product to remain free of APKs, framework JARs, zygote, and system-server dependencies, so that it retains the minimal-base goal.
21. As a builder, I want the existing MTK radio, Wi-Fi/DHCP, audio, Bluetooth, ADB, and logging foundations preserved, so that EchoLocal is integrated on a known bootable base.
22. As a builder, I want the upstream Fire OS installer behavior classified rather than copied wholesale, so that Fire OS-specific boot flashing and package manipulation are never applied to Biscuit CM12.
23. As a Biscuit owner, I want OTA preflight to prove that the package does not wipe user data, so that saved Wi-Fi and EchoLocal state remain intact.
24. As a Biscuit owner, I want explicit approval before any device flash, so that image deployment remains deliberate and reversible through the established recovery workflow.
25. As a maintainer, I want source compilation deferred until the release artifact works, so that toolchain failures cannot be confused with image-integration failures.
26. As a maintainer, I want a later pinned-source build route using Go 1.26, so that the prebuilt artifact can eventually be replaced by a reproducibly built daemon.
27. As a maintainer, I want milestone commits, so that artifact acquisition, product integration, and successful build verification remain independently reviewable.
28. As a user, I want no image-owned firewall customization in the MVP, so that the minimal product does not add unnecessary networking policy.
29. As a Home Assistant user, I want the ESPHome API to become reachable once networking is available, so that discovery and pairing can be validated after boot.
30. As a Biscuit owner, I want microphone, speaker, LED, Wi-Fi, and Bluetooth behavior tested independently, so that a daemon start is not mistaken for end-to-end voice functionality.

## Implementation Decisions

- A new separately lunchable EchoLocal product will inherit the framework-free Biscuit minimal base. The existing full CM12 product and the generic minimal product will remain unchanged in behavior.
- The initial daemon source is the official EchoLocal 0.0.6 release artifact. Its release metadata digest is pinned and verified before staging; the artifact must be a static Linux AArch64 executable.
- Acquisition and validation happen before the Android Docker build. The Android build consumes an already verified staged artifact and does not perform an unpinned network download.
- The product will preserve the upstream executable layout and the `ledcontroller` init service name. It will provide the compatible service alias without importing Amazon's proprietary stock controller.
- Init will create the EchoLocal persistent state hierarchy before starting the daemon. State is data-owned and must survive normal OTAs.
- Starter wake-word model pairs are seeded only when absent. Existing models, configuration, recordings, names, and future credentials are never overwritten by the seed step.
- The default display name will be generated by EchoLocal from the final six hexadecimal characters of the factory MAC address. The Android product model will be Echo Dot. No generated name file is necessary for the MVP.
- The MVP intentionally leaves the ESPHome PSK absent. It neither generates nor packages a shared PSK. Per-device pairing policy can be added later through supported provisioning.
- Wi-Fi provisioning remains a host-side `echoctl wifi` operation. The image must preserve the already working saved-supplicant and DHCP flow, but must not embed an SSID or password.
- The EchoLocal product excludes the generic LED bootstrap hook so that the daemon is the only product-owned LED-ring controller.
- The MVP adds no custom firewall hook or port rule.
- The upstream Fire OS installer is not executed against the minimal image. Its Fire OS boot flashing, Amazon package hiding, SmartHome Wi-Fi gating, stock animation takeover, and stock-service backup behavior are intentionally omitted.
- EchoLocal self-update and rollback behavior must be audited against the minimal init lifecycle before it is enabled as a supported workflow. Initial integration must not silently rely on Fire OS animation scripts.
- The source-build follow-up will pin an exact revision, use a Go 1.26-capable isolated build environment, produce a CGO-free Linux AArch64 daemon, and require equivalent artifact validation before it can replace the release binary.
- Work is committed at meaningful milestones: reproducible artifact acquisition, product/runtime integration, and clean build plus OTA preflight.

## Testing Decisions

- Tests will assert externally visible product contracts rather than Makefile or init implementation details.
- Artifact validation tests will prove release digest, executable mode, AArch64 architecture, static linkage, and absence of unexpected dynamic dependencies.
- Product tests will prove that the EchoLocal product includes the daemon and compatible service contract while excluding Android framework payloads, Amazon LED-controller payloads, generic LED bootstrap behavior, Wi-Fi credentials, and a preinstalled PSK.
- Seed-state tests will prove that a missing state directory receives required starter models and that existing models and provisioning files are preserved unchanged.
- Init tests will prove that persistent state is ready before the daemon is started and that the daemon is supervised under the compatible service name.
- OTA preflight tests will prove that only expected system and boot targets are updated and that no user-data wipe operation is present.
- Hardware validation will test boot, root ADB, daemon residency, Wi-Fi association and DHCP, API reachability, LED ownership, factory-MAC naming, microphone capture, speaker playback, wake-word behavior, and Bluetooth regression behavior.
- Wi-Fi provisioning tests will use the host `echoctl wifi` workflow or its interactive equivalent. Passwords must not be printed in test output, repository files, or summaries.
- Device testing occurs only after an explicit preflight review and explicit authorization to flash.

## Out of Scope

- Running the upstream `echoctl install` command unchanged on the minimal image.
- Fire OS boot-image flashing, recovery-side direct partition writes, or Amazon package manipulation.
- Importing the stock Amazon `ledcontroller` binary.
- Adding an Android framework, zygote, system server, APKs, or framework services.
- Baking Wi-Fi SSIDs, Wi-Fi passwords, or ESPHome PSKs into the image.
- Custom firewall hooks or port rules for the MVP.
- Solving the existing physical audio-route or speaker-output issue as part of the initial integration.
- Replacing the kernel, changing vendor blobs, or adding C/kernel changes for EchoLocal integration.
- Biscuit button, volume, microphone-mute, or `biscuitd` work.
- Supporting EchoLocal self-update until its rollback behavior is demonstrated safe on the minimal init implementation.

## Further Notes

The official release artifact has been verified as a static AArch64 executable. The release checksum manifest does not list this particular daemon asset, so validation uses the official GitHub release-asset digest.

The minimal base already has known working Wi-Fi association and DHCP after boot. It also retains native MTK audio and Bluetooth foundations, but audible speaker output remains unproven: direct PCM playback reached a running ALSA stream without audible output. EchoLocal process health and full voice interaction must therefore be reported separately.

The PRD is intentionally local to this repository and ignored by Git at the user's request.
