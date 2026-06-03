from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from .service import (
    get_user_sessions,
    get_session,
    create_session,
    update_session,
    delete_session
)
from ..auth.dependencies import get_current_user
from ..database import get_db
from ..schemas import SessionCreate, SessionUpdate, SessionResponse
from ..models import User, Session

router = APIRouter(prefix="/sessions", tags=["sessions"])

@router.get("", response_model=list[SessionResponse])
@router.get("/", response_model=list[SessionResponse])
def read_sessions(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    return get_user_sessions(db, current_user.id)

@router.post("", response_model=SessionResponse, status_code=status.HTTP_201_CREATED)
@router.post("/", response_model=SessionResponse, status_code=status.HTTP_201_CREATED)
def create_new_session(
    session: SessionCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    return create_session(db, session, current_user.id)

@router.get("/{session_id}", response_model=SessionResponse)
def read_session(
    session_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    db_session = get_session(db, session_id, current_user.id)
    if not db_session:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="会话不存在"
        )
    return db_session

@router.put("/{session_id}", response_model=SessionResponse)
def update_existing_session(
    session_id: int,
    session: SessionUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    updated_session = update_session(db, session_id, current_user.id, session)
    if not updated_session:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="会话不存在"
        )
    return updated_session

@router.delete("/{session_id}")
def delete_existing_session(
    session_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    success = delete_session(db, session_id, current_user.id)
    if not success:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="会话不存在"
        )
    return {"message": "删除成功"}
