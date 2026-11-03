class_name Skins
extends RefCounted
## Aussehen aller Figuren (Port von `skins.py`). Gezeichnet wird in `FigureArt`, hier stehen nur die Daten.
##   skin, hair, top, pants, shoes, belt   Farben
##   hairstyle  &"short", &"ponytail", &"mohawk", &"bald", &"spikes"
##   sleeves    Oberarme in der Farbe des Oberteils (Jacke) statt Haut
##   top        null = nackter Oberkörper (dann ist vest die Farbe der Weste)
##   band       Farbe des Stirnbands oder null; die Bänder zeigen die Blickrichtung
##   build      Faktor für die Dicke von Armen, Beinen und Rumpf
##   extras     &"beard", &"glasses", &"chain", &"gloves"

const KAI := {
	"name": "KAI", "skin": Color8(238, 196, 156), "hair": Color8(52, 36, 26), "hairstyle": &"short",
	"top": Color8(40, 105, 225), "sleeves": false, "pants": Color8(28, 44, 108), "shoes": Color8(235, 235, 240),
	"belt": Color8(18, 18, 28), "band": Color8(110, 200, 255), "build": 1.0, "extras": [&"gloves"],
	"gloves": Color8(90, 175, 255),
}
const RIA := {
	"name": "RIA", "skin": Color8(244, 204, 170), "hair": Color8(235, 175, 55), "hairstyle": &"ponytail",
	"top": Color8(215, 45, 50), "sleeves": false, "pants": Color8(105, 22, 30), "shoes": Color8(240, 230, 225),
	"belt": Color8(30, 16, 18), "band": Color8(255, 150, 110), "build": 0.95, "extras": [&"gloves"],
	"gloves": Color8(255, 110, 100),
}
const THUG := {
	"name": "SCHLÄGER", "skin": Color8(205, 152, 112), "hair": Color8(25, 22, 20), "hairstyle": &"short",
	"top": Color8(55, 140, 65), "sleeves": true, "pants": Color8(46, 58, 44), "shoes": Color8(40, 30, 25),
	"belt": Color8(25, 25, 20), "band": null, "build": 1.0, "extras": [],
}
const DASHER := {
	"name": "FLITZER", "skin": Color8(226, 178, 140), "hair": Color8(80, 235, 110), "hairstyle": &"mohawk",
	"top": Color8(130, 225, 120), "sleeves": false, "pants": Color8(30, 95, 62), "shoes": Color8(240, 240, 60),
	"belt": Color8(20, 60, 30), "band": null, "build": 0.9, "extras": [],
}
const BRUTE := {
	"name": "BROCKEN", "skin": Color8(180, 128, 92), "hair": Color8(30, 22, 18), "hairstyle": &"bald",
	"top": null, "vest": Color8(26, 92, 44), "sleeves": false, "pants": Color8(34, 48, 36), "shoes": Color8(30, 26, 22),
	"belt": Color8(70, 50, 20), "band": null, "build": 1.35, "extras": [&"beard"],
}
const BOSS := {
	"name": "BOSS GRANIT", "skin": Color8(196, 142, 104), "hair": Color8(20, 20, 24), "hairstyle": &"spikes",
	"top": Color8(16, 74, 40), "sleeves": true, "pants": Color8(18, 30, 24), "shoes": Color8(15, 15, 15),
	"belt": Color8(220, 185, 60), "band": null, "build": 1.25, "extras": [&"glasses", &"chain"],
}
