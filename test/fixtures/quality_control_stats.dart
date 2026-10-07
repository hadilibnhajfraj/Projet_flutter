// Réponse RÉELLE de GET /quality-control/stats?period=all (champ data), compte
// controle_qualite, capturée le 01/10/2026 — sert à vérifier le parsing Flutter.

const kQualityControlStatsAll = r'''
{
  "period": "all",
  "from": null,
  "totals": {
    "total": 3,
    "conforme": 0,
    "nonConforme": 1,
    "aVerifier": 2,
    "machines": 8,
    "machinesActives": 2
  },
  "lines": [
    {
      "type": "PROMESH",
      "label": "PROMESH",
      "total": 3,
      "conforme": 0,
      "nonConforme": 1,
      "aVerifier": 2,
      "machines": [
        {
          "machine": "1",
          "label": "Machine 1",
          "total": 1,
          "conforme": 0,
          "nonConforme": 0,
          "aVerifier": 1,
          "lastControl": {
            "id": "729e3f35-f525-457e-8d5c-e7386ddc96a1",
            "status": "EN_ATTENTE",
            "ficheNumero": "PROMESH-2026-000886",
            "controlDate": "30/09/2026",
            "controlTime": "17:52"
          }
        },
        {
          "machine": "2",
          "label": "Machine 2",
          "total": 2,
          "conforme": 0,
          "nonConforme": 1,
          "aVerifier": 1,
          "lastControl": {
            "id": "35bc2b5b-047b-45ff-bf1a-a86acd7f2663",
            "status": "EN_ATTENTE",
            "ficheNumero": "PROMESH-2026-000887",
            "controlDate": "30/09/2026",
            "controlTime": "17:20"
          }
        },
        {
          "machine": "3",
          "label": "Machine 3",
          "total": 0,
          "conforme": 0,
          "nonConforme": 0,
          "aVerifier": 0,
          "lastControl": null
        },
        {
          "machine": "4",
          "label": "Machine 4",
          "total": 0,
          "conforme": 0,
          "nonConforme": 0,
          "aVerifier": 0,
          "lastControl": null
        }
      ]
    },
    {
      "type": "PROBAR",
      "label": "PROBAR",
      "total": 0,
      "conforme": 0,
      "nonConforme": 0,
      "aVerifier": 0,
      "machines": [
        {
          "machine": "1",
          "label": "Machine 1",
          "total": 0,
          "conforme": 0,
          "nonConforme": 0,
          "aVerifier": 0,
          "lastControl": null
        },
        {
          "machine": "2",
          "label": "Machine 2",
          "total": 0,
          "conforme": 0,
          "nonConforme": 0,
          "aVerifier": 0,
          "lastControl": null
        },
        {
          "machine": "3",
          "label": "Machine 3",
          "total": 0,
          "conforme": 0,
          "nonConforme": 0,
          "aVerifier": 0,
          "lastControl": null
        },
        {
          "machine": "4",
          "label": "Machine 4",
          "total": 0,
          "conforme": 0,
          "nonConforme": 0,
          "aVerifier": 0,
          "lastControl": null
        }
      ]
    }
  ]
}
''';
