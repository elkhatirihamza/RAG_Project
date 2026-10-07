from backend.database.vector_store import ChromaVectorStore, RetrievedChunk
from backend.rag.chunker import TextChunk, chunk_text
from backend.rag.embeddings import GeminiEmbeddings
from backend.rag.generator import GeminiGenerator
from backend.rag.loader import LoadedPage


class RagPipeline:
    def __init__(self, vector_store: ChromaVectorStore, generator: GeminiGenerator) -> None:
        self.vector_store = vector_store
        self.generator = generator

    def ingest(self, document_id: str, document_name: str, pages: list[LoadedPage]) -> list[TextChunk]:
        chunks = [
            chunk
            for page in pages
            for chunk in chunk_text(
                document_id=document_id,
                document_name=document_name,
                text=page.text,
                page=page.page,
            )
        ]
        self.vector_store.add_documents(chunks)
        return chunks

    def ask(
        self,
        question: str,
        history: list[dict[str, str]],
        document_ids: list[str] | None = None,
    ) -> tuple[str, list[RetrievedChunk]]:
        chunks = self.vector_store.similarity_search(question, top_k=5, document_ids=document_ids)
        return self.generator.answer(question, chunks, history), chunks


def create_pipeline() -> RagPipeline:
    from backend.config import settings

    embeddings = GeminiEmbeddings()
    return RagPipeline(ChromaVectorStore(settings.chroma_path, embeddings), GeminiGenerator())
