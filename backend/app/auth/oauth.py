from datetime import datetime, timedelta
from typing import Optional, Dict, List
from sqlalchemy.orm import Session
from ..models import User, OAuthAccount
from ..schemas import OAuthProviderInfo
from .service import create_access_token, create_refresh_token, save_refresh_token, get_password_hash
from dotenv import load_dotenv
import os
import secrets

load_dotenv()

# OAuth provider configurations
OAUTH_PROVIDERS = {
    # 示例配置，实际使用时需要配置对应的环境变量
    # "github": {
    #     "client_id": os.getenv("GITHUB_CLIENT_ID"),
    #     "client_secret": os.getenv("GITHUB_CLIENT_SECRET"),
    #     "auth_url": "https://github.com/login/oauth/authorize",
    #     "token_url": "https://github.com/login/oauth/access_token",
    #     "user_url": "https://api.github.com/user",
    #     "scope": "user:email",
    #     "display_name": "GitHub",
    #     "enabled": os.getenv("GITHUB_ENABLED", "false").lower() == "true",
    # },
}


def get_oauth_providers() -> List[OAuthProviderInfo]:
    """获取所有可用的OAuth提供商列表"""
    providers = []
    for name, config in OAUTH_PROVIDERS.items():
        if config.get("enabled", False):
            providers.append(OAuthProviderInfo(
                name=name,
                display_name=config["display_name"],
                auth_url=config["auth_url"],
                enabled=True
            ))
    return providers


def get_or_create_user_from_oauth(
    db: Session,
    provider: str,
    provider_user_id: str,
    email: str,
    nickname: Optional[str] = None,
    avatar_url: Optional[str] = None
) -> User:
    """从OAuth信息获取或创建用户"""
    # 查找是否已存在OAuth账户
    oauth_account = db.query(OAuthAccount).filter(
        OAuthAccount.provider == provider,
        OAuthAccount.provider_user_id == provider_user_id
    ).first()
    
    if oauth_account:
        # 如果存在，返回对应的用户
        return db.query(User).filter(User.id == oauth_account.user_id).first()
    
    # 查找是否已存在该邮箱的用户
    user = db.query(User).filter(User.email == email).first()
    
    if not user:
        # 创建新用户（生成随机密码）
        random_password = secrets.token_urlsafe(32)
        user = User(
            email=email,
            password_hash=get_password_hash(random_password),
            nickname=nickname or email.split("@")[0],
            avatar_url=avatar_url
        )
        db.add(user)
        db.commit()
        db.refresh(user)
    
    # 创建OAuth账户关联
    oauth_account = OAuthAccount(
        user_id=user.id,
        provider=provider,
        provider_user_id=provider_user_id
    )
    db.add(oauth_account)
    db.commit()
    
    return user


def oauth_login(
    db: Session,
    provider: str,
    code: str,
    redirect_uri: str
) -> Optional[Dict]:
    """
    OAuth登录处理（基础框架）
    实际实现需要根据具体provider添加code换token和获取用户信息的逻辑
    """
    # 这里是基础框架，具体的OAuth流程需要按provider实现
    # 示例流程：
    # 1. 用code换取access_token
    # 2. 用access_token获取用户信息
    # 3. 调用get_or_create_user_from_oauth创建或获取用户
    # 4. 生成并返回access_token和refresh_token
    
    # 目前返回None表示该功能需要进一步配置
    return None


def link_oauth_account(
    db: Session,
    user_id: int,
    provider: str,
    provider_user_id: str,
    access_token: Optional[str] = None,
    refresh_token: Optional[str] = None,
    expires_at: Optional[datetime] = None
) -> OAuthAccount:
    """关联OAuth账户到现有用户"""
    oauth_account = OAuthAccount(
        user_id=user_id,
        provider=provider,
        provider_user_id=provider_user_id,
        access_token=access_token,
        refresh_token=refresh_token,
        expires_at=expires_at
    )
    db.add(oauth_account)
    db.commit()
    db.refresh(oauth_account)
    return oauth_account


def unlink_oauth_account(db: Session, user_id: int, provider: str) -> bool:
    """解除OAuth账户关联"""
    oauth_account = db.query(OAuthAccount).filter(
        OAuthAccount.user_id == user_id,
        OAuthAccount.provider == provider
    ).first()
    
    if oauth_account:
        db.delete(oauth_account)
        db.commit()
        return True
    return False
