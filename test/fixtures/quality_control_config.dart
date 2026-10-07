// GET /quality-control/config — réponse RÉELLE du backend (config/qualityControl.js).
const String kQualityControlConfig = r'''{
  "parameters": [
    {
      "key": "niveau_bain_graines",
      "label": "NIVEAU BAIN DE GRAINES",
      "position": 1,
      "autoTime": false,
      "scope": "reading",
      "lines": [
        "PROMESH"
      ],
      "byLine": {
        "PROMESH": {
          "section": "controle_machine",
          "order": 7,
          "label": "NIVEAU BAIN DE GRAINES"
        }
      },
      "withStatus": false,
      "section": "ligne",
      "group": null,
      "shortLabel": null,
      "kind": "choice",
      "unit": null,
      "hint": null,
      "options": [
        {
          "value": "Bien",
          "label": "Bien",
          "tone": "ok"
        },
        {
          "value": "Moyen",
          "label": "Moyen",
          "tone": "warn"
        },
        {
          "value": "Mauvais",
          "label": "Mauvais",
          "tone": "nok"
        }
      ]
    },
    {
      "key": "variateur_frequence_tirage",
      "label": "VARIATEUR EN FRÉQUENCE DE TIRAGE",
      "position": 3,
      "autoTime": false,
      "scope": "reading",
      "lines": [
        "PROBAR"
      ],
      "byLine": {},
      "withStatus": false,
      "section": "ligne",
      "group": null,
      "shortLabel": null,
      "kind": "number",
      "unit": null,
      "hint": null,
      "options": []
    },
    {
      "key": "variateur_frequence_bobinage",
      "label": "VARIATEUR EN FRÉQUENCE DE BOBINAGE",
      "position": 4,
      "autoTime": false,
      "scope": "reading",
      "lines": [
        "PROBAR"
      ],
      "byLine": {},
      "withStatus": false,
      "section": "ligne",
      "group": null,
      "shortLabel": null,
      "kind": "number",
      "unit": null,
      "hint": null,
      "options": []
    },
    {
      "key": "vitesse_barre",
      "label": "VITESSE DE BARRE (m/min)",
      "position": 5,
      "autoTime": false,
      "scope": "reading",
      "lines": [
        "PROBAR"
      ],
      "byLine": {},
      "withStatus": false,
      "section": "ligne",
      "group": null,
      "shortLabel": null,
      "kind": "number",
      "unit": null,
      "hint": null,
      "options": []
    },
    {
      "key": "nombre_bobines",
      "label": "NOMBRE DE BOBINES",
      "position": 10,
      "autoTime": false,
      "scope": "reading",
      "lines": [
        "PROBAR"
      ],
      "byLine": {},
      "withStatus": false,
      "section": "ligne",
      "group": null,
      "shortLabel": null,
      "kind": "number",
      "unit": null,
      "hint": null,
      "options": []
    },
    {
      "key": "alignement_fibres",
      "label": "ALIGNEMENT DES FIBRES",
      "position": 12,
      "autoTime": false,
      "scope": "reading",
      "lines": [
        "PROBAR"
      ],
      "byLine": {},
      "withStatus": false,
      "section": "ligne",
      "group": null,
      "shortLabel": null,
      "kind": "choice",
      "unit": null,
      "hint": null,
      "options": [
        {
          "value": "Conforme",
          "label": "Conforme",
          "tone": "ok"
        },
        {
          "value": "Non conforme",
          "label": "Non conforme",
          "tone": "nok"
        }
      ]
    },
    {
      "key": "temperature_zone_1",
      "label": "TEMPÉRATURE ZONE 1",
      "position": 13,
      "autoTime": false,
      "scope": "reading",
      "lines": [
        "PROBAR"
      ],
      "byLine": {},
      "withStatus": false,
      "section": "chauffage",
      "group": null,
      "shortLabel": null,
      "kind": "number",
      "unit": "°C",
      "hint": null,
      "options": []
    },
    {
      "key": "temperature_zone_2",
      "label": "TEMPÉRATURE ZONE 2",
      "position": 14,
      "autoTime": false,
      "scope": "reading",
      "lines": [
        "PROBAR"
      ],
      "byLine": {},
      "withStatus": false,
      "section": "chauffage",
      "group": null,
      "shortLabel": null,
      "kind": "number",
      "unit": "°C",
      "hint": null,
      "options": []
    },
    {
      "key": "temperature_zone_3",
      "label": "TEMPÉRATURE ZONE 3",
      "position": 15,
      "autoTime": false,
      "scope": "reading",
      "lines": [
        "PROBAR"
      ],
      "byLine": {},
      "withStatus": false,
      "section": "chauffage",
      "group": null,
      "shortLabel": null,
      "kind": "number",
      "unit": "°C",
      "hint": null,
      "options": []
    },
    {
      "key": "pression_air",
      "label": "PRESSION D'AIR",
      "position": 16,
      "autoTime": false,
      "scope": "reading",
      "lines": [
        "PROBAR"
      ],
      "byLine": {},
      "withStatus": false,
      "section": "chauffage",
      "group": null,
      "shortLabel": null,
      "kind": "number",
      "unit": null,
      "hint": null,
      "options": []
    },
    {
      "key": "viscosite_resine",
      "label": "VISCOSITÉ DE LA RÉSINE",
      "position": 20,
      "autoTime": false,
      "scope": "reading",
      "lines": [
        "PROBAR"
      ],
      "byLine": {},
      "withStatus": false,
      "section": "chauffage",
      "group": null,
      "shortLabel": null,
      "kind": "number",
      "unit": null,
      "hint": null,
      "options": []
    },
    {
      "key": "ratio_resine_durcisseur_catalyseur",
      "label": "RATIO RÉSINE / DURCISSEUR / CATALYSEUR",
      "position": 21,
      "autoTime": false,
      "scope": "reading",
      "lines": [
        "PROBAR"
      ],
      "byLine": {},
      "withStatus": false,
      "section": "chauffage",
      "group": null,
      "shortLabel": null,
      "kind": "conformity",
      "unit": null,
      "hint": null,
      "options": []
    },
    {
      "key": "temperature_machine",
      "label": "TEMPÉRATURE DE MACHINE",
      "position": 32,
      "autoTime": false,
      "scope": "reading",
      "lines": [
        "PROMESH"
      ],
      "byLine": {
        "PROMESH": {
          "section": "controle_machine",
          "order": 1,
          "label": "TEMPÉRATURE DE MACHINE"
        }
      },
      "withStatus": false,
      "section": "machine",
      "group": null,
      "shortLabel": null,
      "kind": "number",
      "unit": "°C",
      "hint": null,
      "options": []
    },
    {
      "key": "temperature_eau",
      "label": "TEMPÉRATURE D'EAU",
      "position": 33,
      "autoTime": false,
      "scope": "reading",
      "lines": [
        "PROMESH",
        "PROBAR",
        "PROMESH:4"
      ],
      "byLine": {
        "PROMESH": {
          "section": "controle_machine",
          "order": 2,
          "label": "TEMPÉRATURE D'EAU"
        },
        "PROMESH:4": {
          "section": "controle_promesh_4",
          "order": 5,
          "label": "TEMPÉRATURE D'EAU"
        }
      },
      "withStatus": false,
      "section": "machine",
      "group": null,
      "shortLabel": null,
      "kind": "number",
      "unit": "°C",
      "hint": null,
      "options": []
    },
    {
      "key": "pression_air_comprime",
      "label": "PRESSION D'AIR COMPRIMÉ",
      "position": 34,
      "autoTime": false,
      "scope": "reading",
      "lines": [
        "PROMESH"
      ],
      "byLine": {
        "PROMESH": {
          "section": "controle_machine",
          "order": 3,
          "label": "PRESSION D'AIR COMPRIMÉ"
        }
      },
      "withStatus": false,
      "section": "machine",
      "group": null,
      "shortLabel": null,
      "kind": "number",
      "unit": "bar",
      "hint": null,
      "options": []
    },
    {
      "key": "fuite_air_comprime",
      "label": "FUITE D'AIR COMPRIMÉ",
      "position": 35,
      "autoTime": false,
      "scope": "reading",
      "lines": [
        "PROMESH",
        "PROBAR"
      ],
      "byLine": {
        "PROMESH": {
          "section": "controle_machine",
          "order": 5,
          "label": "FUITE D'AIR COMPRIMÉ"
        }
      },
      "withStatus": false,
      "section": "machine",
      "group": null,
      "shortLabel": null,
      "kind": "choice",
      "unit": null,
      "hint": null,
      "options": [
        {
          "value": "Absent",
          "label": "Absent",
          "tone": "ok"
        },
        {
          "value": "Présent",
          "label": "Présent",
          "tone": "nok"
        }
      ]
    },
    {
      "key": "fuite_eau",
      "label": "FUITE D'EAU",
      "position": 36,
      "autoTime": false,
      "scope": "reading",
      "lines": [
        "PROMESH",
        "PROBAR"
      ],
      "byLine": {
        "PROMESH": {
          "section": "controle_machine",
          "order": 4,
          "label": "FUITE D'EAU"
        }
      },
      "withStatus": false,
      "section": "machine",
      "group": null,
      "shortLabel": null,
      "kind": "choice",
      "unit": null,
      "hint": null,
      "options": [
        {
          "value": "Absent",
          "label": "Absent",
          "tone": "ok"
        },
        {
          "value": "Présent",
          "label": "Présent",
          "tone": "nok"
        }
      ]
    },
    {
      "key": "etat_disque_coupe",
      "label": "ÉTAT DU DISQUE DE COUPE",
      "position": 37,
      "autoTime": false,
      "scope": "reading",
      "lines": [
        "PROMESH",
        "PROBAR"
      ],
      "byLine": {
        "PROMESH": {
          "section": "controle_machine",
          "order": 6,
          "label": "ÉTAT DISQUE DE COUPE"
        }
      },
      "withStatus": false,
      "section": "machine",
      "group": null,
      "shortLabel": null,
      "kind": "choice",
      "unit": null,
      "hint": null,
      "options": [
        {
          "value": "OK",
          "label": "OK",
          "tone": "ok"
        },
        {
          "value": "NOK",
          "label": "NOK",
          "tone": "nok"
        }
      ]
    },
    {
      "key": "nombre_bar_longueur",
      "label": "NOMBRE DE BARRES EN LONGUEUR",
      "position": 38,
      "autoTime": false,
      "scope": "fiche",
      "lines": [
        "PROMESH",
        "PROMESH:4"
      ],
      "byLine": {
        "PROMESH": {
          "section": "physique",
          "order": 2,
          "label": "NOMBRE DE BARRES EN LONGUEUR"
        },
        "PROMESH:4": {
          "section": "physique",
          "order": 3,
          "label": "NOMBRE DE BARRES EN LONGUEUR"
        }
      },
      "withStatus": false,
      "section": "physique",
      "group": null,
      "shortLabel": null,
      "kind": "number",
      "unit": null,
      "hint": null,
      "options": []
    },
    {
      "key": "nombre_bar_largeur",
      "label": "NOMBRE DE BARRES EN LARGEUR",
      "position": 39,
      "autoTime": false,
      "scope": "fiche",
      "lines": [
        "PROMESH",
        "PROMESH:4"
      ],
      "byLine": {
        "PROMESH": {
          "section": "physique",
          "order": 3,
          "label": "NOMBRE DE BARRES EN LARGEUR"
        },
        "PROMESH:4": {
          "section": "physique",
          "order": 5,
          "label": "NOMBRE DE BARRES EN LARGEUR"
        }
      },
      "withStatus": false,
      "section": "physique",
      "group": null,
      "shortLabel": null,
      "kind": "number",
      "unit": null,
      "hint": null,
      "options": []
    },
    {
      "key": "dimensions_maille",
      "label": "DIMENSIONS DE MAILLE",
      "position": 40,
      "autoTime": false,
      "scope": "fiche",
      "lines": [
        "PROMESH",
        "PROMESH:4"
      ],
      "byLine": {
        "PROMESH": {
          "section": "physique",
          "order": 4,
          "label": "DIMENSIONS DE MAILLE"
        },
        "PROMESH:4": {
          "section": "physique",
          "order": 4,
          "label": "DIMENSIONS DE MAILLE"
        }
      },
      "withStatus": false,
      "section": "physique",
      "group": null,
      "shortLabel": null,
      "kind": "text",
      "unit": null,
      "hint": "ex. 20 × 20 mm",
      "options": []
    },
    {
      "key": "dimensions_cote_1_long",
      "label": "DIMENSIONS CÔTÉ 1 LONG",
      "position": 41,
      "autoTime": false,
      "scope": "fiche",
      "lines": [
        "PROMESH",
        "PROMESH:4"
      ],
      "byLine": {
        "PROMESH": {
          "section": "physique",
          "order": 5,
          "label": "DIMENSIONS CÔTÉ 1 LONG"
        },
        "PROMESH:4": {
          "section": "physique",
          "order": 2,
          "label": "DIMENSIONS CÔTÉ 1 LONGUEUR"
        }
      },
      "withStatus": false,
      "section": "physique",
      "group": null,
      "shortLabel": null,
      "kind": "number",
      "unit": "mm",
      "hint": null,
      "options": []
    },
    {
      "key": "dimensions_cote_2_long",
      "label": "DIMENSIONS CÔTÉ 2 LONG",
      "position": 42,
      "autoTime": false,
      "scope": "fiche",
      "lines": [
        "PROMESH",
        "PROMESH:4"
      ],
      "byLine": {
        "PROMESH": {
          "section": "physique",
          "order": 6,
          "label": "DIMENSIONS CÔTÉ 2 LONG"
        },
        "PROMESH:4": {
          "section": "physique",
          "order": 6,
          "label": "DIMENSIONS CÔTÉ 2 LONGUEUR"
        }
      },
      "withStatus": false,
      "section": "physique",
      "group": null,
      "shortLabel": null,
      "kind": "number",
      "unit": "mm",
      "hint": null,
      "options": []
    },
    {
      "key": "etat_impression",
      "label": "ÉTAT D'IMPRESSION",
      "position": 43,
      "autoTime": false,
      "scope": "fiche",
      "lines": [
        "PROMESH"
      ],
      "byLine": {
        "PROMESH": {
          "section": "physique",
          "order": 7,
          "label": "ÉTAT D'IMPRESSION"
        }
      },
      "withStatus": false,
      "section": "physique",
      "group": null,
      "shortLabel": null,
      "kind": "choice",
      "unit": null,
      "hint": null,
      "options": [
        {
          "value": "Conforme",
          "label": "Conforme",
          "tone": "ok"
        },
        {
          "value": "Non conforme",
          "label": "Non conforme",
          "tone": "nok"
        }
      ]
    },
    {
      "key": "vitesse_impression",
      "label": "VITESSE D'IMPRESSION",
      "position": 44,
      "autoTime": false,
      "scope": "reading",
      "lines": [
        "PROMESH"
      ],
      "byLine": {
        "PROMESH": {
          "section": "controle_machine",
          "order": 8,
          "label": "VITESSE D'IMPRESSION"
        }
      },
      "withStatus": false,
      "section": "machine",
      "group": null,
      "shortLabel": null,
      "kind": "number",
      "unit": null,
      "hint": null,
      "options": []
    },
    {
      "key": "phys_diametre_nominal",
      "label": "DIAMÈTRE NOMINAL",
      "position": 45,
      "autoTime": false,
      "scope": "fiche",
      "lines": [
        "PROBAR"
      ],
      "byLine": {},
      "withStatus": false,
      "section": "physique",
      "group": null,
      "shortLabel": null,
      "kind": "text",
      "unit": null,
      "hint": null,
      "options": []
    },
    {
      "key": "phys_diametre_reel",
      "label": "DIAMÈTRE RÉEL",
      "position": 46,
      "autoTime": false,
      "scope": "fiche",
      "lines": [
        "PROBAR"
      ],
      "byLine": {},
      "withStatus": false,
      "section": "physique",
      "group": null,
      "shortLabel": null,
      "kind": "text",
      "unit": null,
      "hint": null,
      "options": []
    },
    {
      "key": "phys_section_transversale",
      "label": "SECTION TRANSVERSALE",
      "position": 47,
      "autoTime": false,
      "scope": "fiche",
      "lines": [
        "PROBAR"
      ],
      "byLine": {},
      "withStatus": false,
      "section": "physique",
      "group": null,
      "shortLabel": null,
      "kind": "text",
      "unit": null,
      "hint": null,
      "options": []
    },
    {
      "key": "phys_longueur",
      "label": "LONGUEUR",
      "position": 49,
      "autoTime": false,
      "scope": "fiche",
      "lines": [
        "PROBAR"
      ],
      "byLine": {},
      "withStatus": false,
      "section": "physique",
      "group": null,
      "shortLabel": null,
      "kind": "text",
      "unit": null,
      "hint": null,
      "options": []
    },
    {
      "key": "phys_masse_lineique",
      "label": "POIDS EN g",
      "position": 50,
      "autoTime": false,
      "scope": "fiche",
      "lines": [
        "PROBAR"
      ],
      "byLine": {},
      "withStatus": false,
      "section": "physique",
      "group": null,
      "shortLabel": null,
      "kind": "text",
      "unit": null,
      "hint": null,
      "options": []
    },
    {
      "key": "phys_defauts_superficiels_controle",
      "label": "DÉFAUTS SUPERFICIELS",
      "position": 60,
      "autoTime": false,
      "scope": "fiche",
      "lines": [
        "PROBAR"
      ],
      "byLine": {},
      "withStatus": false,
      "section": "physique",
      "group": null,
      "shortLabel": null,
      "kind": "choice",
      "unit": null,
      "hint": null,
      "options": [
        {
          "value": "OK",
          "label": "OK",
          "tone": "ok"
        },
        {
          "value": "NOK",
          "label": "NOK",
          "tone": "nok"
        }
      ]
    },
    {
      "key": "phys_qualite_coupe",
      "label": "QUALITÉ DE COUPE",
      "position": 61,
      "autoTime": false,
      "scope": "fiche",
      "lines": [
        "PROBAR"
      ],
      "byLine": {},
      "withStatus": false,
      "section": "physique",
      "group": null,
      "shortLabel": null,
      "kind": "choice",
      "unit": null,
      "hint": null,
      "options": [
        {
          "value": "BON",
          "label": "Bon",
          "tone": "ok"
        },
        {
          "value": "PAS_BON",
          "label": "Pas bon",
          "tone": "nok"
        }
      ]
    },
    {
      "key": "promesh4_nombre_bobines",
      "label": "NOMBRE DE BOBINES",
      "position": 85,
      "autoTime": false,
      "scope": "reading",
      "lines": [
        "PROMESH:4"
      ],
      "byLine": {
        "PROMESH:4": {
          "section": "controle_promesh_4",
          "order": 6,
          "label": "NOMBRE DE BOBINES"
        }
      },
      "withStatus": false,
      "section": "controle_promesh_4",
      "group": null,
      "shortLabel": null,
      "kind": "number",
      "unit": null,
      "hint": null,
      "options": []
    },
    {
      "key": "promesh4_vitesse_tirage",
      "label": "VITESSE DE TIRAGE",
      "position": 86,
      "autoTime": false,
      "scope": "reading",
      "lines": [
        "PROMESH:4"
      ],
      "byLine": {
        "PROMESH:4": {
          "section": "controle_promesh_4",
          "order": 7,
          "label": "VITESSE DE TIRAGE"
        }
      },
      "withStatus": false,
      "section": "controle_promesh_4",
      "group": null,
      "shortLabel": null,
      "kind": "number",
      "unit": null,
      "hint": null,
      "options": []
    },
    {
      "key": "promesh4_viscosite_bain_1",
      "label": "VISCOSITÉ DE LA RÉSINE — BAIN 1",
      "position": 87,
      "autoTime": false,
      "scope": "reading",
      "lines": [
        "PROMESH:4"
      ],
      "byLine": {
        "PROMESH:4": {
          "section": "controle_promesh_4",
          "order": 8,
          "label": "VISCOSITÉ DE LA RÉSINE — BAIN 1"
        }
      },
      "withStatus": false,
      "section": "controle_promesh_4",
      "group": "VISCOSITÉ DE LA RÉSINE",
      "shortLabel": "BAIN 1",
      "kind": "number",
      "unit": "°",
      "hint": null,
      "options": []
    },
    {
      "key": "promesh4_viscosite_bain_2",
      "label": "VISCOSITÉ DE LA RÉSINE — BAIN 2",
      "position": 88,
      "autoTime": false,
      "scope": "reading",
      "lines": [
        "PROMESH:4"
      ],
      "byLine": {
        "PROMESH:4": {
          "section": "controle_promesh_4",
          "order": 9,
          "label": "VISCOSITÉ DE LA RÉSINE — BAIN 2"
        }
      },
      "withStatus": false,
      "section": "controle_promesh_4",
      "group": "VISCOSITÉ DE LA RÉSINE",
      "shortLabel": "BAIN 2",
      "kind": "number",
      "unit": "°",
      "hint": null,
      "options": []
    },
    {
      "key": "promesh4_temperature_machine_1_zone_1",
      "label": "TEMPÉRATURE MACHINE 1 — ZONE 1",
      "position": 89,
      "autoTime": false,
      "scope": "reading",
      "lines": [
        "PROMESH:4"
      ],
      "byLine": {
        "PROMESH:4": {
          "section": "controle_promesh_4",
          "order": 1,
          "label": "TEMPÉRATURE MACHINE 1 — ZONE 1"
        }
      },
      "withStatus": false,
      "section": "controle_promesh_4",
      "group": "TEMPÉRATURE MACHINE 1",
      "shortLabel": "ZONE 1",
      "kind": "number",
      "unit": "°C",
      "hint": null,
      "options": []
    },
    {
      "key": "promesh4_temperature_machine_1_zone_2",
      "label": "TEMPÉRATURE MACHINE 1 — ZONE 2",
      "position": 90,
      "autoTime": false,
      "scope": "reading",
      "lines": [
        "PROMESH:4"
      ],
      "byLine": {
        "PROMESH:4": {
          "section": "controle_promesh_4",
          "order": 2,
          "label": "TEMPÉRATURE MACHINE 1 — ZONE 2"
        }
      },
      "withStatus": false,
      "section": "controle_promesh_4",
      "group": "TEMPÉRATURE MACHINE 1",
      "shortLabel": "ZONE 2",
      "kind": "number",
      "unit": "°C",
      "hint": null,
      "options": []
    },
    {
      "key": "promesh4_temperature_machine_2_zone_1",
      "label": "TEMPÉRATURE MACHINE 2 — ZONE 1",
      "position": 91,
      "autoTime": false,
      "scope": "reading",
      "lines": [
        "PROMESH:4"
      ],
      "byLine": {
        "PROMESH:4": {
          "section": "controle_promesh_4",
          "order": 3,
          "label": "TEMPÉRATURE MACHINE 2 — ZONE 1"
        }
      },
      "withStatus": false,
      "section": "controle_promesh_4",
      "group": "TEMPÉRATURE MACHINE 2",
      "shortLabel": "ZONE 1",
      "kind": "number",
      "unit": "°C",
      "hint": null,
      "options": []
    },
    {
      "key": "promesh4_temperature_machine_2_zone_2",
      "label": "TEMPÉRATURE MACHINE 2 — ZONE 2",
      "position": 92,
      "autoTime": false,
      "scope": "reading",
      "lines": [
        "PROMESH:4"
      ],
      "byLine": {
        "PROMESH:4": {
          "section": "controle_promesh_4",
          "order": 4,
          "label": "TEMPÉRATURE MACHINE 2 — ZONE 2"
        }
      },
      "withStatus": false,
      "section": "controle_promesh_4",
      "group": "TEMPÉRATURE MACHINE 2",
      "shortLabel": "ZONE 2",
      "kind": "number",
      "unit": "°C",
      "hint": null,
      "options": []
    },
    {
      "key": "promesh_diametre_reel",
      "label": "DIAMÈTRE RÉEL",
      "position": 93,
      "autoTime": false,
      "scope": "fiche",
      "lines": [
        "PROMESH",
        "PROMESH:4"
      ],
      "byLine": {
        "PROMESH": {
          "section": "physique",
          "order": 1,
          "label": "DIAMÈTRE RÉEL"
        },
        "PROMESH:4": {
          "section": "physique",
          "order": 1,
          "label": "DIAMÈTRE RÉEL"
        }
      },
      "withStatus": false,
      "section": "physique",
      "group": null,
      "shortLabel": null,
      "kind": "text",
      "unit": null,
      "hint": null,
      "options": []
    }
  ],
  "sections": [
    {
      "key": "controle_machine",
      "label": "Contrôle Machine"
    },
    {
      "key": "controle_promesh_4",
      "label": "Contrôle Machine"
    },
    {
      "key": "ligne",
      "label": "Paramètres de ligne"
    },
    {
      "key": "chauffage",
      "label": "Chauffage / imprégnation"
    },
    {
      "key": "machine",
      "label": "Machine"
    },
    {
      "key": "physique",
      "label": "Contrôle produit",
      "scope": "fiche",
      "group": "physique"
    }
  ],
  "productionLines": [
    {
      "type": "PROMESH",
      "label": "PROMESH",
      "machines": [
        "1",
        "2",
        "3",
        "4"
      ]
    },
    {
      "type": "PROBAR",
      "label": "PROBAR",
      "machines": [
        "1",
        "2",
        "3",
        "4"
      ]
    }
  ],
  "machineLines": [
    {
      "type": "PROMESH",
      "machine": "4",
      "key": "PROMESH:4"
    }
  ],
  "readingIntervalMinutes": 180,
  "statuses": [
    "EN_ATTENTE",
    "EN_COURS",
    "CONFORME",
    "NON_CONFORME"
  ],
  "itemStatuses": [
    "CONFORME",
    "NON_CONFORME",
    "NON_CONTROLE"
  ]
}''';
