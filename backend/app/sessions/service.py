from sqlalchemy.orm import Session
from ..models import Session, User
from ..schemas import SessionCreate, SessionUpdate

def get_user_sessions(db: Session, user_id: int):
    return db.query(Session).filter(Session.user_id == user_id).order_by(Session.updated_at.desc()).all()

def get_session(db: Session, session_id: int, user_id: int):
    return db.query(Session).filter(
        Session.id == session_id,
        Session.user_id == user_id
    ).first()

def create_session(db: Session, session_create: SessionCreate, user_id: int):
    db_session = Session(
        user_id=user_id,
        title=session_create.title or "新对话",
        model=session_create.model or "deepseek-chat",
        web_search_enabled=session_create.web_search_enabled or False
    )
    db.add(db_session)
    db.commit()
    db.refresh(db_session)
    return db_session

def update_session(db: Session, session_id: int, user_id: int, session_update: SessionUpdate):
    db_session = get_session(db, session_id, user_id)
    if not db_session:
        return None
    if session_update.title:
        db_session.title = session_update.title
    db.commit()
    db.refresh(db_session)
    return db_session

def delete_session(db: Session, session_id: int, user_id: int):
    db_session = get_session(db, session_id, user_id)
    if not db_session:
        return False
    db.delete(db_session)
    db.commit()
    return True
