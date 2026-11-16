# Configuration de l'assistant agricole

L'assistant agricole est ajouté à l'application Flutter sans remplacer les écrans existants. Il utilise les services de reconnaissance et de synthèse vocale disponibles sur l'appareil.

## 1. Installer les dépendances

Depuis le dossier `app_flutter` :

```bash
flutter pub get
flutter analyze
```

## 2. Autorisation du microphone sur Android

Ce dépôt ne contient pas encore les fichiers de plateforme Flutter Android : le script `PREPARER_FLUTTER_WINDOWS.bat` les génère avec `flutter create`.

Après la génération, ouvrez `android/app/src/main/AndroidManifest.xml` et ajoutez les lignes suivantes directement sous la balise `<manifest ...>`, avant `<application>` :

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.INTERNET" />
<queries>
    <intent>
        <action android:name="android.speech.RecognitionService" />
    </intent>
</queries>
```

Au premier usage, autorisez l'accès au microphone si Android le demande. Un moteur de reconnaissance vocale doit être installé et activé sur l'appareil.

## 3. Langues

Le français est sélectionné par défaut. L'option wolof est proposée, mais sa reconnaissance et sa synthèse ne sont disponibles que si le service vocal installé sur l'appareil prend réellement en charge `wo_SN` / `wo-SN`. Si ce n'est pas le cas, l'application affiche un message et ne prétend pas que la langue est prise en charge.

## 4. Commandes disponibles

- « Ouvre les récoltes »
- « Ouvre les pertes »
- « Ouvre le scanner »
- « Ouvre la carte »
- « Ouvre mon profil »

Les commandes vocales naviguent uniquement dans l'application. Elles ne créent, ne modifient et ne suppriment aucune récolte ou perte.


## 5. Assistant agricole connecté à Gemini

L'écran `AssistantVocalScreen` conserve les commandes locales de navigation et transmet
les questions agricoles (qui ne sont pas des commandes de navigation) à l'endpoint
Django `POST /api/ia/conseiller/`. La réponse `answer` est affichée puis lue par
`flutter_tts`. Un champ de saisie reste disponible si la reconnaissance vocale de
la langue choisie n'est pas installée sur le téléphone.

Le tableau de bord mobile ouvre désormais cet écran avec le bouton
« Assistant agricole — parler à Gemini ».

## 6. Assistant agricole dans Django Web

Le composant flottant ajouté dans `pertes/templates/pertes/base.html` est présent
sur les pages qui héritent de ce template. Il utilise les interfaces Web Speech
`SpeechRecognition` / `webkitSpeechRecognition` et `speechSynthesis` lorsqu'elles
sont prises en charge par le navigateur. Les questions sont envoyées à la même API
Django `/api/ia/conseiller/`; la réponse Gemini est affichée et lue à voix haute.

Utilisez le site en HTTPS ou sur `localhost` / `127.0.0.1` pour permettre l'accès
au microphone. Autorisez le microphone dans le navigateur. Si la reconnaissance
vocale n'est pas disponible, saisissez la question manuellement.

## 7. Limites de prise en charge linguistique

Les huit langues sont proposées comme langues de réponse à Gemini. Cela ne garantit
pas que le moteur vocal du téléphone ou du navigateur sache reconnaître et prononcer
chacune d'elles. La reconnaissance et la synthèse sont dépendantes des moteurs
installés et de leurs langues disponibles. Le code affiche un avertissement lorsque
la reconnaissance demandée n'est pas disponible ; le mode texte reste utilisable.
Les traductions et réponses dans les langues nationales doivent être validées par
des locuteurs natifs avant une mise en production.


## 8. Configuration Android après génération de la plateforme

L'archive V18 ne contient pas le dossier `android/`. Après génération de la plateforme
Flutter, vérifiez `android/app/src/main/AndroidManifest.xml` et ajoutez sous `<manifest>` :

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.INTERNET" />
<queries>
    <intent>
        <action android:name="android.speech.RecognitionService" />
    </intent>
</queries>
```

Pour les essais locaux en HTTP uniquement, Android peut aussi exiger
`android:usesCleartextTraffic="true"` sur la balise `<application>`. N'utilisez pas
cette option en production : configurez HTTPS.


## 9. Reconnaissance vocale distante dans Flutter

L'écran Flutter utilise d'abord le moteur vocal natif lorsqu'il expose réellement la langue sélectionnée. Si la langue n'est pas disponible (ou si aucun moteur natif n'est initialisé), l'écran propose un enregistrement PCM mono 16 kHz via le paquet `record`, puis transmet un WAV à `POST /api/ia/transcrire-audio/`. L'enregistrement est conservé temporairement en mémoire pour permettre une nouvelle tentative après une erreur réseau ou une indisponibilité du service.

Cette voie distante nécessite :
- `GEMINI_API_KEY` déjà configurée sur le serveur Django ;
- une connexion entre le téléphone et le serveur (sur appareil physique, configurer `API_BASE_URL` avec l'adresse IP locale du PC, sans exposer de clé API dans Flutter) ;
- l'autorisation du microphone Android (`RECORD_AUDIO`).

Le serveur réessaie brièvement les erreurs temporaires de quota/indisponibilité (429/5xx). Si le fournisseur reste indisponible, l'application affiche une erreur et permet de réessayer avec le même enregistrement. Cela ne garantit pas une reconnaissance parfaite des langues nationales : valider chaque langue et variété avec des locuteurs natifs reste obligatoire. La transcription audio ne crée ni ne modifie aucune donnée métier.
