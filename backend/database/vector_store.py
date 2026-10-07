from dataclasses import dataclass
from pathlib import Path
from typing import Any

from backend.rag.chunker import TextChunk


@dataclass(frozen=True)
class RetrievedChunk:
    text: str
    document_id: str
    document_name: str
    page: int | None
    relevance: float


class ChromaVectorStore:
    def __init__(self, path: Path, embeddings: Any) -> None:
        import chromadb

        self.client = chromadb.PersistentClient(path=str(path))
        self.collection = self.client.get_or_create_collection("document_chunks")
        self.embeddings = embeddings

    def add_documents(self, chunks: list[TextChunk]) -> None:
        if not chunks:
            return
        vectors = self.embeddings.embed([chunk.text for chunk in chunks])
        self.collection.upsert(
            ids=[chunk.id for chunk in chunks],
            documents=[chunk.text for chunk in chunks],
            embeddings=vectors,
            metadatas=[
                {
                    "document_id": chunk.document_id,
                    "document_name": chunk.document_name,
                    "page": chunk.page or 0,
                }
                for chunk in chunks
            ],
        )

    def similarity_search(self, query: str, top_k: int = 5, document_ids: list[str] | None = None) -> list[RetrievedChunk]:
        query_vector = self.embeddings.embed([query])[0]
        where = {"document_id": {"$in": document_ids}} if document_ids else None
        result = self.collection.query(query_embeddings=[query_vector], n_results=top_k, where=where)
        documents = result.get("documents", [[]])[0]
        metadatas = result.get("metadatas", [[]])[0]
        distances = result.get("distances", [[]])[0]
        return [
            RetrievedChunk(
                text=text,
                document_id=metadata["document_id"],
                document_name=metadata["document_name"],
                page=metadata.get("page") or None,
                relevance=max(0.0, 1.0 - float(distance)),
            )
            for text, metadata, distance in zip(documents, metadatas, distances)
        ]

    def delete_document(self, document_id: str) -> None:
        self.collection.delete(where={"document_id": document_id})
