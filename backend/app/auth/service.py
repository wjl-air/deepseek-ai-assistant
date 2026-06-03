from datetime import datetime, timedelta, timezone
from typing import Optional
from jose import JWTError, jwt
from sqlalchemy.orm import Session
from ..models import User, RefreshToken, LoginCode
from ..schemas import UserCreate
from dotenv import load_dotenv
import os
import secrets
import bcrypt
import string

load_dotenv()

SECRET_KEY = os.getenv("SECRET_KEY")
REFRESH_SECRET_KEY = os.getenv("REFRESH_SECRET_KEY", SECRET_KEY)
ALGORITHM = os.getenv("ALGORITHM")
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES"))
REFRESH_TOKEN_EXPIRE_DAYS = int(os.getenv("REFRESH_TOKEN_EXPIRE_DAYS"))

def get_password_hash(password: str) -> str:
    return bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')

def verify_password(plain_password: str, hashed_password: str) -> bool:
    try:
        return bcrypt.checkpw(plain_password.encode('utf-8'), hashed_password.encode('utf-8'))
    except ValueError:
        # 旧的SHA-256哈希无法用bcrypt验证，视为不匹配
        return False

def create_access_token(data: dict, token_version: int = 0, expires_delta: Optional[timedelta] = None) -> str:
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.now(timezone.utc) + expires_delta
    else:
        expire = datetime.now(timezone.utc) + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire, "tv": token_version, "type": "access"})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

def create_refresh_token(data: dict) -> str:
    expire = datetime.now(timezone.utc) + timedelta(days=REFRESH_TOKEN_EXPIRE_DAYS)
    to_encode = data.copy()
    to_encode.update({
        "exp": expire,
        "jti": secrets.token_urlsafe(32),
        "type": "refresh"
    })
    encoded_jwt = jwt.encode(to_encode, REFRESH_SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

def get_user_by_email(db: Session, email: str) -> Optional[User]:
    return db.query(User).filter(User.email == email).first()

def get_user_by_id(db: Session, user_id: int) -> Optional[User]:
    return db.query(User).filter(User.id == user_id).first()

def create_user(db: Session, user: UserCreate) -> User:
    hashed_password = get_password_hash(user.password)
    db_user = User(
        email=user.email,
        password_hash=hashed_password,
        nickname=user.nickname
    )
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    return db_user

def authenticate_user(db: Session, email: str, password: str) -> Optional[User]:
    user = get_user_by_email(db, email)
    if not user or not verify_password(password, user.password_hash):
        return None
    return user

def save_refresh_token(db: Session, user_id: int, token: str, expires_at: datetime, 
                     device_info: Optional[str] = None, ip_address: Optional[str] = None) -> RefreshToken:
    db_token = RefreshToken(
        user_id=user_id,
        token=token,
        expires_at=expires_at,
        device_info=device_info,
        ip_address=ip_address
    )
    db.add(db_token)
    db.commit()
    db.refresh(db_token)
    return db_token


def get_user_devices(db: Session, user_id: int) -> list[RefreshToken]:
    """获取用户所有设备（包括已撤销的）"""
    from sqlalchemy import desc
    return db.query(RefreshToken).filter(
        RefreshToken.user_id == user_id
    ).order_by(desc(RefreshToken.created_at)).all()


def get_device_by_id(db: Session, device_id: int, user_id: int) -> Optional[RefreshToken]:
    """根据ID获取用户的特定设备"""
    return db.query(RefreshToken).filter(
        RefreshToken.id == device_id,
        RefreshToken.user_id == user_id
    ).first()

def get_valid_refresh_token(db: Session, token: str) -> Optional[RefreshToken]:
    return db.query(RefreshToken).filter(
        RefreshToken.token == token,
        RefreshToken.revoked == False,
        RefreshToken.expires_at > datetime.now(timezone.utc)
    ).first()

def revoke_refresh_token(db: Session, token: str) -> None:
    db.query(RefreshToken).filter(RefreshToken.token == token).update(
        {"revoked": True}
    )
    db.commit()

def revoke_all_user_tokens(db: Session, user_id: int) -> None:
    db.query(RefreshToken).filter(RefreshToken.user_id == user_id).update(
        {"revoked": True}
    )
    db.commit()

def revoke_all_access_tokens(db: Session, user_id: int) -> None:
    user = db.query(User).filter(User.id == user_id).first()
    if user:
        user.token_version = (user.token_version or 0) + 1
        db.commit()

def verify_token(token: str) -> Optional[dict]:
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        return payload
    except JWTError:
        return None

def verify_refresh_token(token: str) -> Optional[dict]:
    try:
        payload = jwt.decode(token, REFRESH_SECRET_KEY, algorithms=[ALGORITHM])
        return payload
    except JWTError:
        return None


def generate_login_code() -> str:
    """生成8位字母数字组合的登录码"""
    chars = string.ascii_uppercase + string.digits
    return ''.join(secrets.choice(chars) for _ in range(8))


def create_login_code(db: Session, user_id: int, expires_minutes: int = 5) -> LoginCode:
    """为用户创建登录码"""
    code = generate_login_code()
    # 确保code唯一
    while db.query(LoginCode).filter(LoginCode.code == code).first():
        code = generate_login_code()
    
    login_code = LoginCode(
        user_id=user_id,
        code=code,
        expires_at=datetime.now(timezone.utc) + timedelta(minutes=expires_minutes)
    )
    db.add(login_code)
    db.commit()
    db.refresh(login_code)
    return login_code


def get_valid_login_code(db: Session, code: str) -> Optional[LoginCode]:
    """获取有效的登录码"""
    return db.query(LoginCode).filter(
        LoginCode.code == code,
        LoginCode.used == False,
        LoginCode.expires_at > datetime.now(timezone.utc)
    ).first()


def use_login_code(db: Session, login_code: LoginCode) -> None:
    """标记登录码为已使用"""
    login_code.used = True
    db.commit()
