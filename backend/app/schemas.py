from pydantic import BaseModel, EmailStr, field_validator
from datetime import datetime
from typing import Optional, List, Any

class UserCreate(BaseModel):
    email: EmailStr
    password: str
    nickname: Optional[str] = None

    @field_validator('password')
    @classmethod
    def validate_password(cls, v: str) -> str:
        if len(v) < 8:
            raise ValueError('密码长度不能少于8个字符')
        if len(v) > 128:
            raise ValueError('密码长度不能超过128个字符')
        return v

class UserUpdate(BaseModel):
    nickname: Optional[str] = None
    avatar_url: Optional[str] = None
    phone: Optional[str] = None

class UserResponse(BaseModel):
    id: int
    email: str
    nickname: Optional[str]
    avatar_url: Optional[str]
    phone: Optional[str]
    created_at: datetime
    
    class Config:
        from_attributes = True

class LoginRequest(BaseModel):
    email: EmailStr
    password: str

class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int
    user_id: int

class RefreshTokenRequest(BaseModel):
    refresh_token: Optional[str] = None

class SessionCreate(BaseModel):
    title: Optional[str] = None
    model: Optional[str] = None
    web_search_enabled: Optional[bool] = False

class SessionUpdate(BaseModel):
    title: Optional[str] = None

class SessionResponse(BaseModel):
    id: int
    title: str
    model: str
    web_search_enabled: bool
    created_at: datetime
    updated_at: Optional[datetime] = None
    
    class Config:
        from_attributes = True

class MessageCreate(BaseModel):
    role: str
    content: str
    reasoning_content: Optional[str] = None
    image_urls: Optional[List[str]] = None
    web_search_enabled: Optional[bool] = False
    rag_sources: Optional[Any] = None

class MessageResponse(BaseModel):
    id: int
    session_id: int
    role: str
    content: str
    reasoning_content: Optional[str] = None
    image_urls: Optional[List[str]] = None
    web_search_enabled: bool
    rag_sources: Optional[Any] = None
    created_at: datetime
    
    class Config:
        from_attributes = True

class OAuthLoginRequest(BaseModel):
    provider: str
    code: str
    redirect_uri: str
    state: str

class OAuthProviderInfo(BaseModel):
    name: str
    display_name: str
    auth_url: str
    enabled: bool

class OAuthProviderListResponse(BaseModel):
    providers: List[OAuthProviderInfo]

class SendOTPRequest(BaseModel):
    email: EmailStr

class VerifyAndRegisterRequest(BaseModel):
    email: EmailStr
    code: str
    password: str
    nickname: Optional[str] = None

    @field_validator('password')
    @classmethod
    def validate_password(cls, v: str) -> str:
        if len(v) < 8:
            raise ValueError('密码长度不能少于8个字符')
        if len(v) > 128:
            raise ValueError('密码长度不能超过128个字符')
        return v

    @field_validator('code')
    @classmethod
    def validate_code(cls, v: str) -> str:
        if not v.isdigit() or len(v) != 6:
            raise ValueError('验证码必须是6位数字')
        return v


class LoginCodeRequest(BaseModel):
    pass


class LoginCodeResponse(BaseModel):
    code: str
    expires_at: datetime


class LoginWithCodeRequest(BaseModel):
    code: str
    
    @field_validator('code')
    @classmethod
    def validate_login_code(cls, v: str) -> str:
        if len(v) != 8:
            raise ValueError('登录码必须是8位字符')
        return v


class DeviceResponse(BaseModel):
    id: int
    user_id: int
    device_info: Optional[str]
    ip_address: Optional[str]
    expires_at: datetime
    created_at: datetime
    revoked: bool
    
    class Config:
        from_attributes = True


class RevokeDeviceRequest(BaseModel):
    device_id: int
