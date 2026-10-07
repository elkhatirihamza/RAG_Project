import re
from dataclasses import dataclass


@dataclass(frozen=True)
class TextChunk:
    id: str
    text: str
    document_id: str
    document_name: str
    page: int | None


def chunk_text(
    text: str,
    document_id: str,
    document_name: str,
    page: int | None = None,
    chunk_size: int = 3200,
    overlap: int = 600,
) -> list[TextChunk]:
    if chunk_size <= overlap:
        raise ValueError("chunk_size must be greater than overlap")
    paragraphs = [re.sub(r"\s+", " ", part).strip() for part in text.split("\n")]
    paragraphs = [part for part in paragraphs if part]
    chunks: list[TextChunk] = []
    current = ""
    for paragraph in paragraphs:
        candidate = f"{current} {paragraph}".strip()
        if current and len(candidate) > chunk_size:
            chunk_number = len(chunks)
            chunks.append(TextChunk(f"{document_id}-{chunk_number}", current, document_id, document_name, page))
            current = f"{current[-overlap:]} {paragraph}".strip()
        else:
            current = candidate
    if current:
        chunks.append(TextChunk(f"{document_id}-{len(chunks)}", current, document_id, document_name, page))
    return chunks
