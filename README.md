# Atlas RAG

Application de question-réponse sur documents, avec un client Flutter (Web, iOS, Android) et un backend FastAPI. Les documents sont extraits, découpés, vectorisés dans ChromaDB, puis les passages pertinents sont envoyés à Gemini. La clé Google reste exclusivement côté backend.

## Architecture

```text
Flutter
  -> FastAPI REST
     -> loaders PDF / TXT / DOCX / Markdown
     -> chunking avec chevauchement
     -> embeddings Gemini
     -> ChromaDB
     -> retrieval top-k
     -> Gemini 2.5 Flash
     -> réponse + sources
```

Le pipeline métier est isolé dans `backend/rag/`, le stockage dans `backend/database/` et les routes dans `backend/api/`. Le client utilise `API_BASE_URL` pour rester configurable entre Web, émulateur et appareil physique.

## Installation

Python 3.12+ et Flutter sont nécessaires.

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
```

Renseignez `GOOGLE_API_KEY` dans `.env`. La clé est créée depuis Google AI Studio et ne doit jamais être ajoutée au code Flutter.

## Lancement

Backend :

```bash
uvicorn backend.main:app --reload --port 8000
```

Vérification : `GET http://localhost:8000/health`

Client Flutter Web :

```bash
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000
```

Sur un appareil physique, remplacez `localhost` par l’adresse IP locale de la machine qui exécute FastAPI.

## API

| Méthode | Route | Rôle |
| --- | --- | --- |
| GET | `/health` | Vérifier le service |
| GET | `/api/documents` | Lister les documents indexés |
| POST | `/api/documents/upload` | Importer et indexer un fichier |
| DELETE | `/api/documents/{id}` | Supprimer un document et ses vecteurs |
| POST | `/api/chat` | Interroger les documents avec Gemini |

Formats acceptés : PDF, TXT, DOCX et Markdown. La taille maximale est de 20 MB par fichier. Une réponse contient les noms et pages des chunks récupérés comme sources.

## Tests

```bash
pytest -q
flutter analyze
```

Les tests actuels couvrent la santé de l’API et les invariants du chunker. Un test d’intégration Gemini nécessite une clé et doit rester séparé des tests unitaires.

## RAG Pipeline

```text
Documents
-> Text Extraction
-> Chunking
-> Embeddings
-> ChromaDB
-> Retrieval
-> Context
-> Gemini
-> Answer + Sources
```

## Roadmap

- Historique persistant des conversations.
- Streaming Gemini.
- Mode Study : résumé, QCM et flashcards.
- Reranking et filtres avancés par document.
- Authentification et stockage objet en production.# rag_test1

A new Flutter project.
