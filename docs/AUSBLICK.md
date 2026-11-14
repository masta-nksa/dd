# Doppelfaust (Godot) – Ausblick

Stand: 2026-11-08. Stufen 1–12 fertig und headless getestet (`tests/stufe2_test.gd` bis `stufe12_test.gd`, dazu `grafik_test.gd`).
Start: `godot --headless --fixed-fps 3000 --disable-vsync -s tests/stufe4_test.gd` (ohne `--fixed-fps` läuft er in Echtzeit, ~10 min).
Balance-Messung: Parameter `-- normal` (Bot ist sterblich). Online unter https://masta-nksa.github.io/dd/ (Pages-Quelle «GitHub Actions», Workflow `Online stellen` bei jedem Push auf `main`).
Startszene ist `scenes/app.tscn`; Tests der reinen Spielszene laden weiter `scenes/main.tscn`.

## Stufe 3 (Kampf) – Aufbau
- `scripts/combat/`: `AttackData` (Daten), `Attacks` (Tabelle: punch1–3, kick_low, kick_high, spin, jump_kick), `HitBox`, `HurtBox` (Quader x/y/z),
  `CombatSystem` (prüft aktive HitBoxen gegen HurtBoxen anderer Teams, jeder Angriff trifft ein Ziel nur einmal).
- `Fighter`: FSM IDLE, WALK, JUMP, ATTACK, HIT, KNOCKDOWN, GETUP, DEAD; Eingabepuffer 0,25 s; Combo startet in der Erholung;
  Trefferpause je Angriff (`AttackData.hitstop`); Rückstoss; Umwerfen mit Unverwundbarkeit am Boden; Spezial «spin» kostet 4 LP.
- Steuerung: 1P F = Schlag, G = Low Kick, T = High Kick, R = Spezial; 2P K, L, U, I. F1 zeigt Hit- (rot) und Hurtboxen (grün).
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
8. Kampfbewegungen: Clips aus Blender (bisher nur Bruce), Low Kick und High Kick, Combos quer über Schlag und Tritt, Trefferwirkung
9. Baseballschläger: 3D-Modell in echter Länge, Schwünge mit beiden Händen (bisher nur Bruce), Abwehr und Konter
10. Gegner als 3D-Modelle mit zufälligen Varianten (Schritt 1 des Gegner-Konzepts; Stilpakete, neue Typen und Bossphasen folgen)
11. Nachschub statt Wellen, stärkere Gegner, zweites Level (Chinatown)
12. Schläger-Clips für alle Figuren, Gegner holen und schwingen den Schläger

## Stufe 4 (Gegner) – Aufbau
- `scripts/enemies/enemy.gd` (`Enemy extends Fighter`): KI-Zustände LURK, CHASE, ATTACK, RETREAT, HURT, DEAD; vier Typen
  (`thug` Schläger, `dasher` Flitzer, `brute` Brocken, `boss` Granit) mit Werten aus dem Pygame-Spiel; Boss mit Anlauf-Rammen.
- Gegnerangriffe `g_*` in `Attacks`; neu in `AttackData`: `drive` (Rammen), `chain_needs_hit`. `Fighter` bekam `body_scale`, `weight`, `score`.
- `scripts/core/wave_director.gd`: ursprünglich fünf Wellen wie im Pygame-Spiel, seit Stufe 11 Nachschub ohne Wellen (siehe dort); höchstens 3 Angreifer pro Spieler von beiden Seiten, tote Gegner verschwinden nach 1,6 s.
- HUD: Banner, Punkte, «GESCHAFFT!» / «GAME OVER».
- Tests: 6 Bot-Läufe (1 und 2 Spieler, 3 Zufallswerte) bis zum Levelende ohne Softlock (76–95 s).
- Balance: Der einfache Bot (Dauerfeuer) gewinnt 28 von 28 sterblichen Läufen mit 48–80 LP Rest; ein Mensch spielt anders.
  Echte Schwierigkeit bitte von Hand prüfen. Nicht portiert: Hindernis-Umweg (`umweg`), weil es noch keine Kisten gibt (Stufe 5).

## Stufe 5 (Waffen und Requisiten) – Aufbau
- `scripts/world/`: `Prop` (Kiste, Fass, Tonne, Laterne; blockieren am Boden, Sprung drüber), `WorldItems` (Register + Waffenverteiler),
  `WeaponData`/`Carry` (Tragedinge), `WeaponPickup`, `Pickup` (Huhn +40, Apfel +15, Geld +1000), `Projectile` (Wurf), `Effects` (Splitter, Texte).
- Greifen: 1P E, 2P J. Nichts in Reichweite → das Getragene wird geworfen. Mit Kiste/Fass/Tonne wirft jede Angriffstaste, kein Sprung, langsamer.
- Schläger: Kette 12/18 (2. wirft um), Homerun (Spezial) kostet 2, 10 Haltbarkeit pro Treffer, Wurf 14 Schaden und kostet 3. Modell, Reichweite und Abwehr: siehe Stufe 9.
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
- Controller: erster Controller = Spieler 1, zweiter = Spieler 2. A Sprung, X Schlag, B Low Kick, LB High Kick, Y Spezial, RB Greifen, Stick/Kreuz bewegen. Der Greifen-Hinweis im HUD zeigt dann «RB».
- Tests: 44 Prüfungen in `stufe6_test.gd`. Im Browser geprüft: Start, Menü, Spielstart, Pause, Speichern über einen Neuladen. Von Hand zu prüfen: Klang der Töne, echtes Gamepad. Nicht portiert: Rumble, Einsteigen mitten im Spiel.
- Die Warnung «ObjectDB instances leaked» am Ende von `stufe6_test.gd` kommt von Tonobjekten, die beim sofortigen Beenden noch spielen.

## Grafik-Port – Aufbau
- Anlass: Die Stufen 2 bis 6 hatten nur Platzhalter-Grafik. Portiert ist jetzt der Zeichencode des Originals, die Trefferboxen und Kampfwerte sind unverändert.
- `scripts/art/`: `Art` (Farben, Kapseln, Schatten, Text), `Skins` (Aussehen), `Poses` (Gelenkwinkel), `FigureArt` (Skelett-Figur), `LevelPainter` (Himmel, Skyline, Altstadt, Industrie, Hafen, Strasse).
- `Level`: drei Ebenen mit Parallaxe, einmal über `SubViewport` in Texturen gemalt und statisch aufbewahrt; die Strasse in drei Stücken zu 1800 Pixeln. Der Zufall ist fest, aber nicht derselbe wie in Python, die Häuser stehen also anders als im Original.
  Text in diesen Texturen nutzt `Art.painted_font()` mit fester Schärfe; die normale Schrift richtet sich nach der Fenstergrösse beim Malen und wurde im Browser unscharf.
- `Effects`: Funke, Splitter, Staub, Schwebetext. `CameraRig.shake()`: Bildschirmwackeln.
- `Hud`: Felder mit `Portrait`, Balken mit Nachlaufspur, Herzen, Combo, Gegner- und Boss-Balken. `HeroFigure`: grosse Figuren in Menü und Endbildschirm.
- Neu im Spiel: 2 Extraleben (`Fighter.lives`, Einsteigen von oben, 2,5 s unverwundbar), Combos und Punkte pro Treffer (`count_hit`). Das macht das Spiel leichter als in den Balance-Messungen von Stufe 4 beschrieben.
- Tests: `grafik_test.gd`. Das Aussehen selbst prüfen nur Screenshots neben dem Original.
- Ersatzfiguren ohne Modell zeichnet `FigureArt` in 2D wie im Original; Spielerfiguren (Stufe 7) und Gegner (Stufe 10) sind 3D-Modelle (siehe dort).

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
  Liegen `.blend` im Ordner, kam `--import` am 2026-11-03 nicht innert 150 s zum Ende; eine Kopie des Projekts ohne `.blend` importierte normal.
- Im Spiel noch 2D: HUD-Porträts (2D-Kopf mit demselben Aussehen), Helden in Menü und Endbildschirm (Kai, Ria), die Trainingspuppe.
- Tests: `stufe7_test.gd` (Daten, Wahl mit Sperre, App-Ablauf, Werte im Kampf, Modelle samt Haltung und Handpunkten, je ein Bot-Lauf pro Figur). Die Modell-Prüfungen überspringt der Test ohne `.glb`.
  Online geprüft (2026-11-03): Workflow baut die acht `.glb` (Artefakt 314 KB), Wahl und Spielstart mit Bruce und Chuck laufen im Browser. Nicht geprüft: Leistung bei längerem Spiel, Balance, echtes Gamepad in der Wahl. Die Schrift des Spiels hat keine Pfeil-Zeichen (←/→).

## Stufe 8 (Kampfbewegungen) – Aufbau
- Clips nur für Bruce (`CLIP_FIGHTERS` in `tools/blender/fighter_clips.py`): `punch1`–`punch3`, `kick_low`, `kick_high`, `jump_kick`, `spin`, je als `<id>_R` und `<id>_L`. Die anderen sieben und die Gegner bleiben bei `Poses`.
- Die Schlüsselposen stehen als Text in `fighter_clips.py`, weil der Workflow die `.glb` neu baut und die `.blend` nicht im Repo liegt. Der Bake rechnet sie auf das Skelett der Figur um: stehende Füsse per IK (reicht das Bein nicht, hebt sich die Ferse), Boden als Grenze. Der Bau bricht ab, wenn ein Fuss über 5 mm rutscht oder über 2 cm in den Boden taucht.
- Zeitachse jedes Clips: 3 s, davon 0–1 Anlauf, 1–2 Treffer, 2–3 Erholung. `AttackData.phase_at` bildet die echte Angriffszeit darauf ab; `ModelFigure.set_clip` tastet die Spuren selbst ab (`rotation_track_interpolate`), kein `AnimationPlayer`. So gelten Angriffstempo und Trefferstopp automatisch, und die Spiellogik bestimmt die Zeit.
- Beim Wechsel zwischen Pose und Clip läuft die Figur über 5 Bilder aus der letzten Haltung in die neue (`_blend_from_last`). Clipnamen ohne Punkt: Godot ersetzt ihn beim Import durch `_`.
- Angriffe: `kick` ist ersetzt durch `kick_low` (schnell, 10 Schaden, trifft unten) und `kick_high` (langsamer, 17 Schaden, trifft oben). Bei den Figuren ohne Clip zeigen die Posen `low_kick` und `high_kick` dasselbe.
- Combos: `AttackData.chains` nennt je Taste den nächsten Angriff, statt `chain_to`. Längste Kette: Schlag, Low Kick, Schlag, High Kick, Schlag. Die Tabelle hat keine Schleifen, das prüft der Test.
- Trefferwirkung: `hitstop` je Angriff, `hit_level` wählt die Reaktion (`Poses.hit`: oben fliegt der Kopf zurück, unten knickt die Figur ein), Bewegungsspur `trail` an Fuss oder Faust (nur bei 3D-Figuren), stärkerer Funke und Kamerastoss ab `hitstop` 0,1 s.
- Vorschau: `blender -b -P tools/blender/build_fighter.py -- --fighter bruce --clip-preview` schreibt Bildreihen nach `build/characters_preview/`. Tests: `stufe8_test.gd`.
- Online geprüft (2026-11-03): Workflow baut die Clips, im Browser laufen Menü, Wahl von Bruce, Low Kick und High Kick ohne Konsolenfehler. Nicht geprüft: Balance mit den neuen Angriffen, echtes Gamepad mit LB, Bildrate im sichtbaren Browserfenster. Bruces `.glb` wuchs durch die Clips von 258 auf rund 490 KB (mit den Schläger-Clips aus Stufe 9).

## Stufe 9 (Baseballschläger) – Aufbau
- Modell: `build_bat` in `tools/blender/build_fighter.py`, wird bei jedem Lauf ohne `--out` als `assets/characters/weapon_bat.glb` gebaut (288 Dreiecke, 12 KB). 86,8 cm lang wie ein Erwachsenenschläger, Kopf mit 9,2 cm bewusst dicker als die erlaubten 6,6 cm, damit er im Spiel sichtbar bleibt. Die Risse sind ein eigenes Objekt `BatCracks`.
- In der Hand: `ModelFigure.show_bat` und `_update_bat`. Der Schläger ist kein Knochen (das Skelett bleibt bei 17) und liest seine Richtung aus dem Knochen der vorderen Hand. Bei Posen verlängert er so den Unterarm, in Clips zeigt die Hand entlang des Schlägers.
- Am Boden, im Flug und im HUD zeichnet `WeaponPickup.draw_bat` ein einmal gerendertes Bild desselben Modells. Ohne `.glb` bleibt eine 2D-Ersatzzeichnung mit denselben Massen.
- Clips (nur Bruce): `w_bat1`, `w_bat2`, `w_homerun`, `w_block`. Mit `bat=True` greifen die Arme per IK den Griff (`grip_*`, `bat_el`, `bat_az`, `grip_gap`). Der Bau bricht ab, wenn eine Hand über 2,5 cm neben dem Griff liegt. Der Rechtshänder holt mit der Brust zur Kamera aus; der Schlägerkopf streicht auf der Kamera-Seite um den Körper, leicht schräg, weil ein waagrechter Schwung in der Seitenansicht zu stark verkürzt wirkt.
- Werte: Reichweite 72 px statt 78–82 px, Anlauf 0,13 / 0,15 / 0,22 s, Schaden und Haltbarkeit wie bisher.
- Abwehr: `Fighter.State.BLOCK`. Mit Schläger hebt die Low-Kick-Taste (G / L / B) ihn hoch, solange sie gehalten wird (`block_held`); man steht still. `try_block` wehrt Angriffe von vorn ohne Schaden und Trefferstarre ab und kostet 1 Haltbarkeit. In den ersten 0,15 s wird daraus ein Konter: Der Angreifer taumelt 0,7 s (`stagger`). Von hinten trifft es weiter. Abgewehrte Angriffe zählen nicht als Treffer (`HitBox.blocked_targets`), Gegner-Ketten laufen dann nicht weiter.
- Tests: `stufe9_test.gd`. Vorschau: `... -- --fighter bruce --clip-preview w_bat1 w_bat2 w_homerun w_block`.
- Figuren ohne Schläger-Clips (nur noch Modelle, die ohne `.glb` laufen) halten den Schläger mit einer Hand und zeigen die Posen `swing`, `homerun`, `block`. Seit Stufe 12 haben alle Modelle die Schläger-Clips.
- Online geprüft (2026-11-03): Im Browser liegt der Schläger nach der ersten Kiste am Boden, lässt sich aufheben, sitzt als 3D-Modell in der Hand, das HUD zeigt ihn samt Abwehr-Hinweis, Abwehr heben und senken läuft, keine Konsolenfehler. Der Schwung selbst nur in der lokalen Aufnahme gesehen. Nicht geprüft: Balance mit Abwehr und kürzerer Reichweite, echtes Gamepad, Bildrate im sichtbaren Browserfenster. Beute landet am selben Punkt wie der Schläger und kann ihn kurz verdecken.

## Stufe 10 (Gegner als 3D-Modelle) – Aufbau
- Modelle: `ENEMIES` (thug, dasher, brute, boss) und `ENEMY_VARIANTS` (thug_cap, dasher_spiky, brute_bare) in `tools/blender/build_fighter.py`, gebaut als `assets/characters/enemy_<name>.glb` (je 2300–2700 Dreiecke, 220–260 KB). Gleiches 17-Knochen-Skelett wie die Kämpfer, `--fighter all` baut sie mit. Neue Bausteine: Frisuren `bald`, `mohawk`, `crop`, Mütze (`hat`), Sonnenbrille (`glasses`), Goldkette (`chain`), kurze Ärmel ohne Handschuhe.
- Aussehen: `EnemyLooks` (`scripts/enemies/`) listet je Typ Varianten aus Modell und Zonenfarben (Schläger 6, Flitzer 5, Brocken 5, Boss 1). `Enemy.create(type, index)` würfelt beim Auftauchen eine Variante mit eigenem Zufall, der den des Spiels nicht verschiebt. Ohne Modell nimmt `FigureArt` dieselben Farben (`skin_for`).
- Umfärben: Die Materialien heissen `<figur>__<zone>` (Godot entfernt «/» und «.» beim Import, Unterstriche bleiben). `ModelFigure.apply_palette` legt je Modell eigene Kopien der Materialien an; eine neue Hautfarbe färbt `shade` mit. Pfad eines Modells: `ModelFigure.path_for` (Kämpfer `player_`, Gegner `enemy_`).
- Leistung: `ModelFigure.set_active` rechnet das Teilbild nur für Figuren im Bild oder nahe daran (`Fighter._on_screen`, Puffer 260 px seitlich). F2 zeigt Bildzeit, Bildrate und die Zahl der gezeichneten 3D-Figuren (`PerfOverlay`). Lokal gemessen (Intel Arc, Fenster, ohne vsync): Welle mit 3 Gegnern und 2 Spielern im Mittel 5,4 ms, 95 % unter 8,4 ms; 12 Figuren allein kosten rund 2,8 ms.
- Leichte Gegnerbilder (Browser-Leistung, 2026-11-05): `ModelFigure.create(id, true)` für Gegner nutzt 160 statt 256 Pixel, 2-fach statt 4-fach Glättung und rechnet Haltung und Teilbild nur jedes zweite Bild (`update_due`, nach Figur verschoben). Spieler bleiben unverändert. Wirkung im Browser noch nicht gemessen.
- Gemeinsame Bühne für Gegner (2026-11-14, `ModelFigure.Stage`): Alle Gegner stehen in einer einzigen 3D-Welt (ein `SubViewport` mit 4×4 Feldern, 800 px, ohne Glättung) statt je in einem eigenen Teilbild; das ist ein Renderdurchgang für alle. Jede Figur hat ein Feld (`_slot`, `_slot_origin`) und zeichnet mit `draw_texture_rect_region` ihren Ausschnitt. Feldabstand 1,25 × Bildausschnitt, damit Gliedmassen nicht ins Nachbarfeld ragen. Der Treffer-Blitz ist eine weisse `material_overlay` statt helleres Licht (das Licht ist geteilt). Haltung rechnen Gegner nur jedes 2. (ab 6 Figuren jedes 3.) Bild, das Teilbild der Bühne wird dann einmal angefordert (`UPDATE_ONCE`). Spieler haben weiter eigene Teilbilder. Geprüft mit Platzhalter-Modellen unter Mesa/llvmpipe (Felder, Ausblenden, Blitz, Freigeben), Tests stufe2/10/12 grün; `stufe11` meldet schon vorher «Boss» (headless, unabhängig). Im Browser noch nicht gemessen (F2).
- Die Gegner nutzen weiter die `Poses` (noch keine Clips): `current_pose` und die g_-Angriffe sind unverändert.
- Tests: `stufe10_test.gd` (Varianten, Zonen, Umfärben nur am eigenen Modell, Zählung, Bildrand, 2D-Ersatz).

## Stufe 11 (Nachschub, stärkere Gegner, zweites Level) – Aufbau
- Keine Wellen mehr: `WaveDirector` lässt laufend Gegner nachrücken. `budget()` = 3 + Fortschritt × (24 in Level 1, 30 in Level 2; ×1,4 zu zweit) + 1 je 10 s. Es erscheinen höchstens so viele Gegner, wie das Guthaben erlaubt, und höchstens `max_alive()` (3 bis 6, zu zweit +2) gleichzeitig.
  Wer vorankommt, trifft also immer wieder auf neue Gegner, wer wartet, bekommt hin und wieder Besuch. Die Kamera bleibt nie stehen; Anzeigen «WELLE n» und «GO» sind weg, oben steht «LEVEL n».
- Typenmischung nach Fortschritt (Brocken ab 20 % des Wegs, in Level 2 von Anfang an). Am Levelende (Bildrand ab `BOSS_X` = 4440) erscheint der Boss, dazu alle 6–9 s ein weiterer Gegner. Fällt der Boss, geben die übrigen auf (`_end_level`).
- Stärke (`WaveDirector.LEVELS`, beim Erscheinen gesetzt, `Enemy.create` bleibt unverändert): Lebenspunkte ×1,5 (Level 2 ×1,9) und im Level bis ×1,25 mehr, Schaden ×1,3 (×1,5), Angriffspausen ×0,7 (×0,6), Boss in Level 2 ×1,3 Lebenspunkte. Drei Angreifer pro Spieler statt zwei. Das sind Startwerte, die Schwierigkeit prüft am besten der User von Hand.
- Level 2 (`LevelPainter.theme` 2, `Level.level_index`): Chinatown bei Nacht mit Gasse (Lampions, Ladenfronten), Markt (Stände, Lichterkette) und Tempel mit Dojo am Ende, Pagoden in der Ferne, eigener Requisitenplan (`Level.PROP_PLAN_2`). Texturen je Level getrennt gemerkt. Boss «DRACHE» ist das Boss-Modell in anderen Farben (`EnemyLooks` Variante 1).
- Levelwechsel in `Main._on_level_cleared`/`_start_level`: «LEVEL GESCHAFFT!», nach 3 s Start von Level 2 mit Punkten und Leben, vollen Lebenspunkten, ausgeschiedene Spieler steigen wieder ein. Sieg erst nach dem zweiten Boss; `Main.level_count` (Tests setzen 1) bestimmt die Zahl der Level.
- Tests: `stufe11_test.gd` (Nachschub, Stärke, Boss, Levelwechsel, ganzer Bot-Lauf durch beide Level in rund 350 Spielsekunden). Die Bots der Stufen 4 und 7 laufen mit einem Level.

## Stufe 12 (Schläger für alle, Gegner mit Schläger) – Aufbau
- Schläger-Clips für alle: `BAT_CLIP_FIGHTERS` in `tools/blender/fighter_clips.py` (die sieben übrigen Kämpfer und alle sieben Gegnermodelle); `clip_ids(name)` liefert je Figur alle Clips (Bruce), nur `w_bat1`, `w_bat2`, `w_homerun`, `w_block` oder keine. Die anderen Kampf-Clips bleiben bei Bruce, alle übrigen Angriffe bei den `Poses`.
- Die Griffpunkte sind für Bruce gemessen (Arm 0,47 m, Schulter 1,36 m). Andere Figuren greifen im Verhältnis zur Armlänge (nur verkürzend) und Schulterhöhe; reicht ein Arm trotzdem nicht (breite Schultern: JCVD, Bruno, Brocken, Boss), rückt `_fit_grip` den Schläger als Ganzes näher an den Körper. Der Bau prüft weiter, dass beide Hände am Griff liegen (0,0 mm bei allen 15 Modellen; Toleranz 2,5 cm, per `CLIP_REACH_TOL` änderbar). `CLIP_DEBUG=1` zeigt die Körpermasse.
- Gegner mit Schläger: `Enemy` hat den Zustand `FETCH`. Ohne Waffe prüft er alle 0,6–1,2 s `WorldItems.find_weapon_for_enemy`: ein Schläger im Bild, höchstens 300 px weit und 90 px tief, und kein lebender Spieler liegt näher dran (Spieler gehen vor). Er läuft hin (mit `_detour` um Hindernisse), hebt ihn per `request_grab` auf und gibt nach 3,5 s auf. Gegner heben nur Waffen auf, keine Kisten (`Fighter.weapons_only`).
- Bewaffnet wählt er nur `w_bat1` (3) und `w_homerun` (1), die Kette `w_bat1` → `w_bat2` läuft wie beim Combo-Wurf der Gegner, und er schlägt aus 62 px (statt 44–58 px) zu. Schaden und Pausen kommen wie bei allen Gegnern aus den Faktoren des Levels. Treffer nutzen den Schläger ab, am Ende «KAPUTT!»; fällt der Gegner, bleibt der Schläger blinkend liegen (wie bei Spielern).
- Tests: `stufe12_test.gd` (Holen, Spieler gehen vor, keine Kisten, Schläger-Angriffe und Reichweite, Treffer und Abnutzung, Fallenlassen, Schläger-Clips in allen 15 Modellen samt Faust nach vorn). Von Hand zu prüfen: wie der Schwung der anderen Figuren aussieht, und wie oft Gegner den Schläger holen (Balance).
- Vorschau: `... -- --fighter mika --clip-preview w_bat2` (geht jetzt für jede Figur mit Schläger-Clips).

## Online-Koop (später, eigener Konzeptvorschlag nötig)
- Node.js-WebSocket-Relay auf Fly.io; Räume mit Code; Godot `WebSocketMultiplayerPeer` + `@rpc`.
- Host-autoritativ: ein Client simuliert die Welt, der andere sendet Eingaben; Client-Prediction nur für die eigene Figur, getrennt vom Spielzustand.
- Offene Fragen: Latenz-Toleranz, Wiederverbinden, Spielerzahl (nur 2?).

## Nächste Schritte
- Nächste Waffen (Wunsch des Users, 2026-11-08): Wurfsterne und Nunchakus. Vor dem Bauen Konzept als Liste (Modelle, Clips, Greifen, Haltbarkeit, Gegner, Balance).
- Browser-Prüfung der Online-Fassung mit den Modellen (nach dem ersten Lauf des Workflows `Online stellen`).
- Balance der acht Figuren messen, Werte von Bruce, Chuck, Jackie, JCVD mit dem User abstimmen.
- Gegner-Konzept, Schritt 2 und 3: Stilpakete (Raufer, Treter, Schwergewicht, Stecher, Karateka, Akrobat) für Gegner und Kämpfer, dann die vier neuen Typen Messerkerl, Wächter, Werfer, Springer, Bosswutstufen und Elite-Gegner. Danach Clips (auch Schläger) für die übrigen sieben Kämpfer.
- Bildrate der Online-Fassung mit Gegnern im sichtbaren Browserfenster ansehen (F2).
- Eigene Spezialangriffe und Combos je Figur (Pygame-Konzept, Abschnitt 9); Porträts als 3D.
