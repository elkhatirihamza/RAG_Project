from backend.config import settings
from backend.database.vector_store import RetrievedChunk


SYSTEM_PROMPT = """You are a helpful assistant specialized in answering questions using the user's documents.
Use the provided context as your primary source. Do not invent facts absent from the context.
If the answer is not in the context, say: I could not find this information in the provided documents.
Answer in the language used by the user. Be clear and concise.

Context:
{context}

Conversation history:
{history}

User question:
{question}
"""


class GeminiGenerator:
    def __init__(self) -> None:
        if not settings.google_api_key:
            raise RuntimeError("GOOGLE_API_KEY is not configured")
        from google import genai

        self.client = genai.Client(api_key=settings.google_api_key)
        self.model = "gemini-2.5-flash"

    def answer(self, question: str, chunks: list[RetrievedChunk], history: list[dict[str, str]]) -> str:
        context = "\n\n".join(
            f"[{chunk.document_name}, page {chunk.page or 'n/a'}]\n{chunk.text}" for chunk in chunks
        )
        history_text = "\n".join(f"{item['role']}: {item['content']}" for item in history[-6:])
        response = self.client.models.generate_content(
            model=self.model,
            contents=SYSTEM_PROMPT.format(context=context, history=history_text, question=question),
        )
        return response.text or "I could not generate an answer."
