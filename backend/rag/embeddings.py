from backend.config import settings


class GeminiEmbeddings:
    def __init__(self) -> None:
        if not settings.google_api_key:
            raise RuntimeError("GOOGLE_API_KEY is not configured")
        from google import genai

        self.client = genai.Client(api_key=settings.google_api_key)
        self.model = "gemini-embedding-001"

    def embed(self, texts: list[str]) -> list[list[float]]:
        response = self.client.models.embed_content(model=self.model, contents=texts)
        return [list(embedding.values) for embedding in response.embeddings]
