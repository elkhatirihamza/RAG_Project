from pydantic import BaseModel, Field
from fastapi import APIRouter, HTTPException

from backend.api.documents import get_pipeline


router = APIRouter(prefix="/api/chat", tags=["chat"])


class ChatMessage(BaseModel):
    role: str = Field(pattern="^(user|assistant)$")
    content: str = Field(min_length=1, max_length=12000)


class ChatRequest(BaseModel):
    conversation_id: str = Field(min_length=1, max_length=120)
    question: str = Field(min_length=1, max_length=12000)
    document_ids: list[str] = Field(default_factory=list)
    history: list[ChatMessage] = Field(default_factory=list, max_length=20)


@router.post("")
def chat(request: ChatRequest) -> dict[str, object]:
    try:
        answer, chunks = get_pipeline().ask(
            question=request.question,
            history=[message.model_dump() for message in request.history],
            document_ids=request.document_ids or None,
        )
    except RuntimeError as error:
        raise HTTPException(status_code=503, detail=str(error)) from error
    return {
        "conversation_id": request.conversation_id,
        "answer": answer,
        "sources": [
            {
                "document": chunk.document_name,
                "page": chunk.page,
                "relevance": round(chunk.relevance, 3),
            }
            for chunk in chunks
        ],
    }
