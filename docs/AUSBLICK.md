# Doppelfaust (Godot) – Ausblick

Stand: 2026-11-03. Stufen 1–7 fertig und headless getestet (`tests/stufe2_test.gd` bis `stufe7_test.gd`, dazu `grafik_test.gd`).
Start: `godot --headless --fixed-fps 3000 --disable-vsync -s tests/stufe4_test.gd` (ohne `--fixed-fps` läuft er in Echtzeit, ~10 min).
Balance-Messung: Parameter `-- normal` (Bot ist sterblich). Online unter https://masta-nksa.github.io/dd/ (Pages-Quelle «GitHub Actions», Workflow `Online stellen` bei jedem Push auf `main`).
Startszene ist `scenes/app.tscn`; Tests der reinen Spielszene laden weiter `scenes/main.tscn`.

## Stufe 3 (Kampf) – Aufbau
- `scripts/combat/`: `AttackData` (Daten), `Attacks` (Tabelle: punch1–3, kick, spin, jump_kick), `HitBox`, `HurtBox` (Quader x/y/z),
  `CombatSystem` (prüft aktive HitBoxen gegen HurtBoxen anderer Teams, jeder Angriff trifft ein Ziel nur einmal).
- `Fighter`: FSM IDLE, WALK, JUMP, ATTACK, HIT, KNOCKDOWN, GETUP, DEAD; Eingabepuffer 0,25 s; Combo startet in der Erholung;
  Trefferpause 0,07 s; Rückstoss; Umwerfen mit Unverwundbarkeit am Boden; Spezial «spin» kostet 4 LP.
- Steuerung: 1P F = Schlag, G = Tritt, R = Spezial; 2P K, L, I. F1 zeigt Hit- (rot) und Hurtboxen (grün).
- Trainingspuppe (Team 1) in `main.gd`, steht nach 2,5 s wieder auf; wird in Stufe 4 durch Gegner ersetzt.
- Offen: Spezial-Kombination F+G.

## Stufen
1. Gerüst (Projekt, Eingabe, Menü, Pause, Web-Export)
2. 2.5D-Kern: `CharacterBody3D`/Node2D mit X, Z (Spur), Y (Sprung), Z-Sortierung, Schatten, Kamera für beide Spieler
3. Kampf: `HitBox`/`HurtBox` (Area), Combos, Spezial, Rückstoss; Angriffe als Daten (`Resource`)
4. Gegner-KI (FSM), vier Typen, Boss, Wellen, Level mit Parallax
5. Waffen Stufe 1 (Greifen, Werfen, Schläger, Kisten, Drops)
6. Töne, HUD, Game-Over/Sieg, Rekord
7. Kämpferwahl mit acht Figuren und 3D-Modellen (Bruce, Chuck, Jackie, JCVD; zusätzlich Kai, Ria, Bruno, Mika; Modelle aus `tools/blender/build_fighter.py`)

## Stufe 4 (Gegner) – Aufbau
- `scripts/enemies/enemy.gd` (`Enemy extends Fighter`): KI-Zustände LURK, CHASE, ATTACK, RETREAT, HURT, DEAD; vier Typen
  (`thug` Schläger, `dasher` Flitzer, `brute` Brocken, `boss` Granit) mit Werten aus dem Pygame-Spiel; Boss mit Anlauf-Rammen.
- Gegnerangriffe `g_*` in `Attacks`; neu in `AttackData`: `drive` (Rammen), `chain_needs_hit`. `Fighter` bekam `body_scale`, `weight`, `score`.
- `scripts/core/wave_director.gd`: fünf Wellen wie im Pygame-Spiel (Level 5400 breit), Nachrücken, Extras bei 2 Spielern,
  höchstens 2 Angreifer pro Spieler von beiden Seiten, tote Gegner verschwinden nach 1,6 s. Kamera bleibt während einer Welle stehen.
- HUD: Banner «WELLE n», «LOS >>>», Punkte, «GESCHAFFT!» / «GAME OVER».
- Tests: 6 Bot-Läufe (1 und 2 Spieler, 3 Zufallswerte) bis zum Levelende ohne Softlock (76–95 s).
- Balance: Der einfache Bot (Dauerfeuer) gewinnt 28 von 28 sterblichen Läufen mit 48–80 LP Rest; ein Mensch spielt anders.
  Echte Schwierigkeit bitte von Hand prüfen. Nicht portiert: Hindernis-Umweg (`umweg`), weil es noch keine Kisten gibt (Stufe 5).

## Stufe 5 (Waffen und Requisiten) – Aufbau
- `scripts/world/`: `Prop` (Kiste, Fass, Tonne, Laterne; blockieren am Boden, Sprung drüber), `WorldItems` (Register + Waffenverteiler),
  `WeaponData`/`Carry` (Tragedinge), `WeaponPickup`, `Pickup` (Huhn +40, Apfel +15, Geld +1000), `Projectile` (Wurf), `Effects` (Splitter, Texte).
- Greifen: 1P E, 2P J. Nichts in Reichweite → das Getragene wird geworfen. Mit Kiste/Fass/Tonne wirft jede Angriffstaste, kein Sprung, langsamer.
- Schläger: Kette 12/18 (2. wirft um), Homerun (Spezial) kostet 2, 10 Haltbarkeit pro Treffer, Wurf 14 Schaden und kostet 3.
  Kiste 18 + 1,2 s, Fass 24 + Umwerfen, Tonne 12 + 1,0 s; zerbricht beim Wurf. Bei Treffern fällt Schweres zu Boden, Gestorbene lassen Waffen blinkend liegen (8 s).
- Drops (Gegner: Schläger 10 %, Flitzer 12 %, Brocken 30 %; Requisiten: Kiste 22 %, Fass 12 %, Tonne 15 %) mit Bremsen wie im Pygame-Spiel;
  erste Kiste enthält immer einen Schläger. Gegner umgehen Hindernisse (`Enemy._detour`) und benutzen keine Waffen.
- Wurfweite ist kurz (~120 px), wie im Pygame-Spiel (Gravitation 1800 statt 1900). Bekannte Mängel: Fass wirft den Brocken um (Gewicht 1,7 teilt nur den Rückstoss).
- Tests: 26 Prüfungen in `stufe5_test.gd`, Bot-Läufe mit Requisiten (6 von 6 ohne Softlock).

## Stufe 6 (Ablauf, Töne, Controller) – Aufbau
- `scripts/core/app.gd` (`App`, Startszene): Menü → Spiel → Pause/Endbildschirm. `Main` kennt das nicht und meldet nur `run_ended(won)` (Sieg nach 4 s, Niederlage nach 2 s).
- `scripts/ui/`: `Screen` (Grundlage mit echten `Button`, also Maus, Tastatur und Controller), `MenuScreen`, `PauseScreen`, `ResultScreen` (Knöpfe 1 s gesperrt).
- Pause: Esc, P oder Start auf jedem Controller. Wird der Controller eines mitspielenden Spielers getrennt, pausiert das Spiel mit Grund.
- `SaveData`: Rekord als Gesamtpunktzahl, getrennt nach 1 und 2 Spielern, dazu Musik an/aus, in `user://doppelfaust.cfg`.
- `SoundBank`: 14 Geräusche und eine Musikschleife (4 Takte, 8 s) im Code berechnet, Port von `ton.py`; `SoundBank.play(id)` bleibt ohne `App` still. M schaltet die Musik.
- Controller: erster Controller = Spieler 1, zweiter = Spieler 2. A Sprung, X/LB Schlag, B Tritt, Y Spezial, RB Greifen, Stick/Kreuz bewegen. Der Greifen-Hinweis im HUD zeigt dann «RB».
- Tests: 44 Prüfungen in `stufe6_test.gd`. Im Browser geprüft: Start, Menü, Spielstart, Pause, Speichern über einen Neuladen. Von Hand zu prüfen: Klang der Töne, echtes Gamepad. Nicht portiert: Rumble, Einsteigen mitten im Spiel.
- Die Warnung «ObjectDB instances leaked» am Ende von `stufe6_test.gd` kommt von Tonobjekten, die beim sofortigen Beenden noch spielen.

## Grafik-Port – Aufbau
- Anlass: Die Stufen 2 bis 6 hatten nur Platzhalter-Grafik. Portiert ist jetzt der Zeichencode des Originals, die Trefferboxen und Kampfwerte sind unverändert.
- `scripts/art/`: `Art` (Farben, Kapseln, Schatten, Text), `Skins` (Aussehen), `Poses` (Gelenkwinkel), `FigureArt` (Skelett-Figur), `LevelPainter` (Himmel, Skyline, Altstadt, Industrie, Hafen, Strasse).
- `Level`: drei Ebenen mit Parallaxe, einmal über `SubViewport` in Texturen gemalt und statisch aufbewahrt; die Strasse in drei Stücken zu 1800 Pixeln. Der Zufall ist fest, aber nicht derselbe wie in Python, die Häuser stehen also anders als im Original.
- `Effects`: Funke, Splitter, Staub, Schwebetext. `CameraRig.shake()`: Bildschirmwackeln.
- `Hud`: Felder mit `Portrait`, Balken mit Nachlaufspur, Herzen, Combo, Gegner- und Boss-Balken. `HeroFigure`: grosse Figuren in Menü und Endbildschirm.
- Neu im Spiel: 2 Extraleben (`Fighter.lives`, Einsteigen von oben, 2,5 s unverwundbar), Combos und Punkte pro Treffer (`count_hit`). Das macht das Spiel leichter als in den Balance-Messungen von Stufe 4 beschrieben.
- Tests: `grafik_test.gd`. Das Aussehen selbst prüfen nur Screenshots neben dem Original.
- Gegner und Ersatzfiguren zeichnet `FigureArt` in 2D wie im Original; die Spielerfiguren sind seit Stufe 7 3D-Modelle (siehe dort).

## Stufe 7 (Kämpferwahl, 3D-Figuren) – Aufbau
- `FighterData` (`scripts/core/`): die acht Kämpfer mit Werten (LP, Tempo x/z, Sprung, Gewicht, Schadens-, Angriffstempo- und Reichweitenfaktor), 2D-`Skins` und Modellpfad.
  Kai, Ria, Bruno, Mika nach `docs/PROJEKTSTAND.md` des Pygame-Spiels (Abschnitt 9, Spezial und eigene Combos noch nicht), Bruce, Chuck, Jackie, JCVD sind ein Vorschlag:
  Bruce 96 LP, schnell (190/124, Angriffe ×1,15); Chuck 106 LP, wuchtig (160/105, Gewicht 1,20, Schaden ×1,06); Jackie 100 LP, höchster Sprung (670), Reichweite ×1,05; JCVD 102 LP, Reichweite ×1,15.
  Balance noch ungemessen: `godot --headless --fixed-fps 3000 -s tests/stufe7_test.gd -- normal` (8 sterbliche Läufe je Figur; Ziel wie im Original: keiner über 35 %, keiner unter 10 % Siegquote; der Bot misst Tempo kaum).
- `SelectScreen` (`scripts/ui/`) zwischen Menü und Spiel: Hauptfiguren oben, weitere Kämpfer unten, je Spieler ein Cursor (1P blau, 2P rot). Bestätigen: Schlag oder Sprung, Zurück: Tritt, Esc: ins Menü.
  Jede Figur nur einmal: Wer bestätigt, sperrt sie, der Cursor des anderen springt weiter und überspringt belegte Karten. Start 0,5 s nach der letzten Bestätigung. Neustart behält die Wahl (`App.picks`); `Main.picks` (Standard Kai/Ria) gilt für Tests.
- `Fighter` bekam `fighter_id`, `damage_factor`, `attack_speed`, `reach_factor`; `Attacks.scaled` macht daraus eine Kopie des Angriffs (die Vorlage bleibt unverändert).
- `ModelFigure` (`scripts/art/`): Das 3D-Modell steht in einem eigenen `SubViewport` (256 px, orthografische Seitenkamera, Teilbild wird auf halbe Grösse gezeichnet); `Fighter._draw` zeichnet das Bild statt `FigureArt`.
  Die Haltung kommt aus denselben Gelenkwinkeln (`Poses`), das Spiel bleibt 2D. Schläger und Kisten sitzen an den Handknochen. Fehlt die `.glb` (oder läuft es headless), zeichnet `FigureArt` die Figur wie vorher.
  Fallstrick: `Skeleton3D.get_bone_global_rest` liefert in Godot 4.4.1 für den Hüft-Teil Nullen; `ModelFigure` rechnet die Rast-Pose selbst aus.
- Die `.glb` liegen nicht im Repo (`.gitignore`). Im Workflow baut ein erster Job (`models`) sie mit Blender 5.0.1 aus `tools/blender/build_fighter.py` und gibt sie als Artefakt an den Export weiter. Schlägt er fehl, läuft der Export mit den 2D-Figuren weiter.
  Lokal: `blender -b -P tools/blender/build_fighter.py -- --fighter all --no-blend`, danach `godot --headless --import`.
- Im Spiel noch 2D: Gegner, HUD-Porträts (2D-Kopf mit demselben Aussehen), Helden in Menü und Endbildschirm (Kai, Ria).
- Tests: `stufe7_test.gd` (Daten, Wahl mit Sperre, App-Ablauf, Werte im Kampf, Modelle samt Haltung und Handpunkten, je ein Bot-Lauf pro Figur). Die Modell-Prüfungen überspringt der Test ohne `.glb`.
  Nicht geprüft: Workflow mit Blender auf GitHub, Browser-Export mit den Modellen (Leistung, MSAA im Web), echtes Gamepad in der Wahl.

## Online-Koop (später, eigener Konzeptvorschlag nötig)
- Node.js-WebSocket-Relay auf Fly.io; Räume mit Code; Godot `WebSocketMultiplayerPeer` + `@rpc`.
- Host-autoritativ: ein Client simuliert die Welt, der andere sendet Eingaben; Client-Prediction nur für die eigene Figur, getrennt vom Spielzustand.
- Offene Fragen: Latenz-Toleranz, Wiederverbinden, Spielerzahl (nur 2?).

## Nächste Schritte
- Browser-Prüfung der Online-Fassung mit den Modellen (nach dem ersten Lauf des Workflows `Online stellen`).
- Balance der acht Figuren messen, Werte von Bruce, Chuck, Jackie, JCVD mit dem User abstimmen.
- Eigene Spezialangriffe und Combos je Figur (Pygame-Konzept, Abschnitt 9); Gegner und Porträts als 3D.
