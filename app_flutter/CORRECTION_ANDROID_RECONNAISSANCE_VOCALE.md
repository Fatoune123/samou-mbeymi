# Correction Android — reconnaissance vocale SAMOU MBEYMI

## Modifications incluses
- L'assistant Flutter ne bloque plus immédiatement le français lorsque la liste des locales Android est vide : il tente `fr_FR`.
- Le message d'erreur est plus précis pour diagnostiquer le service vocal Android.

## Étape Android indispensable
Cette archive ne contient pas le dossier `android/` (plateforme native Flutter). Après extraction, dans `app_flutter`, générez la plateforme Android si elle n'existe pas :

```bash
flutter create --platforms=android .
```

Puis ouvrez `android/app/src/main/AndroidManifest.xml` et ajoutez les éléments suivants :
- directement sous la balise `<manifest>` :

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.INTERNET" />

<queries>
    <intent>
        <action android:name="android.speech.RecognitionService" />
    </intent>
</queries>
```

Ne remplacez pas le reste du manifeste généré. Ajoutez uniquement ces déclarations si elles n'existent pas déjà.

## Sur le téléphone Android
1. Activez Internet.
2. Dans Paramètres > Applications, vérifiez que SAMOU MBEYMI a l'autorisation Microphone.
3. Vérifiez que l'application Google et le service « Reconnaissance vocale et synthèse vocale Google » sont installés/activés.
4. Dans les paramètres du service vocal, téléchargez le français hors connexion si cette option est proposée.

## Recompiler
```bash
flutter clean
flutter pub get
flutter run
```

La disponibilité du français dépend du service de reconnaissance installé sur le téléphone. Les langues nationales ne sont pas automatiquement prises en charge par Android : elles nécessitent un moteur qui les reconnaît réellement.

## Protection des données
Cette correction ne touche pas au backend Django, à SQLite, aux comptes, aux mots de passe, aux migrations ni aux données métier.
