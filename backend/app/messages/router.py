from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from .service import (
    get_session_messages,
    create_message,
    delete_message
)
from ..auth.dependencies import get_current_user
from ..database import get_db
from ..schemas import MessageCreate, MessageResponse
from ..models import User

router = APIRouter(prefix="/sessions/{session_id}/messages", tags=["messages"])

@router.get("", response_model=list[MessageResponse])
@router.get("/", response_model=list[MessageResponse])
def read_messages(
    session_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    messages = get_session_messages(db, session_id, current_user.id)
    if messages is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="会话不存在"
        )
    return messages

@router.post("", response_model=MessageResponse, status_code=status.HTTP_201_CREATED)
@router.post("/", response_model=MessageResponse, status_code=status.HTTP_201_CREATED)
def create_new_message(
    session_id: int,
    message: MessageCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    from ..models import Session as SessionModel
    session = db.query(SessionModel).filter(
        SessionModel.id == session_id,
        SessionModel.user_id == current_user.id
    ).first()
    if not session:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="会话不存在"
        )
    
    return create_message(db, message, session_id)

@router.delete("/{message_id}")
def delete_existing_message(
    session_id: int,
    message_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    success = delete_message(db, message_id, session_id, current_user.id)
    if not success:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="消息不存在"
        )
    return {"message": "删除成功"}
