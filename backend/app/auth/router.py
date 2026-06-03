from datetime import datetime, timedelta, timezone
from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.orm import Session
from sqlalchemy import desc
from ..rate_limit import limiter
from ..email_service import generate_otp, send_otp_email, OTP_EXPIRE_MINUTES
from .service import (
    authenticate_user,
    create_user,
    create_access_token,
    create_refresh_token,
    save_refresh_token,
    get_valid_refresh_token,
    revoke_refresh_token,
    revoke_all_user_tokens,
    revoke_all_access_tokens,
    get_user_by_email,
    get_user_by_id,
    create_login_code,
    get_valid_login_code,
    use_login_code,
    get_user_devices,
    get_device_by_id,
    REFRESH_TOKEN_EXPIRE_DAYS,
    ACCESS_TOKEN_EXPIRE_MINUTES
)
from .dependencies import get_current_user
from ..database import get_db
from ..schemas import (
    UserCreate,
    UserResponse,
    LoginRequest,
    TokenResponse,
    RefreshTokenRequest,
    SendOTPRequest,
    VerifyAndRegisterRequest,
    LoginCodeRequest,
    LoginCodeResponse,
    LoginWithCodeRequest,
    DeviceResponse,
    RevokeDeviceRequest
)
from ..models import User, RefreshToken, EmailOTP, LoginCode

router = APIRouter(prefix="/auth", tags=["auth"])

@router.post("/register", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
@limiter.limit("5/minute")
def register(request: Request, user: UserCreate, db: Session = Depends(get_db)):
    db_user = get_user_by_email(db, user.email)
    if db_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="该邮箱已被注册"
        )
    return create_user(db, user)


@router.post("/send-otp")
@limiter.limit("3/minute")
async def send_otp(request: Request, body: SendOTPRequest, db: Session = Depends(get_db)):
    email = body.email

    # Check if email already registered
    existing = get_user_by_email(db, email)
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="该邮箱已被注册"
        )

    # Rate limit: 60s cooldown per email
    recent = db.query(EmailOTP).filter(
        EmailOTP.email == email,
        EmailOTP.purpose == "register",
        EmailOTP.created_at > datetime.utcnow() - timedelta(seconds=60)
    ).first()
    if recent:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="请等待60秒后再重新发送"
        )

    # Generate and save OTP
    code = generate_otp()
    otp = EmailOTP(
        email=email,
        code=code,
        purpose="register",
        expires_at=datetime.now(timezone.utc) + timedelta(minutes=OTP_EXPIRE_MINUTES)
    )
    db.add(otp)
    db.commit()

    # Send email
    success = await send_otp_email(email, code)
    if not success:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="验证码发送失败，请稍后再试"
        )

    return {"message": "验证码已发送"}


@router.post("/verify-and-register", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
@limiter.limit("10/minute")
def verify_and_register(request: Request, body: VerifyAndRegisterRequest, db: Session = Depends(get_db)):
    email = body.email

    # Check if already registered
    existing = get_user_by_email(db, email)
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="该邮箱已被注册"
        )

    # Find latest unused OTP
    otp = db.query(EmailOTP).filter(
        EmailOTP.email == email,
        EmailOTP.purpose == "register",
        EmailOTP.used == False
    ).order_by(desc(EmailOTP.created_at)).first()

    if not otp:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="请先获取验证码"
        )

    # Check expiration
    if otp.expires_at.replace(tzinfo=timezone.utc) < datetime.now(timezone.utc):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="验证码已过期，请重新获取"
        )

    # Check code
    if otp.code != body.code:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="验证码错误"
        )

    # Mark OTP as used
    otp.used = True

    # Create user with is_verified=True
    user_data = UserCreate(email=email, password=body.password, nickname=body.nickname)
    user = create_user(db, user_data)
    user.is_verified = True
    db.commit()
    db.refresh(user)

    return user

@router.post("/login", response_model=TokenResponse)
@limiter.limit("10/minute")
def login(request: Request, login_request: LoginRequest, db: Session = Depends(get_db)):
    user = authenticate_user(db, login_request.email, login_request.password)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="邮箱或密码错误"
        )
    
    access_token = create_access_token(data={"sub": str(user.id)}, token_version=user.token_version or 0)
    refresh_token = create_refresh_token(data={"sub": str(user.id)})
    
    expires_at = datetime.now(timezone.utc) + timedelta(days=REFRESH_TOKEN_EXPIRE_DAYS)
    
    # 获取设备信息和IP地址
    device_info = request.headers.get("user-agent", "")[:255]  # 限制长度，避免过长
    ip_address = request.client.host if request.client else None
    
    save_refresh_token(db, user.id, refresh_token, expires_at, device_info, ip_address)
    
    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "token_type": "bearer",
        "expires_in": ACCESS_TOKEN_EXPIRE_MINUTES * 60,
        "user_id": user.id
    }

@router.post("/refresh", response_model=TokenResponse)
def refresh_token(request: Request, refresh_request: RefreshTokenRequest, db: Session = Depends(get_db)):
    token_record = get_valid_refresh_token(db, refresh_request.refresh_token)
    if not token_record:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="无效的刷新令牌"
        )
    
    user = db.query(User).filter(User.id == token_record.user_id).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="用户不存在"
        )
    
    access_token = create_access_token(data={"sub": str(user.id)}, token_version=user.token_version or 0)
    new_refresh_token = create_refresh_token(data={"sub": str(user.id)})
    
    # 标记旧token为撤销（保留审计记录）
    db.query(RefreshToken).filter(RefreshToken.token == refresh_request.refresh_token).update({"revoked": True})
    expires_at = datetime.now(timezone.utc) + timedelta(days=REFRESH_TOKEN_EXPIRE_DAYS)
    
    # 获取设备信息和IP地址
    device_info = request.headers.get("user-agent", "")[:255]
    ip_address = request.client.host if request.client else None
    
    save_refresh_token(db, user.id, new_refresh_token, expires_at, device_info, ip_address)
    
    return {
        "access_token": access_token,
        "refresh_token": new_refresh_token,
        "token_type": "bearer",
        "expires_in": ACCESS_TOKEN_EXPIRE_MINUTES * 60,
        "user_id": user.id
    }

@router.post("/logout")
def logout(
    refresh_request: RefreshTokenRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if refresh_request.refresh_token:
        revoke_refresh_token(db, refresh_request.refresh_token)
    else:
        revoke_all_user_tokens(db, current_user.id)
        revoke_all_access_tokens(db, current_user.id)
    return {"message": "注销成功"}

@router.get("/me", response_model=UserResponse)
def get_current_user_info(current_user: User = Depends(get_current_user)):
    return current_user


@router.post("/login-code/generate", response_model=LoginCodeResponse, status_code=status.HTTP_201_CREATED)
@limiter.limit("3/minute")
def generate_login_code_endpoint(
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """为已登录用户生成登录码（用于其他设备/客户端登录）"""
    login_code = create_login_code(db, current_user.id)
    return {
        "code": login_code.code,
        "expires_at": login_code.expires_at
    }


@router.post("/login-code/login", response_model=TokenResponse)
@limiter.limit("5/minute")
def login_with_code(
    request: Request,
    login_request: LoginWithCodeRequest,
    db: Session = Depends(get_db)
):
    """使用登录码登录（不需要密码）"""
    login_code = get_valid_login_code(db, login_request.code)
    if not login_code:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="无效或已过期的登录码"
        )
    
    user = get_user_by_id(db, login_code.user_id)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="用户不存在"
        )
    
    # 标记登录码为已使用
    use_login_code(db, login_code)
    
    # 生成新的token
    access_token = create_access_token(data={"sub": str(user.id)}, token_version=user.token_version or 0)
    refresh_token = create_refresh_token(data={"sub": str(user.id)})
    
    expires_at = datetime.now(timezone.utc) + timedelta(days=REFRESH_TOKEN_EXPIRE_DAYS)
    
    # 获取设备信息和IP地址
    device_info = request.headers.get("user-agent", "")[:255]
    ip_address = request.client.host if request.client else None
    
    save_refresh_token(db, user.id, refresh_token, expires_at, device_info, ip_address)
    
    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "token_type": "bearer",
        "expires_in": ACCESS_TOKEN_EXPIRE_MINUTES * 60,
        "user_id": user.id
    }


@router.get("/devices", response_model=list[DeviceResponse])
@limiter.limit("30/minute")
def get_devices(
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """获取用户所有登录设备"""
    devices = get_user_devices(db, current_user.id)
    return devices


@router.post("/devices/revoke")
@limiter.limit("10/minute")
def revoke_device(
    request: Request,
    revoke_request: RevokeDeviceRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """强制下线指定设备"""
    device = get_device_by_id(db, revoke_request.device_id, current_user.id)
    if not device:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="设备不存在"
        )
    
    revoke_refresh_token(db, device.token)
    return {"message": "设备已下线"}


@router.post("/devices/revoke-all")
@limiter.limit("5/minute")
def revoke_all_devices(
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """强制下线所有其他设备（当前设备除外）"""
    revoke_all_user_tokens(db, current_user.id)
    revoke_all_access_tokens(db, current_user.id)
    return {"message": "所有设备已下线"}
