# SAMOU MBEYMI — Assistant agricole (V18)

## Périmètre livré dans cette copie

- Les libellés visibles « Assistant vocal » sont remplacés par « Assistant agricole » dans les écrans concernés.
- L'assistant conserve l'entrée écrite et l'entrée par microphone lorsque le moteur de l'appareil les prend en charge.
- Le backend effectue une classification du domaine avant de produire une réponse. Les questions non agricoles reçoivent un refus de périmètre.
- Les consignes de réponse demandent une réponse dans la langue choisie et interdisent d'inventer les traductions, doses, prix ou diagnostics.
- Flutter vérifie si une voix TTS correspondant à la langue choisie est disponible. En l'absence de voix, le texte reste affiché et l'application ne doit pas prétendre avoir prononcé correctement la langue.
- Le doublon de méthode `conseillerAgricole` dans `ApiService` a été supprimé ; l'appel phytosanitaire utilise maintenant la méthode nommée existante.

## Langues proposées

Français, wolof, pulaar, sérère, joola, mandinka, soninké et anglais.

**Important :** la présence d'une langue dans la liste ne signifie pas que le téléphone ou le navigateur possède un moteur ASR/TTS pour cette langue. Les codes linguistiques ne créent pas une voix. La disponibilité réelle dépend du moteur vocal et de sa version. Pour les langues locales, il faut tester séparément :
1. reconnaissance de la parole (ASR/STT) ;
2. qualité de la réponse écrite dans la langue ;
3. synthèse et intelligibilité de la voix (TTS).

Aucun modèle vocal local spécialisé n'a été ajouté dans cette livraison : il faut sélectionner et intégrer un modèle ou service réellement compatible, puis le valider avec des locuteurs natifs. Cela nécessite des échantillons audio consentis et transcrits pour mesurer les erreurs et la prononciation. Ne pas annoncer les six langues comme vocalement opérationnelles avant ces essais.

## Domaine agricole

Le endpoint `/api/ia/conseiller/` demande d'abord au modèle de classifier le sujet en `AGRICOLE` ou `HORS_SUJET`. En cas de doute, il refuse. Pour un sujet classé agricole, un second appel génère la réponse dans la langue demandée. Ce contrôle améliore le respect du périmètre mais reste un contrôle par modèle : il doit être testé contre des questions ambiguës et des tentatives de détourner les instructions.

## Configuration

- Conserver le fichier `.env` de l'installation locale. Ne jamais publier sa clé Gemini.
- Aucun changement de schéma de données n'est requis pour l'assistant.
- Aucun `migrate` n'est requis pour ces modifications.
- L'archive source transmise pour cette livraison ne contenait pas `backend_django/db.sqlite3`. Remettre la base existante depuis la sauvegarde locale dans `backend_django/` après extraction, sans écraser une base plus récente.

## Vérifications

- Syntaxe Python du module Django : vérifiée avec `py_compile`.
- Intégrité de l'archive source : vérifiée.
- `flutter analyze` / `flutter build` : à exécuter dans l'environnement Flutter du projet.
- Essais Gemini : nécessitent la clé locale valide et une connexion Internet.
- Essais ASR/TTS : à faire sur le téléphone Android et le navigateur cible avec des locuteurs natifs des six langues.
