# Atlas RAG

Atlas RAG est une application de question-réponse fondée sur les documents. Elle associe une interface Flutter à une API FastAPI et à un pipeline RAG (Retrieval-Augmented Generation) pour retrouver les passages utiles avant de générer une réponse contextualisée.

## Structure du projet

```text
rag_projet/
├── lib/
│   └── main.dart                 # Application Flutter et interface de chat
├── backend/
│   ├── main.py                   # Création de l’application FastAPI
│   ├── config.py                 # Configuration des chemins et services
│   ├── api/
│   │   ├── chat.py               # Route de question-réponse
│   │   └── documents.py          # Routes d’import, liste et suppression
│   ├── database/
│   │   ├── models.py             # Modèles et catalogue des documents
│   │   └── vector_store.py       # Persistance et recherche dans ChromaDB
│   └── rag/
│       ├── loader.py             # Lecture des PDF, TXT, Markdown et DOCX
│       ├── chunker.py            # Découpage du texte en segments
│       ├── embeddings.py         # Transformation des textes en vecteurs
│       ├── generator.py          # Génération des réponses
│       └── pipeline.py           # Orchestration du pipeline RAG
├── data/
│   └── documents/                # Fichiers importés par l’application
├── tests/                        # Tests du backend et du traitement de texte
├── test/                         # Tests de l’application Flutter
├── android/                      # Configuration de la cible Android
├── ios/                          # Configuration de la cible iOS
├── web/                          # Configuration de la cible Web
├── requirements.txt              # Dépendances Python
└── pubspec.yaml                  # Dépendances Flutter/Dart
```

## Architecture générale

L’application est organisée en deux parties principales :

- **Client Flutter** : interface de conversation, sélection des documents, envoi des questions et affichage des réponses avec leurs sources.
- **Backend FastAPI** : API REST qui reçoit les fichiers et les questions, exécute le pipeline RAG et renvoie les résultats au client.

Le client communique avec le backend via HTTP. L’adresse de l’API est configurable avec `API_BASE_URL`, ce qui permet d’utiliser la même interface sur Web, Android ou iOS.

## Pipeline RAG

```text
Import d’un document
  ↓
Extraction du texte et des pages
  ↓
Découpage en chunks
  ↓
Calcul des embeddings
  ↓
Stockage dans ChromaDB
  ↓
Recherche sémantique des passages pertinents
  ↓
Construction du contexte
  ↓
Génération de la réponse
  ↓
Réponse accompagnée des sources
```

### 1. Ingestion des documents

La route `/api/documents/upload` vérifie le fichier, le sauvegarde dans `data/documents/`, puis le transmet au loader. Le loader prend en charge les formats PDF, TXT, Markdown et DOCX.

### 2. Préparation et indexation

Le texte extrait est découpé en chunks par `backend/rag/chunker.py`. Chaque chunk conserve les métadonnées du document et, lorsque cela est disponible, son numéro de page. Les chunks sont convertis en embeddings puis enregistrés dans la collection ChromaDB par `ChromaVectorStore`.

### 3. Recherche et génération

Lorsqu’une question arrive sur `/api/chat`, le vector store effectue une recherche de similarité et sélectionne les passages les plus pertinents. Le générateur utilise ces passages ainsi que l’historique de conversation pour produire une réponse. Les métadonnées des chunks récupérés sont renvoyées comme sources.

## Organisation des responsabilités

```text
Flutter
  └── Client HTTP et interface utilisateur
       └── FastAPI
      ├── API documents et chat
      ├── Pipeline RAG
      │    ├── Loaders
      │    ├── Chunker
      │    ├── Embeddings
      │    └── Générateur
      └── Persistance
     ├── Catalogue des documents
     └── ChromaDB
```

A new Flutter project.
