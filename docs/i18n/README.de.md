<p align="center"><img src="../../Assets/AkkuLogo.png" width="160" alt="Akku, der grüne Batterie-Affe"></p>

# Akku

**Deine Batterie verstehen – anhand deines Alltags.** Ein experimenteller, nativer macOS-Begleiter für MacBook Air und Pro mit M1–M5.

[English](../../README.md) · [Español](README.es.md) · [Français](README.fr.md) · [简体中文](README.zh-Hans.md) · [Deutsch](README.de.md) · [Português (Brasil)](README.pt-BR.md)

[Download](https://github.com/Francoocicchetti/Akku/releases) · [Feedback und Ideen](https://github.com/Francoocicchetti/Akku/discussions) · [Problem melden](https://github.com/Francoocicchetti/Akku/issues/new/choose)

## Warum ich Akku entwickelt habe

Meine Muttersprache ist Spanisch, und ich bin kein Programmierer. Ich habe Akku mit Hilfe von KI-Werkzeugen erstellt, weil ich besser auf mein MacBook achten und seine Batterie verstehen wollte: Wie lange hält sie bei meiner Nutzung, wo lade ich gewöhnlich, und wann sollte das Ladegerät mit?

Das Projekt entstand aus dem Wunsch, meinem eigenen MacBook etwas Gutes zu tun. Die App sollte meinen Alltag kennenlernen, ohne dass ich jede Tätigkeit eintragen muss. Akku ist auch der kleine Affe, der mich begleitet: munter, müde, hungrig nach Strom oder mit einer unaufdringlichen Erinnerung an eine Pause.

**Dies ist ein persönliches, experimentelles Projekt. Es kann Fehler, ungenaue Schätzungen und unfertiges Verhalten enthalten.** Ich behaupte weder professionelle Programmiererfahrung noch Tests auf jedem MacBook. Ich veröffentliche den Code, damit andere die App ausprobieren, prüfen und verbessern können. Sie repariert keine Batterie und belegt keine Verlängerung ihrer Lebensdauer.

Da ich Spanisch spreche, **können Übersetzungen holprig oder falsch sein**, auch diese Dokumentation. Korrekturen sind willkommen. Feedback ist in allen sechs verfügbaren Sprachen möglich.

## Kompatibilität und Sprachen

Diese Version richtet sich **nur an MacBook Air und MacBook Pro mit M1, M2, M3, M4 oder M5**, einschließlich der jeweiligen Pro/Max-Varianten. Physisch getestet wurde bisher **ein MacBook Air M5**. Modellerkennung bedeutet keine vollständige Validierung aller Konfigurationen.

Erforderlich ist macOS 13 oder neuer, wobei die Mindestversion des jeweiligen Macs gilt. Ältere kompatible macOS-Versionen benötigen noch reale Tests. Intel-Macs, Desktop-Macs, MacBook Neo, Windows und Linux gehören nicht zum aktuellen Supportumfang. Ein im Build erzeugter Intel-Anteil ist keine Supportzusage.

Eine neue Installation startet auf Englisch. Spanisch, Französisch, vereinfachtes Chinesisch, Deutsch und brasilianisches Portugiesisch lassen sich im Kopfbereich oder in den Einstellungen auswählen. Die Auswahl bleibt gespeichert.

## Funktionen

### Eine volle Ladung, dein Alltag

Akku schätzt, **wie lange 100 % bis 0 % bei der in den letzten sieben Tagen beobachteten Nutzung reichen würden**. Auf der Startseite gibt es keine manuelle Auswahl von Tätigkeit oder Dauer. Grundlage sind gemessener Prozentverlust und beobachtete Wachzeit im Batteriebetrieb. Laden, Ruhezustand und Messlücken zählen nicht. Die Sicherheitsreserve wird hier nicht abgezogen; der aktuelle Ladestand wird nicht als volle Batterie behandelt.

Für die erste Schätzung sind drei Tage mit jeweils mindestens zehn Minuten, insgesamt neunzig Minuten und fünf verbrauchte Prozentpunkte erforderlich. Davor zeigt die App den Lernfortschritt. Das Ergebnis besteht aus einer Spanne und einer Vertrauensstufe. Unterschiedliche Tagesverläufe verbreitern die Spanne. Das Vertrauen für Alltagsschätzungen bleibt höchstens mittel, solange eine reale Kalibrierung fehlt. Andere Aufgaben oder Zubehör können die Laufzeit verändern.

### Automatische Aufzeichnung und Verlauf

Abziehen des Ladegeräts startet eine Sitzung. Wird Akku bereits im Batteriebetrieb geöffnet, beginnt die Beobachtung erst dann. Auch ein bestätigtes Verlassen des Zuhauses kann eine Sitzung beginnen. Ein Scan- oder Startknopf ist nicht nötig. Angeschlossenes, pausiertes optimiertes Laden gilt nicht als Abziehen.

Ruhezustand und Lücken werden ausgelassen; nach dem Aufwachen geht es weiter. Eine stabile Stromverbindung von einer Minute beendet die Sitzung. Akku muss zum Lernen laufen; der Start bei Anmeldung ist optional. Das Abschalten des Lernens pausiert die Aufzeichnung.

Die Statistik enthält Wochenverlauf, Sitzungen, verbrauchte Prozentpunkte und Zeit zu Hause, unterwegs oder ohne bekannte Position. Das Batteriepanel zeigt **24 Stunden und 10 Tage**, Ladestand, Lade- und Anschlusszeiten, beobachtete Bildschirmzeit und einzelne Intervalle. Fehlende Historie wird nicht erfunden. Ein eingeschalteter Bildschirm beweist keine Aufmerksamkeit; über mehrere Ladevorgänge können mehr als 100 Punkte verbraucht werden.

### Echte Apps und Kombinationen

Native macOS-Informationen erkennen Safari, FaceTime, ChatGPT, WhatsApp und andere geöffnete Apps samt Symbolen. Öffnungszeit und Vordergrundnutzung werden getrennt nach Tag und Ort angezeigt.

Akku lernt auch den Verbrauch des gesamten Macs bei geöffneten App-Kombinationen. **CPU-Nutzung ist keine genaue Energiemessung je App.** Offenes FaceTime beweist keinen Anruf; eine Webseite in Safari bleibt Safari. Nachrichten, Dokumente, Tabs, Bildschirminhalte und Tastendrücke werden nicht gelesen. Hintergrundanrufe und Lesen ohne Interaktion können unterschätzt werden.

### Orte, Karte und Heimweg

Die interaktive Apple-MapKit-Karte zeigt häufige Orte, beobachtete Ladevorgänge, niedrigen Ladestand und Nutzung über 7 oder 30 Tage. Ein ausgewählter Ort zeigt zugehörige Apps und Beobachtungen. Wiederholte Besuche können Vorschläge für Zuhause oder Arbeit ergeben; ihre Bedeutung bestätigst du selbst.

Automatische Ortung benötigt die macOS-Erlaubnis und ist abschaltbar. Das Batterielernen funktioniert ohne sie. Orte oder eine aktuelle Position können manuell eingetragen werden. Eine manuelle aktuelle Position gilt dreißig Minuten und wird nie als automatisch erkannter Aufbruch dargestellt. Die Adresssuche fragt Apple Maps erst nach Betätigung von Suchen ab.

„Gehst du los?“ erscheint unaufdringlich nach einem bestätigten Wechsel, nicht sofort an der Haustür. Die Entfernung ist **Luftlinie, keine Route und keine Fahrzeit**. Ladeempfehlungen nutzen Batterie, Reserve sowie deine Angaben zu Heimweg und weiterer Nutzung. Sie garantieren nicht, ohne Laden nach Hause zu kommen. Akku ersetzt nicht „Wo ist?“ und ortet keinen ausgeschalteten Computer aus der Ferne.

### Der animierte Begleiter

Akku hat acht Zustände: bereit, voller Energie, ladend, müde, erschöpft, Pause, Abend und unterwegs. Füttern bedeutet, das echte Ladegerät anzuschließen. Uhrzeit, Batterie, jüngste Nutzung und erlaubte Position bestimmen seine Hinweise; ein entfernter KI-Dienst ist nicht nötig.

Animationen beginnen beim Einblenden oder Stimmungswechsel und laufen danach in kurzen Abschnitten. Bei versteckter Oberfläche, Stromsparmodus, Notfallmodus oder reduzierter Bewegung pausieren sie. Pausenhinweise bleiben innerhalb der App und lassen sich stummschalten. Sie sind Näherungen, keine Gesundheitsmessungen.

### Notfallmodus und eigener Verbrauch

Der Notfallmodus versucht, auf unterstützten Displays die Helligkeit zu senken, reduziert Akkus Abfragen, zeigt Änderungen an und bietet Rückgängig. Stromsparmodus und Synchronisation anderer Apps benötigen manuelle Schritte. Das Schließen einer App erfordert Bestätigung und fordert normales Beenden an; es wird nicht erzwungen und kann Anrufe oder Uploads unterbrechen. Erneutes Öffnen stellt ungespeicherte Arbeit nicht wieder her. Eine zusätzliche Stunde wird nicht garantiert.

Beobachtungen erfolgen ungefähr jede Minute im Hintergrund oder alle dreißig Sekunden bei sichtbarer Oberfläche. Im Ruhezustand stoppt der Timer. Schreibvorgänge werden gebündelt, CPU-Daten nur bei Bedarf geprüft und fehlgeschlagene Ortungsanfragen seltener wiederholt. Kurze Animationen laufen mit acht Bildern pro Sekunde. **Wenig Verbrauch ist ein Entwicklungsziel, kein Nullverbrauch und kein Messergebnis für alle Macs.**

## Datenschutz

Es gibt kein Akku-Konto, keine Analyseplattform und keinen Entwickler-Server. Der Verlauf bleibt unter `~/Library/Application Support/BatteryTrip`; die alte Identität erhält bestehende Daten. Lokal gespeichert werden Batterie, App-Kennungen und Nutzung, Ortskoordinaten und zusammengefasste Besuche, keine durchgehende Route. Karten, Adresssuche und macOS-Ortung können Apple kontaktieren.

Lerndaten und Orte sind löschbar. Exporte enthalten Batterie und App-Kennungen, aber keine Koordinaten oder Ortszuordnungen. **Prüfe und anonymisiere Exporte vor dem Teilen.** Keine Wohnadresse, Standortaufnahmen oder persönlichen Nutzungsdateien öffentlich posten.

## Installation und Build

ZIP aus den [Releases](https://github.com/Francoocicchetti/Akku/releases) laden, entpacken und `Akku.app` nach Programme verschieben. Alte Kopien vor dem Austausch beenden. Einstellungen und Verlauf bleiben erhalten. Das Schließen des Fensters lässt die Menüleisten-App weiterlaufen; keine zwei Versionen parallel starten.

Die Vorschau hat eine **lokale Ad-hoc-Signatur, keine Developer-ID-Signatur oder Apple-Notarisierung**. macOS kann warnen oder das Öffnen verweigern. Das Projekt verlangt kein Abschalten der Systemsicherheit. Die Signierung für breitere Verteilung steht noch aus.

Zum Bauen: Mac, Python 3, Xcode/Command Line Tools, passendes SDK und Swift ab 5.9. Keine externen Pakete erforderlich.

```sh
./test.sh
./build.sh "$PWD/dist"
```

`notarize.sh` benötigt ein eigenes Developer-ID-Zertifikat und Schlüsselbundprofil; Zugangsdaten sind nicht enthalten.

## Feedback und Beiträge

Erfahrungen, Ideen und Fragen gehören in [Discussions](https://github.com/Francoocicchetti/Akku/discussions). Für Fehler, Verbrauch und Übersetzungen gibt es [Formulare je Sprache](https://github.com/Francoocicchetti/Akku/issues/new/choose). Bitte Modell/Chip, macOS, Akku-Version/Sprache, Schritte, Erwartung und Ergebnis sowie Ladegerät/Stromsparmodus nennen. Übersetzungsvorschläge brauchen Bildschirm, aktuellen Text und bessere Formulierung. Alle sechs Sprachen sind willkommen, besonders Spanisch.

[Feedback](../../FEEDBACK.md) · [Mitwirken](../../CONTRIBUTING.md) · [Technische Details auf Englisch](../TECHNICAL.md) · [Validierung auf Englisch](../VALIDATION.md) · [Änderungen](../../CHANGELOG.md). Automatische Tests garantieren weder Präzision noch Einsparungen auf allen Modellen. Es wurde noch keine Open-Source-Lizenz gewählt; das Repository erklärt keine MIT-, Apache- oder vergleichbare Lizenzgewährung.
