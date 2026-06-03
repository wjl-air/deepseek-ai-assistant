from sqlalchemy.orm import Session
from ..models import Message, Session
from ..schemas import MessageCreate

def get_session_messages(db: Session, session_id: int, user_id: int):
    session = db.query(Session).filter(
        Session.id == session_id,
        Session.user_id == user_id
    ).first()
    if not session:
        return None
    
    return db.query(Message).filter(
        Message.session_id == session_id
    ).order_by(Message.created_at.asc()).all()

def create_message(db: Session, message_create: MessageCreate, session_id: int):
    db_message = Message(
        session_id=session_id,
        role=message_create.role,
        content=message_create.content,
        reasoning_content=message_create.reasoning_content,
        image_urls=message_create.image_urls,
        web_search_enabled=message_create.web_search_enabled or False,
        rag_sources=message_create.rag_sources
    )
    db.add(db_message)
    db.commit()
    db.refresh(db_message)
    
    db.query(Session).filter(Session.id == session_id).update(
        {"updated_at": db_message.created_at}
    )
    db.commit()
    
    return db_message

def delete_message(db: Session, message_id: int, session_id: int, user_id: int):
    session = db.query(Session).filter(
        Session.id == session_id,
        Session.user_id == user_id
    ).first()
    if not session:
        return False
    
    message = db.query(Message).filter(
        Message.id == message_id,
        Message.session_id == session_id
    ).first()
    if not message:
        return False
    
    db.delete(message)
    db.commit()
    return True
