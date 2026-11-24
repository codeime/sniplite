> [!IMPORTANT]
> **sniplite for Mac.** Dieses Repository pflegt nur die **macOS**-Version (in [`macos`](../macos/README.md), Download unter [Releases](https://github.com/codeime/sniplite/releases/latest)). Für **Windows** laden Sie sniplite aus dem ursprünglichen Repository: [MrTangLuyao/sniplite](https://github.com/MrTangLuyao/sniplite/releases/latest).

<div align="center">

<img src="../pics/macos/icon.png" width="96" alt="sniplite-Symbol">

# sniplite

**Ein winziges, schnelles Werkzeug für Screenshots und Pins auf macOS**

[![English](https://img.shields.io/badge/English-eaeef2?style=flat-square)](../README.md) [![简体中文](https://img.shields.io/badge/%E7%AE%80%E4%BD%93%E4%B8%AD%E6%96%87-eaeef2?style=flat-square)](README.zh-CN.md) [![繁體中文](https://img.shields.io/badge/%E7%B9%81%E9%AB%94%E4%B8%AD%E6%96%87-eaeef2?style=flat-square)](README.zh-TW.md) [![日本語](https://img.shields.io/badge/%E6%97%A5%E6%9C%AC%E8%AA%9E-eaeef2?style=flat-square)](README.ja.md) [![한국어](https://img.shields.io/badge/%ED%95%9C%EA%B5%AD%EC%96%B4-eaeef2?style=flat-square)](README.ko.md) [![Français](https://img.shields.io/badge/Fran%C3%A7ais-eaeef2?style=flat-square)](README.fr.md) [![Deutsch](https://img.shields.io/badge/Deutsch-1677e5?style=flat-square)](README.de.md) [![Español](https://img.shields.io/badge/Espa%C3%B1ol-eaeef2?style=flat-square)](README.es.md)

[![Version](https://img.shields.io/github/v/release/codeime/sniplite?label=Version&style=flat-square&color=1677e5)](https://github.com/codeime/sniplite/releases) [![System](https://img.shields.io/badge/System-macOS%2014%2B-3b82f6?style=flat-square)](#download) [![Lizenz](https://img.shields.io/badge/Lizenz-MIT-3b82f6?style=flat-square)](../LICENSE)

[**Download**](#download) | [Standard-Tastenkürzel](#standard-tastenkürzel) | [Häufige Fragen](#häufige-fragen)

<img src="../pics/macos/edit.png" alt="Einen Bereich wählen und direkt darauf Kreise, Pfeile, Text und Nummern zeichnen" width="66%">
<br>
<img src="../pics/macos/select.png" alt="Vor der Aufnahme wird das Fenster oder Element unter der Maus erkannt; die Lupe zeigt Pixel und Farben" width="32.5%"> <img src="../pics/macos/pin.png" alt="Einen Screenshot oder Text über allen Fenstern anheften; das Mausrad zoomt" width="32.5%">
<br>
<img src="../pics/macos/ocr.png" alt="Den Text der Auswahl lesen; eine Tabelle behält ihre Spalten" width="66%">

</div>

## Merkmale

- **Schnell**: F1 drücken, und die Aufnahme ist sofort bereit
- **Findet, worauf Sie zeigen**: das Fenster oder der Teil eines Fensters (ein Knopf, ein Feld, eine Liste) unter der Maus wird für Sie ausgewählt; das Mausrad geht zu größeren Teilen
- **Zeichnen**: Rechtecke, Ellipsen, Linien, Pfeile, Stift, Marker, Text, Nummern und Mosaik, jedes mit eigener Größe und Deckkraft; alles Gezeichnete lässt sich später auswählen und ändern
- **Pins**: eine Aufnahme oder Kopiertes über allen Fenstern anheften; zoomen, Deckkraft ändern, wieder darauf zeichnen
- **Texterkennung**: liest den Text einer Aufnahme, Tabellen eingeschlossen, mit Apples Vision auf diesem Mac (optional, standardmäßig aus)
- **Leicht**: etwa 2 MB, nativ auf Apple Silicon und Intel, etwa 15–25 MB Speicher im Leerlauf
- **Sauber**: Open Source, keine Werbung, nichts wird gesammelt oder hochgeladen
- **Sprachen**: English, 简体中文, 繁體中文, je nach System

## Download

Laden Sie `sniplite_<Version>_macos.zip` unter [Releases](https://github.com/codeime/sniplite/releases/latest) herunter, entpacken Sie es und verschieben Sie `sniplite.app` in den Ordner Programme. Nötig ist macOS 14 Sonoma oder neuer.

sniplite ist nicht von Apple beglaubigt, daher blockiert macOS es zunächst („kann nicht geöffnet werden“ oder „ist beschädigt“). Führen Sie nach dem Verschieben einmal aus:

```bash
xattr -dr com.apple.quarantine "/Applications/sniplite.app"
```

> [!TIP]
> sniplite sitzt in der Menüleiste (vier Ecken und ein Blitz) und hat kein Symbol im Dock. Beim ersten Start zeigt es, was zu erlauben ist: Bildschirmaufnahme zum Aufnehmen und Bedienungshilfen für die Tasten F1–F12 und um die Teile von Fenstern zu finden.

## Standard-Tastenkürzel

| Taste | Funktion |
| --- | --- |
| **F1** | Aufnahme |
| **⇧F1** | Schnellaufnahme: der Bildschirm unter der Maus direkt in eine Datei (wenn in den Einstellungen eingeschaltet) |
| **F3** | Kopiertes Bild oder kopierten Text anheften |
| **⇧F3** | Alle Pins aus- / einblenden |
| **F4** / **⇧F4** | Aufnehmen und Text lesen / kopieren (bei eingeschalteter Texterkennung) |
| **Eingabe** / Doppelklick | Aufnahme kopieren |
| **⌘S** | Speichern |
| **⌘T** / Mittelklick | Anheften |
| **⌘Z** / **⇧⌘Z** | Widerrufen / Wiederholen |
| **Esc** / Rechtsklick | Einen Schritt zurück; am Ende abbrechen |
| **Pfeiltasten**, **W A S D** | Um ein Pixel verschieben; mit Umschalt um zehn |
| **Mausrad** / zwei Finger | Beim Auswählen: größerer oder kleinerer Teil; mit Werkzeug: seine Größe; auf einem Pin: Zoom |
| **⌥ + Mausrad** | Mit Werkzeug: seine Deckkraft; auf einem Pin: dessen Deckkraft |
| **⌘E** (auf einem Pin) | Wieder auf den Pin zeichnen |

Alle Tastenkürzel stehen im [README der macOS-Version](../macos/README.md#shortcuts); die globalen lassen sich in den Einstellungen ändern.

## Häufige Fragen

**Warum meldet macOS, sniplite „kann nicht geöffnet werden“ oder „ist beschädigt“?**

Es ist nicht von Apple beglaubigt. Führen Sie den `xattr`-Befehl unter [Download](#download) einmal aus: Er entfernt die Markierung, die macOS heruntergeladenen Dateien gibt.

**Warum ändert F1 stattdessen die Helligkeit?**

Die Kürzel F1–F12 brauchen die Bedienungshilfen-Berechtigung (unter macOS 27 „Device Control and Data Access“). Erlauben Sie sie über das Menüleistensymbol unter Permissions….

**Muss ich die Berechtigungen nach einem Update neu erteilen?**

Meist ja: sniplite ist ad hoc signiert, daher sieht macOS jede Version als neue App. sniplite entfernt die alten Einträge selbst und öffnet seine Berechtigungsseite; ziehen Sie es wieder in die Liste.

**Wie lese ich den Text einer Aufnahme?**

Schalten Sie Text recognition unter Settings › Capture ein. Nutzen Sie dann die Textknöpfe der Werkzeugleiste, ⌘O oder F4 / ⇧F4. Das läuft mit Apples Vision auf diesem Mac; nichts wird hochgeladen.

**Wie viel Speicher braucht es?**

Etwa 15–25 MB im Leerlauf. Eine Aufnahme hält das Bild des Bildschirms nur, solange sie offen ist, und gibt es dann frei.

**Wo sind Einstellungen und Protokoll?**

Die Einstellungen sind die Voreinstellungen der App (`defaults read io.github.codeime.sniplite`); ein kurzes Protokoll zu Kürzeln, Berechtigungen und Erkennungszeiten liegt in `~/Library/Logs/sniplite.log`.

**Wie deinstalliere ich es?**

Beenden Sie es über die Menüleiste und löschen Sie `sniplite.app` aus Programme. Um auch die Einstellungen zu löschen, führen Sie `defaults delete io.github.codeime.sniplite` aus; steht es noch unter Datenschutz & Sicherheit in den Systemeinstellungen, entfernen Sie es dort ebenfalls.

**Gibt es eine Windows-Version?**

Ja, das Original: [MrTangLuyao/sniplite](https://github.com/MrTangLuyao/sniplite/releases/latest).

## Einstellungen

<img src="../pics/macos/settings.png" alt="Die Einstellungen von sniplite für Mac">

## Selbst bauen

Nötig sind nur die Xcode-Befehlszeilenwerkzeuge (`xcode-select --install`), nicht Xcode selbst.

```bash
cd macos
./build.sh          # -> build/sniplite.app (Apple Silicon + Intel)
./build.sh --zip    # zusätzlich build/sniplite_<Version>_macos.zip
./test.sh           # Unit-Tests
```

Der Quellcode liegt in `macos/Sources`, geschrieben in Swift mit AppKit; Signieren und ein Überblick über den Code stehen in [`macos`](../macos/README.md). Ein Tag `macos-v<Version>` lässt GitHub Actions die App bauen und unter Releases veröffentlichen. Der Quellcode der Windows-Version in `src` stammt aus dem ursprünglichen Repository und wird hier nicht gebaut.

## Lizenz

[MIT](../LICENSE)

## Open Source von Dritten

sniplite für Mac nutzt nur, was macOS mitbringt: ScreenCaptureKit zum Aufnehmen, die Bedienungshilfen-API, um Fenster und ihre Teile zu finden, und Vision, um Text zu lesen. Code oder Modelle von Dritten sind nicht enthalten.

Das Feld zum Ziehen für die Berechtigung folgt dem Ansatz von [PermissionFlow](https://github.com/jaywcjlove/PermissionFlow) von jaywcjlove (MIT-Lizenz), neu geschrieben mit AppKit.
