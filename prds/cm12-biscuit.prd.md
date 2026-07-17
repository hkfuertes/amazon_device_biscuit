# PRD: CM12 para Amazon Biscuit

## Problem Statement

El usuario quiere preparar un workspace limpio y reproducible para compilar CM12 para Amazon Biscuit, partiendo del source release oficial de Amazon para Echo Dot 5.5.5.4. El workspace actual no debe arrastrar ruido del árbol viejo existente. La meta no es crear una ROM estética o completa de golpe, sino llegar a un MVP funcional: CM12 que arranque, tenga ADB, WiFi, reproducción de audio y grabación por micrófono.

El usuario necesita que el proceso sea seguro para el dispositivo, reproducible con Docker, y que preserve los ficheros originales de Amazon sin parchearlos directamente. Quiere aprobar el plan antes de implementar cambios.

## Solution

Crear un workspace limpio orientado a build reproducible con Docker. El source tarball de Amazon será el punto de partida y source-of-truth para kernel, configuraciones de dispositivo, init, audio, WiFi, firmware y blobs cuando existan. La extracción original se mantendrá intacta e ignorada por git.

El proyecto tendrá scripts mínimos: un preflight que descargue, verifique, extraiga y prepare enlaces/copias desde los sources originales; y un wrapper de build Docker con nombre fijo de contenedor para poder seguir logs con el mismo comando. El device tree se reconstruirá desde cero, usando solo lo necesario para el MVP.

## User Stories

1. As a ROM developer, I want a clean Biscuit CM12 workspace, so that old experimental noise does not contaminate the new build.
2. As a ROM developer, I want the Amazon source tarball downloaded reproducibly, so that the original vendor source is always available.
3. As a ROM developer, I want the downloaded tarball checksummed, so that I can detect corrupted or changed source inputs.
4. As a ROM developer, I want the Amazon source extracted into an immutable upstream area, so that original files remain trustworthy.
5. As a ROM developer, I want original Amazon files used as-is when possible, so that local divergence stays minimal.
6. As a ROM developer, I want symlinks or generated copies instead of hand-written duplicates, so that updates are easier to reason about.
7. As a ROM developer, I want patches separated from upstream files, so that every intentional change is reviewable.
8. As a ROM developer, I want a Docker-based build environment, so that host Python, Java, and distro versions do not break CM12.
9. As a ROM developer, I want the Dockerfile copied from the known CM12 Biscuit environment, so that the build starts from proven dependencies.
10. As a ROM developer, I want the build container to have a stable name, so that I can follow logs with a fixed docker logs command.
11. As a ROM developer, I want old containers cleaned before new builds, so that stale build state does not confuse diagnosis.
12. As a ROM developer, I want the build output directory to be absolute, so that Android recovery and image generation do not break on relative paths.
13. As a ROM developer, I want a minimal CM12 product target for Biscuit, so that lunch can select the device cleanly.
14. As a ROM developer, I want a minimal BoardConfig for Biscuit, so that boot image generation has the required device facts.
15. As a ROM developer, I want boot and ADB working first, so that later WiFi and audio debugging can happen on-device.
16. As a ROM developer, I want WiFi firmware and configs sourced from Amazon or stock, so that the device can associate with a network.
17. As a ROM developer, I want audio playback working, so that speaker routing and HAL integration are validated.
18. As a ROM developer, I want microphone recording working, so that input routing and capture configs are validated.
19. As a ROM developer, I want tinyalsa or equivalent command-line checks, so that audio can be tested without depending on UI apps.
20. As a ROM developer, I want stock blobs discoverable from public sources or my own dump, so that missing proprietary components can be filled.
21. As a ROM developer, I want no flashing automation in the initial workspace, so that build preparation stays separate from device risk.
22. As a ROM developer, I want flashing notes to respect TWRP and hacked fastboot only, so that unsafe stock fastboot paths are avoided.
23. As a ROM developer, I want the project to ignore tarballs, extracted sources, blobs, and build outputs, so that git only tracks reproducible logic.
24. As a ROM developer, I want the first implementation phase to avoid compiling, so that I can review the workspace before heavy operations.
25. As a ROM developer, I want the plan documented in a PRD, so that future agents can continue without rediscovering context.
26. As a ROM developer, I want the build scripts parameterized enough to choose the final compile location, so that I can move large builds where storage allows.
27. As a ROM developer, I want device bring-up split into boot, WiFi, playback, and recording phases, so that failures are isolated.
28. As a ROM developer, I want every copied vendor artifact traceable to its source, so that legal and technical provenance can be reviewed later.

## Implementation Decisions

- The MVP is CM12 for Amazon Biscuit with boot, ADB, WiFi, audio playback, and microphone recording.
- The Amazon Echo Dot 5.5.5.4 source release is the source-of-truth for vendor/kernel/device material.
- The upstream Amazon extraction must remain unmodified.
- The implementation should prefer referencing original files over copying them.
- If direct references are not accepted by the Android build, generated symlinks are preferred.
- If symlinks fail, generated copies are acceptable.
- If source changes are required, they must live as explicit patches applied to generated working copies, not to the preserved upstream extraction.
- The old dirty CM12/device tree may be consulted only when the user explicitly points to needed material; the new tree starts clean.
- The Docker environment should reuse the known CM12 Ubuntu 14 Dockerfile from the existing CM12 Biscuit project.
- The Docker build container should have a stable name so logs can be followed consistently.
- The build wrapper should remove any previous container with that stable name before starting a new build.
- The build wrapper should avoid automatic container removal after completion, preserving logs for inspection.
- The Android output directory must be absolute.
- The preflight script is responsible for download, checksum, extraction, and generated preparation steps.
- The preflight script must not compile.
- The build script is responsible for invoking Docker and the CM12 build commands.
- The build script should not flash the device.
- Proprietary blobs may be sourced from public locations if found; otherwise the user may provide a stock dump.
- Git should track reproducible scripts, makefiles, metadata, and patches; it should not track downloaded archives, extracted upstream source, blobs, or build outputs.
- Device safety rules from the agent instructions apply: no Android/ADB dd writes, no stock fastboot for ROM flashing, and no touching sensitive partitions unless explicitly requested.

## Testing Decisions

- Tests should validate external behavior and reproducibility, not implementation details.
- The preflight module should be testable by running it in a clean workspace and verifying expected artifacts exist while upstream source remains unmodified.
- The Docker/build wrapper should be testable by checking image presence, stable container naming, absolute output directory setup, and non-destructive behavior before a full build.
- The device tree should be validated first by whether the CM12 environment can select the Biscuit product target.
- Boot validation requires the produced image to boot far enough for ADB.
- WiFi validation requires scanning and associating with a network.
- Audio playback validation requires playing known audio through the speaker path.
- Microphone validation requires recording audio and playing it back or inspecting the captured sample.
- No large test framework is required initially; shell checks and build/bring-up commands are enough.

## Out of Scope

- Flashing automation in the initial implementation.
- Editing the preserved Amazon upstream extraction.
- Building a polished end-user ROM before the MVP hardware paths work.
- OTA packaging polish beyond what CM12 build requires.
- Bluetooth, voice assistant stack, LED behavior, factory reset integration, and advanced power management unless they block MVP.
- Legal cleanup of proprietary blob redistribution before technical feasibility is proven.
- Importing the old dirty device tree wholesale.

## Further Notes

- The user explicitly wants implementation paused until approval.
- The first approved implementation phase should only create the workspace structure, documentation, Dockerfile copy, preflight script, build wrapper, and ignore rules.
- The build container name should remain stable for easy log following.
- The final compile location can be chosen later by the user.
