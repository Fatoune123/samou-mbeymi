# Reconnaissance vocale des langues locales — correction ciblée

- Ajout de POST /api/ia/transcrire-audio/ pour transcrire les enregistrements Wolof, Pulaar, Sérère Sine, Joola, Mandinka et Soninké avec Gemini Audio.
- Les interfaces Web flottante et page dédiée enregistrent au maximum 20 secondes, convertissent l'audio en WAV mono 16 kHz dans le navigateur, puis transmettent le fichier au serveur.
- Le français et l'anglais conservent leur reconnaissance vocale Web Speech existante.
- Aucun modèle, migration, table, compte, mot de passe ou donnée métier n'a été modifié. La route de transcription ne fait aucune écriture en base.
- Prérequis : GEMINI_API_KEY doit déjà être configurée côté serveur. GEMINI_TRANSCRIPTION_MODEL est facultative (défaut gemini-2.5-flash). Aucun secret n'est placé dans le navigateur.
- Important : le support audio d'un modèle ne garantit pas la précision dans chaque langue ou variété. Des essais avec locuteurs natifs sont obligatoires, en particulier pour le Sérère Sine et la variété Joola retenue.
- Cette correction concerne la reconnaissance (parole vers texte). La lecture orale des réponses reste dépendante des voix TTS disponibles sur l'appareil.
