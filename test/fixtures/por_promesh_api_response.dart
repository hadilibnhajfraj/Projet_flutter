// Vraie réponse de GET /por-promesh/:id (sortie du DTO backend), noms anonymisés.
// Constante Dart (et non un fichier lu via dart:io) : les tests tournent dans Chrome.
const String kPorPromeshApiResponse = r'''{
  "id": "43dc7b36-3d76-48a5-a3b4-bba727dffcc5",
  "sequenceNumber": 886,
  "numero": "PROMESH-2026-000886",
  "status": "VALIDE",
  "isLocked": true,
  "validatedAt": "2026-09-29T13:29:10.650Z",
  "dateProduction": "2026-09-28",
  "heureDebut": "00:24:00",
  "heureFin": "11:23:29",
  "operateur": "Personne 9",
  "machine": "1",
  "poste": "matin",
  "diametreMaille1": "",
  "diametreMaille2": "",
  "diametreMaille3": "",
  "productionM2": "1250.00",
  "demarrageProductionHeure1": null,
  "demarrageProductionQuantite1": null,
  "demarrageProductionHeure2": null,
  "demarrageProductionQuantite2": null,
  "responsable1": "Personne 1",
  "responsable2": "",
  "operateur1": "",
  "operateur2": "",
  "aideOperateur": "",
  "manoeuvre": "",
  "stagiaire1": "",
  "stagiaire2": "",
  "personnelActif": {
    "responsable1": "Personne 1",
    "responsable2": "",
    "operateur1": "",
    "operateur2": "",
    "aideOperateur": "",
    "manoeuvre": "",
    "stagiaire1": "",
    "stagiaire2": ""
  },
  "observationPersonnel": "",
  "heureFinTravail": null,
  "observationFinTravail": "",
  "totalMainOeuvre": null,
  "totalChuteBarres": null,
  "totalDechetGraine": null,
  "visaProduction": "",
  "visaControleQualite": "",
  "visaDirection": "",
  "air": "> 6 bars",
  "niveauBainEau": "Bien",
  "temperatureEau": "45.00",
  "temperaturePistons": 125,
  "etatPistons": "Propre",
  "fluideVisuel": "Absence",
  "etatDisqueCoupe": "OK",
  "observationsGenerales": "ok",
  "justificationControleProcess": "",
  "justificationControleMachine": "",
  "visaResponsableLogistiqueProcess": "",
  "visaControleQualiteProcess": "",
  "visaProductionProcess": "",
  "dateValidationProcess": null,
  "conformite": "conforme",
  "descriptionNonConformite": null,
  "photoNonConformite": null,
  "actionsCorrectives": null,
  "createdBy": "b4a9bf6f-65f1-4dd7-9a38-bb7a07210641",
  "creator": {
    "id": "b4a9bf6f-65f1-4dd7-9a38-bb7a07210641",
    "email": "production_1@example.com",
    "role": "responsable_logistique_achat"
  },
  "controlesQualite": [
    {
      "id": "ed253efd-c185-4fd8-89f4-96606e661f42",
      "heure": "06:00",
      "numeroPlaque": "",
      "maille": "",
      "longueur": null,
      "largeur": null,
      "statutCOQ": null
    },
    {
      "id": "b7c6277b-2f82-4683-8701-4b01623792e4",
      "heure": "09:00",
      "numeroPlaque": "",
      "maille": "",
      "longueur": null,
      "largeur": null,
      "statutCOQ": null
    },
    {
      "id": "ffe895a7-2721-4070-8376-85d34af43fab",
      "heure": "12:00",
      "numeroPlaque": "",
      "maille": "",
      "longueur": null,
      "largeur": null,
      "statutCOQ": null
    },
    {
      "id": "5b5a3b6f-51e7-45a1-bfce-83c44a4c4f41",
      "heure": "15:00",
      "numeroPlaque": "",
      "maille": "",
      "longueur": null,
      "largeur": null,
      "statutCOQ": null
    },
    {
      "id": "631b80af-ddba-4868-b0dc-f55ad72160bb",
      "heure": "18:00",
      "numeroPlaque": "",
      "maille": "",
      "longueur": null,
      "largeur": null,
      "statutCOQ": null
    },
    {
      "id": "284b65eb-4f0f-4cd9-8532-9078e6a316da",
      "heure": "21:00",
      "numeroPlaque": "",
      "maille": "",
      "longueur": null,
      "largeur": null,
      "statutCOQ": null
    }
  ],
  "arretsMachine": [],
  "consommations": [],
  "processControl": [
    {
      "id": "8222361a-a6a3-4182-b96f-8dbf5c0bf313",
      "bloc": "controle_08h20",
      "parametre": "Niveau bain de résine",
      "valeurP1": "",
      "corP1": false,
      "valeurP2": "",
      "corP2": false
    },
    {
      "id": "e66448ca-053d-46de-8b23-57460d728053",
      "bloc": "controle_08h20",
      "parametre": "Diamètre de bar",
      "valeurP1": "12",
      "corP1": false,
      "valeurP2": "",
      "corP2": false
    },
    {
      "id": "c126c9c2-8067-4a10-8b3d-ca81a3885970",
      "bloc": "controle_08h20",
      "parametre": "Température de machine",
      "valeurP1": "",
      "corP1": false,
      "valeurP2": "",
      "corP2": false
    },
    {
      "id": "8d1c9fd4-53fd-4ed3-b7a9-06a7d40cf1be",
      "bloc": "controle_08h20",
      "parametre": "Validation impression",
      "valeurP1": "",
      "corP1": false,
      "valeurP2": "",
      "corP2": false
    },
    {
      "id": "614b99cd-b239-4834-ae5c-251bc46ec9a7",
      "bloc": "controle_08h20",
      "parametre": "Nombre de barre en longueur",
      "valeurP1": "",
      "corP1": false,
      "valeurP2": "",
      "corP2": false
    },
    {
      "id": "6d2e0a72-8cff-45ee-a2da-00956656a2d5",
      "bloc": "controle_08h20",
      "parametre": "Dimensions de maille",
      "valeurP1": "",
      "corP1": false,
      "valeurP2": "",
      "corP2": false
    },
    {
      "id": "af2ad075-ecf5-4acf-a24a-27aef43c4e97",
      "bloc": "controle_08h20",
      "parametre": "Dimensions côté 1 long",
      "valeurP1": "",
      "corP1": false,
      "valeurP2": "",
      "corP2": false
    },
    {
      "id": "ca92651b-ac15-445e-840f-bf46b47dc584",
      "bloc": "controle_08h20",
      "parametre": "Dimensions côté 2 long",
      "valeurP1": "",
      "corP1": false,
      "valeurP2": "",
      "corP2": false
    },
    {
      "id": "ecb31fe4-5cd3-4107-b77d-2cd6e09022dd",
      "bloc": "controle_08h20",
      "parametre": "Fuite d'air comprimé",
      "valeurP1": "",
      "corP1": false,
      "valeurP2": "",
      "corP2": false
    },
    {
      "id": "54185279-3438-496a-97cd-7e7dba39dbd3",
      "bloc": "controle_08h20",
      "parametre": "Nombre de barre en largeur",
      "valeurP1": "",
      "corP1": false,
      "valeurP2": "",
      "corP2": false
    },
    {
      "id": "dd1ea3c4-02c8-4b4f-8c71-01e532784ad7",
      "bloc": "controle_10h20",
      "parametre": "Niveau bain de résine",
      "valeurP1": "",
      "corP1": false,
      "valeurP2": "",
      "corP2": false
    },
    {
      "id": "cb9b785f-5497-4169-8953-5dcbce2bd9ce",
      "bloc": "controle_10h20",
      "parametre": "Diamètre de bar",
      "valeurP1": "",
      "corP1": false,
      "valeurP2": "",
      "corP2": false
    },
    {
      "id": "31402077-2f36-4ceb-8dab-822f89f464cb",
      "bloc": "controle_10h20",
      "parametre": "Température de machine",
      "valeurP1": "",
      "corP1": false,
      "valeurP2": "",
      "corP2": false
    },
    {
      "id": "cae501f1-fb51-4fbc-a1ac-2ef8d194a55f",
      "bloc": "controle_10h20",
      "parametre": "Température d'eau",
      "valeurP1": "",
      "corP1": false,
      "valeurP2": "",
      "corP2": false
    },
    {
      "id": "4d57caea-0615-41b1-8943-123d6b956d63",
      "bloc": "controle_10h20",
      "parametre": "Pression d'air comprimé",
      "valeurP1": "",
      "corP1": false,
      "valeurP2": "",
      "corP2": false
    },
    {
      "id": "8b82c910-9bf6-4fb7-8d85-236e5d346fd5",
      "bloc": "controle_10h20",
      "parametre": "Validation impression",
      "valeurP1": "",
      "corP1": false,
      "valeurP2": "",
      "corP2": false
    },
    {
      "id": "98abd690-3be4-44ec-abcc-4bd59d68b3ee",
      "bloc": "controle_10h20",
      "parametre": "Nombre de barre en longueur",
      "valeurP1": "",
      "corP1": false,
      "valeurP2": "",
      "corP2": false
    },
    {
      "id": "339f83fb-7701-4283-9b29-6fc98c3af1c8",
      "bloc": "controle_10h20",
      "parametre": "Dimensions de maille",
      "valeurP1": "",
      "corP1": false,
      "valeurP2": "",
      "corP2": false
    },
    {
      "id": "2bd96ea1-04f2-4e6d-bec3-900e166fa992",
      "bloc": "controle_10h20",
      "parametre": "Dimensions côté 1 long",
      "valeurP1": "",
      "corP1": false,
      "valeurP2": "",
      "corP2": false
    },
    {
      "id": "3dececdb-8648-43cd-88c7-ef32815296d4",
      "bloc": "controle_10h20",
      "parametre": "Dimensions côté 2 long",
      "valeurP1": "",
      "corP1": false,
      "valeurP2": "",
      "corP2": false
    },
    {
      "id": "c8605bbf-ba84-4043-8a9c-7dc2404fbb7d",
      "bloc": "controle_10h20",
      "parametre": "Fuite d'eau",
      "valeurP1": "",
      "corP1": false,
      "valeurP2": "",
      "corP2": false
    },
    {
      "id": "b3e3b6e0-e2b2-4dca-800f-3a156e3c6d37",
      "bloc": "controle_10h20",
      "parametre": "Fuite d'air comprimé",
      "valeurP1": "",
      "corP1": false,
      "valeurP2": "",
      "corP2": false
    },
    {
      "id": "6ef6deb0-af0c-4d91-bf24-8b084e9376d2",
      "bloc": "controle_10h20",
      "parametre": "Etat disque de coupe",
      "valeurP1": "",
      "corP1": false,
      "valeurP2": "",
      "corP2": false
    },
    {
      "id": "325e33ef-405e-4d4a-963f-188fef555a97",
      "bloc": "controle_10h20",
      "parametre": "Nombre de barre en largeur",
      "valeurP1": "",
      "corP1": false,
      "valeurP2": "",
      "corP2": false
    },
    {
      "id": "98d0f290-cd75-4930-a564-0abf11236bb5",
      "bloc": "controle_14h20",
      "parametre": "Niveau bain de résine",
      "valeurP1": "",
      "corP1": false,
      "valeurP2": "",
      "corP2": false
    },
    {
      "id": "2eb469f3-11a5-42e5-ae01-4ca18efcfcc4",
      "bloc": "controle_14h20",
      "parametre": "Diamètre de bar",
      "valeurP1": "",
      "corP1": false,
      "valeurP2": "",
      "corP2": false
    },
    {
      "id": "767058c3-f810-48db-8b4a-8e10be3c6ab7",
      "bloc": "controle_14h20",
      "parametre": "Température de machine",
      "valeurP1": "",
      "corP1": false,
      "valeurP2": "",
      "corP2": false
    },
    {
      "id": "d98183d9-f6f1-485a-badb-b44850724f7f",
      "bloc": "controle_14h20",
      "parametre": "Température d'eau",
      "valeurP1": "",
      "corP1": false,
      "valeurP2": "",
      "corP2": false
    },
    {
      "id": "16ae9836-3122-40e3-acde-22fd384a4670",
      "bloc": "controle_14h20",
      "parametre": "Pression d'air comprimé",
      "valeurP1": "",
      "corP1": false,
      "valeurP2": "",
      "corP2": false
    },
    {
      "id": "25c3c1c3-c266-4abb-bf30-a4f4ced73090",
      "bloc": "controle_14h20",
      "parametre": "Validation impression",
      "valeurP1": "",
      "corP1": false,
      "valeurP2": "",
      "corP2": false
    },
    {
      "id": "fa71c0cb-3db8-43e3-b315-38d80328eb6f",
      "bloc": "controle_14h20",
      "parametre": "Nombre de barre en longueur",
      "valeurP1": "",
      "corP1": false,
      "valeurP2": "",
      "corP2": false
    },
    {
      "id": "4162f40d-175f-4ff9-80f3-211dd7189a57",
      "bloc": "controle_14h20",
      "parametre": "Dimensions de maille",
      "valeurP1": "",
      "corP1": false,
      "valeurP2": "",
      "corP2": false
    },
    {
      "id": "4b6b830c-53d5-42e0-8043-7881d591ae02",
      "bloc": "controle_14h20",
      "parametre": "Dimensions côté 1 long",
      "valeurP1": "",
      "corP1": false,
      "valeurP2": "",
      "corP2": false
    },
    {
      "id": "0ec09551-b951-4741-8497-dc78af20361c",
      "bloc": "controle_14h20",
      "parametre": "Dimensions côté 2 long",
      "valeurP1": "",
      "corP1": false,
      "valeurP2": "",
      "corP2": false
    },
    {
      "id": "782f5d3b-bc41-4869-b91b-2b29fa882c33",
      "bloc": "controle_14h20",
      "parametre": "Fuite d'eau",
      "valeurP1": "",
      "corP1": false,
      "valeurP2": "",
      "corP2": false
    },
    {
      "id": "647428c0-dfea-411a-8bf5-14e14fc1fbee",
      "bloc": "controle_14h20",
      "parametre": "Fuite d'air comprimé",
      "valeurP1": "",
      "corP1": false,
      "valeurP2": "",
      "corP2": false
    },
    {
      "id": "91e03471-cd3b-4278-ae5a-6419983bad95",
      "bloc": "controle_14h20",
      "parametre": "Etat disque de coupe",
      "valeurP1": "",
      "corP1": false,
      "valeurP2": "",
      "corP2": false
    },
    {
      "id": "dd1d237c-0d25-4317-8ff0-1ea3afd99f1f",
      "bloc": "controle_14h20",
      "parametre": "Nombre de barre en largeur",
      "valeurP1": "",
      "corP1": false,
      "valeurP2": "",
      "corP2": false
    },
    {
      "id": "53e0901b-135d-4135-ad4f-807d43bca530",
      "bloc": "controle_08h20",
      "parametre": "Température d'eau",
      "valeurP1": "45",
      "corP1": true,
      "valeurP2": null,
      "corP2": false
    },
    {
      "id": "f9eea475-0203-414c-8359-936bf013ff24",
      "bloc": "controle_08h20",
      "parametre": "Etat disque de coupe",
      "valeurP1": "OK",
      "corP1": true,
      "valeurP2": null,
      "corP2": false
    },
    {
      "id": "754043a1-8970-4baf-b223-76527c8b9c00",
      "bloc": "controle_08h20",
      "parametre": "Fuite d'eau",
      "valeurP1": "Non",
      "corP1": true,
      "valeurP2": null,
      "corP2": false
    },
    {
      "id": "14d79b89-54f4-4de9-bbb6-ff8bb2529d68",
      "bloc": "controle_08h20",
      "parametre": "Pression d'air comprimé",
      "valeurP1": "> 6 bars",
      "corP1": true,
      "valeurP2": null,
      "corP2": false
    }
  ],
  "nonConformites": [],
  "attachments": [],
  "createdAt": "2026-09-28T10:23:29.310Z",
  "updatedAt": "2026-09-29T13:29:10.651Z"
}''';
