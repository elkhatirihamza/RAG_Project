from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class LoadedPage:
    text: str
    page: int | None


SUPPORTED_TYPES = {
    ".pdf": "application/pdf",
    ".txt": "text/plain",
    ".md": "text/markdown",
    ".docx": "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
}


def load_document(path: Path) -> list[LoadedPage]:
    suffix = path.suffix.lower()
    if suffix == ".pdf":
        from pypdf import PdfReader

        return [LoadedPage(page.extract_text() or "", number) for number, page in enumerate(PdfReader(path).pages, 1)]
    if suffix in {".txt", ".md"}:
        return [LoadedPage(path.read_text(encoding="utf-8", errors="replace"), None)]
    if suffix == ".docx":
        from docx import Document

        document = Document(path)
        return [LoadedPage("\n".join(paragraph.text for paragraph in document.paragraphs), None)]
    raise ValueError(f"Unsupported document type: {suffix}")
