<p align="center"><img src="../../Assets/AkkuLogo.png" width="160" alt="Akku, le singe-batterie vert"></p>

# Akku

**Comprendre ta batterie à partir de ta routine.** Un compagnon macOS natif et expérimental pour MacBook Air et Pro M1–M5.

[English](../../README.md) · [Español](README.es.md) · [Français](README.fr.md) · [简体中文](README.zh-Hans.md) · [Deutsch](README.de.md) · [Português (Brasil)](README.pt-BR.md)

[Télécharger](https://github.com/Francoocicchetti/Akku/releases) · [Avis et idées](https://github.com/Francoocicchetti/Akku/discussions) · [Signaler un problème](https://github.com/Francoocicchetti/Akku/issues/new/choose)

## Pourquoi j’ai créé Akku

Je suis hispanophone et je ne suis pas programmeur. J’ai créé Akku avec l’aide d’outils d’IA pour prendre soin de mon MacBook et mieux comprendre sa batterie : combien de temps elle tient avec mes habitudes, où je la recharge et quand emporter le chargeur.

Le projet est né de cette envie de préserver mon propre MacBook. Je voulais une application qui apprenne de mon quotidien sans me demander de saisir toutes mes activités. Akku est aussi le petit singe qui m’accompagne : énergique, fatigué, affamé d’électricité ou prêt à suggérer une pause discrète.

**C’est un projet personnel et expérimental. Il peut contenir des bugs, des estimations inexactes et des fonctions encore imparfaites.** Je ne prétends pas être développeur professionnel ni avoir testé tous les MacBook. Je le partage pour que d’autres puissent l’essayer, examiner le code et l’améliorer. Il ne répare pas la batterie et ne prouve pas qu’il prolongera sa durée de vie.

Ma langue maternelle est l’espagnol : **certaines traductions peuvent être maladroites ou erronées**, y compris cette documentation. Les corrections sont bienvenues, dans n’importe laquelle des six langues disponibles.

## Compatibilité et langues

Cette version vise **uniquement les MacBook Air et MacBook Pro M1, M2, M3, M4 ou M5**, avec les variantes Pro/Max concernées. Un seul appareil a été testé physiquement : **un MacBook Air M5**. La reconnaissance d’un modèle ne vaut pas validation de toutes ses configurations.

macOS 13 ou ultérieur est requis, sous réserve de la version minimale propre au Mac. Les anciennes versions compatibles de macOS restent à tester sur appareil. Intel, Mac de bureau, MacBook Neo, Windows et Linux sont hors du périmètre actuel, même si le script peut générer un binaire Intel.

Une installation neuve démarre en anglais. Le français, l’espagnol, le chinois simplifié, l’allemand et le portugais du Brésil sont accessibles immédiatement depuis l’en-tête ou les réglages. Le choix est conservé.

## Fonctionnalités

### Une charge complète, ta routine

Akku estime **l’autonomie de 100 % à 0 % avec les usages observés pendant les sept derniers jours**. L’écran principal ne demande ni activité ni durée manuelle. Le calcul utilise la baisse réelle du pourcentage et le temps observé sur batterie, Mac éveillé. Recharge, veille et périodes sans mesures sont exclues. La réserve de sécurité n’est pas déduite et le niveau actuel n’est pas considéré comme une charge complète.

Il faut trois jours observés, au moins dix minutes chacun, quatre-vingt-dix minutes au total et cinq points de batterie consommés. Avant cela, Akku affiche l’avancement de l’apprentissage. Le résultat est une plage accompagnée d’un niveau de confiance ; la variation entre les jours l’élargit. La confiance de routine est limitée à moyenne tant que la calibration réelle reste insuffisante. D’autres tâches ou accessoires peuvent changer le résultat.

### Enregistrement automatique et historique

Débrancher le chargeur démarre une session. Si Akku s’ouvre alors que le Mac fonctionne déjà sur batterie, l’observation commence à cet instant. Un départ du domicile confirmé peut aussi déclencher une session. Aucun bouton de scan n’est nécessaire. Une recharge optimisée en pause, avec le chargeur branché, n’est pas une déconnexion.

La veille et les interruptions sont exclues ; l’observation reprend au réveil. Une connexion stable pendant une minute termine la session. Akku doit fonctionner pour apprendre ; l’ouverture à la connexion est facultative. Désactiver l’apprentissage suspend l’enregistrement.

Les statistiques présentent la semaine, les sessions, les points consommés et le temps au domicile, ailleurs ou sans position connue. Le panneau batterie couvre **24 heures et 10 jours**, avec niveau, recharge, connexion, écran allumé observé et détail des intervalles. L’historique absent n’est pas inventé. Un écran allumé ne prouve pas l’attention ; les points peuvent dépasser 100 après plusieurs recharges.

### Applications réelles

Les informations natives de macOS permettent de reconnaître Safari, FaceTime, ChatGPT, WhatsApp et les autres applications ouvertes, avec leurs icônes. Temps d’ouverture et utilisation au premier plan sont séparés, par jour et par lieu.

Akku observe aussi la consommation du Mac entier pendant que des combinaisons d’apps sont ouvertes. **Le CPU n’est pas une mesure exacte d’énergie par app.** FaceTime ouvert ne prouve pas un appel ; un site dans Safari reste Safari. Aucun message, document, onglet, contenu d’écran ou frappe clavier n’est lu. Les appels en arrière-plan et la lecture sans interaction peuvent être sous-estimés.

### Lieux, carte et retour

La carte interactive Apple MapKit montre les lieux fréquents, les recharges observées, les épisodes de batterie faible et les usages sur 7 ou 30 jours. Sélectionner un lieu donne accès aux apps et observations associées. Des visites répétées peuvent suggérer domicile ou travail, mais tu confirmes leur signification.

La localisation automatique nécessite l’autorisation de macOS et peut être désactivée. L’apprentissage de la batterie reste disponible. Tu peux saisir un lieu ou une position actuelle manuellement ; cette dernière dure trente minutes et n’est jamais présentée comme un départ détecté. La recherche d’adresse consulte Apple Maps lorsque tu appuies sur Rechercher.

« Tu sors ? » est un avis discret après un changement confirmé, pas une détection instantanée. La distance au domicile est **à vol d’oiseau, pas un itinéraire ni un temps de trajet**. Les conseils de recharge utilisent batterie, réserve et durées de retour/utilisation indiquées. Ils ne garantissent pas de rentrer sans recharger. Akku ne remplace pas Localiser et ne retrouve pas à distance un Mac éteint.

### Un compagnon animé, avec modération

Akku possède huit états : prêt, plein d’énergie, en recharge, fatigué, épuisé, pause, soirée et sortie. Le nourrir signifie brancher le vrai chargeur. Ses messages utilisent heure, batterie, usage récent et localisation autorisée, sans service d’IA distant.

Les animations commencent à l’apparition ou au changement d’état, puis continuent par courtes séquences. Elles s’arrêtent quand l’app est masquée, en économie d’énergie, en mode Urgence ou avec Réduire les animations. Les rappels de pause restent dans l’app et peuvent être coupés ; ce ne sont pas des mesures de santé.

### Urgence et consommation propre

Le mode Urgence tente de réduire la luminosité sur les écrans compatibles, ralentit les consultations d’Akku, explique les changements et permet de les annuler. L’économie d’énergie et les synchronisations des autres apps nécessitent une intervention manuelle. Fermer une app demande confirmation et un arrêt normal, sans fermeture forcée ; cela peut couper un appel ou un transfert. Rouvrir ne restaure pas le travail non enregistré. Aucune heure supplémentaire n’est garantie.

Les observations ont lieu environ chaque minute en arrière-plan ou toutes les trente secondes quand l’interface est visible. La veille arrête le minuteur. Écritures regroupées, CPU à la demande, requêtes de position espacées après échec et brèves animations à huit images par seconde limitent le travail. **Un faible coût énergétique est un objectif, pas une consommation nulle ni une mesure validée sur tous les Mac.**

## Confidentialité

Pas de compte Akku, d’analytique ni de serveur du développeur. L’historique reste dans `~/Library/Application Support/BatteryTrip`, nom conservé pour la migration. Les données locales comprennent batterie, identifiants et usage des apps, coordonnées des lieux et visites agrégées, sans trajet continu. Cartes, recherche d’adresses et localisation macOS peuvent contacter Apple.

Tu peux effacer l’apprentissage et les lieux. Les exports contiennent batterie et identifiants d’apps, mais pas de coordonnées ni d’associations aux lieux. **Relis et anonymise tout export avant publication.** Ne publie pas ton domicile, tes captures de localisation ou tes fichiers d’usage personnels.

## Installation et code

Télécharge le ZIP dans [Releases](https://github.com/Francoocicchetti/Akku/releases), décompresse-le et déplace `Akku.app` dans Applications. Quitte l’ancienne copie avant remplacement ; préférences et historique sont conservés. Fermer la fenêtre laisse l’app dans la barre des menus. N’exécute pas deux copies ensemble.

Cette version préliminaire dispose d’une **signature locale ad hoc, sans Developer ID ni notarisation Apple**. macOS peut avertir ou refuser l’ouverture. Le projet ne demande pas de désactiver la sécurité du système. La signature pour une distribution plus large reste à faire.

Pour compiler : Mac, Python 3, Xcode/Command Line Tools, SDK compatible et Swift 5.9 ou ultérieur. Aucun paquet tiers requis.

```sh
./test.sh
./build.sh "$PWD/dist"
```

`notarize.sh` nécessite tes propres certificat Developer ID et profil de trousseau ; aucun identifiant secret n’est fourni.

## Avis et contributions

Partage expériences, idées et questions dans [Discussions](https://github.com/Francoocicchetti/Akku/discussions). Les [formulaires par langue](https://github.com/Francoocicchetti/Akku/issues/new/choose) accueillent bugs, consommation et corrections. Indique modèle/puce, macOS, version/langue d’Akku, étapes, résultat attendu/réel, chargeur et économie d’énergie. Pour une traduction : écran, texte actuel et proposition. Les six langues sont bienvenues, particulièrement l’espagnol.

[Feedback](../../FEEDBACK.md) · [Contribuer](../../CONTRIBUTING.md) · [Détails techniques en anglais](../TECHNICAL.md) · [Validation en anglais](../VALIDATION.md) · [Changements](../../CHANGELOG.md). Les tests automatiques ne garantissent pas précision ou économies sur tous les modèles. Aucune licence open source n’a encore été choisie ; ce dépôt ne déclare pas de licence MIT, Apache ou équivalente.
