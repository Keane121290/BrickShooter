# Codemagic (etter GitHub)

Repo: [Keane121290/BrickShooter](https://github.com/Keane121290/BrickShooter)

`codemagic.yaml` ligger i git-roten. Flutter-appen ligger i `brick_shooter/` (`pubspec.yaml` der). Workflowene kjører derfra.

Testannonsene er fortsatt på. Ikke slå dem av i denne konfigurasjonen.

## 1. Koble GitHub i Codemagic

1. [codemagic.io](https://codemagic.io) → **Add application** → GitHub → velg **BrickShooter**.
2. Velg **Flutter app** og branch `main`.
3. Codemagic skal finne `codemagic.yaml` automatisk.

## 2. iOS (TestFlight)

Appen må finnes i App Store Connect med bundle-id `com.keane1212.brickTapper` før TestFlight-innsendingen kan lykkes. Selve IPA-en bygges uansett.

### App Store Connect API

Samme integrasjon som Knitting Helper kan gjenbrukes.

1. [App Store Connect](https://appstoreconnect.apple.com) → **Users and Access** → **Integrations** → **App Store Connect API**.
2. Nøkkelen trenger rollen **App Manager**.
3. Last ned `.p8` én gang. Noter **Issuer ID** og **Key ID**.

### Codemagic

1. **Team integrations** → **Developer Portal** → legg inn API-nøkkelen om den ikke allerede ligger der.
2. **Code signing identities** → **iOS certificates**: **Generate/Fetch** med API-nøkkelen.
3. **iOS provisioning profiles**: **Fetch** for bundle ID `com.keane1212.brickTapper` (App Store).
4. **Team integrations** → **App Store Connect**: bruk integrasjonen **`Codemagic`**.
5. I `codemagic.yaml`, under `ios-release` → `integrations` → `app_store_connect`, skal navnet matche steg 4 (`Codemagic`).

Workflow **ios-release** kjører tester, bygger IPA og sender til **TestFlight** (`submit_to_app_store: false`).

## 3. Android

Android bygges lokalt i Android Studio med opplastingsnøkkelen på denne maskinen. Codemagic bygger den ikke.

## 4. Første build

1. Push `codemagic.yaml` til `main`, eller start bygget manuelt i Codemagic etter at filen er på GitHub.
2. Last ned `.ipa` / `.aab` fra **Artifacts**.

## App-identifikatorer

| Plattform | ID |
|-----------|-----|
| iOS bundle | `com.keane1212.brickTapper` |
| Android applicationId | `com.keane1212.brickTapper` |
| Versjon | `1.0.0+1` (fra `brick_shooter/pubspec.yaml`) |
