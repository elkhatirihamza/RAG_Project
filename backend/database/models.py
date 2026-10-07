from dataclasses import asdict, dataclass
from datetime import datetime, timezone
import json
from pathlib import Path
from typing import Any


@dataclass(frozen=True)
class DocumentRecord:
    id: str
    name: str
    size: int
    content_type: str
    pages: int
    status: str
    created_at: str

    @classmethod
    def create(cls, document_id: str, name: str, size: int, content_type: str, pages: int) -> "DocumentRecord":
        return cls(
            id=document_id,
            name=name,
            size=size,
            content_type=content_type,
            pages=pages,
            status="indexed",
            created_at=datetime.now(timezone.utc).isoformat(),
        )


class DocumentCatalog:
    def __init__(self, path: Path) -> None:
        self.path = path / "index.json"
        self.path.parent.mkdir(parents=True, exist_ok=True)

    def list(self) -> list[DocumentRecord]:
        if not self.path.exists():
            return []
        data = json.loads(self.path.read_text(encoding="utf-8"))
        return [DocumentRecord(**item) for item in data]

    def add(self, document: DocumentRecord) -> DocumentRecord:
        documents = [item for item in self.list() if item.id != document.id]
        documents.append(document)
        self.path.write_text(
            json.dumps([asdict(item) for item in documents], ensure_ascii=False, indent=2),
            encoding="utf-8",
        )
        return document

    def remove(self, document_id: str) -> DocumentRecord | None:
        documents = self.list()
        remaining = [item for item in documents if item.id != document_id]
        removed = next((item for item in documents if item.id == document_id), None)
        if removed is not None:
            self.path.write_text(
                json.dumps([asdict(item) for item in remaining], ensure_ascii=False, indent=2),
                encoding="utf-8",
            )
        return removed

    def get(self, document_id: str) -> DocumentRecord | None:
        return next((item for item in self.list() if item.id == document_id), None)
