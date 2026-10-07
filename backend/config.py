from dataclasses import dataclass
import os
from pathlib import Path


@dataclass(frozen=True)
class Settings:
    google_api_key: str = os.getenv("GOOGLE_API_KEY", "")
    chroma_path: Path = Path(os.getenv("CHROMA_PATH", "data/vector_db"))
    documents_path: Path = Path(os.getenv("DOCUMENTS_PATH", "data/documents"))
    allowed_origins: tuple[str, ...] = tuple(
        origin.strip()
        for origin in os.getenv(
            "ALLOWED_ORIGINS", "http://localhost:3000,http://localhost:5173"
        ).split(",")
        if origin.strip()
    )


settings = Settings()
