import aiosmtplib
import os
import random
from email.mime.text import MIMEText
from dotenv import load_dotenv

load_dotenv()

SMTP_HOST = os.getenv("SMTP_HOST", "smtp.gmail.com")
SMTP_PORT = int(os.getenv("SMTP_PORT", "465"))
SMTP_USER = os.getenv("SMTP_USER", "")
SMTP_PASSWORD = os.getenv("SMTP_PASSWORD", "")
SMTP_FROM = os.getenv("SMTP_FROM", SMTP_USER)
OTP_EXPIRE_MINUTES = int(os.getenv("OTP_EXPIRE_MINUTES", "5"))
# 开发模式：当SMTP未配置时，打印验证码到控制台
DEV_MODE = os.getenv("DEV_MODE", "false").lower() == "true"


def generate_otp() -> str:
    return f"{random.randint(0, 999999):06d}"


def build_otp_email(code: str) -> str:
    return f"""
    <div style="font-family: 'Microsoft YaHei', sans-serif; max-width: 480px; margin: 0 auto; padding: 30px; background: #f9f9f9;">
        <div style="background: #fff; border-radius: 12px; padding: 40px; box-shadow: 0 2px 8px rgba(0,0,0,0.08);">
            <h2 style="color: #333; margin-bottom: 20px;">邮箱验证码</h2>
            <p style="color: #666; font-size: 14px;">您的注册验证码为：</p>
            <div style="background: #f0f7ff; border-radius: 8px; padding: 20px; text-align: center; margin: 20px 0;">
                <span style="font-size: 36px; font-weight: bold; color: #1a73e8; letter-spacing: 12px;">{code}</span>
            </div>
            <p style="color: #999; font-size: 13px;">验证码 {OTP_EXPIRE_MINUTES} 分钟内有效，请勿泄露给他人。</p>
            <hr style="border: none; border-top: 1px solid #eee; margin: 20px 0;">
            <p style="color: #bbb; font-size: 12px;">如非本人操作，请忽略此邮件。</p>
        </div>
    </div>
    """


async def send_otp_email(to_email: str, code: str) -> bool:
    # 开发模式：打印验证码到控制台
    if DEV_MODE or not SMTP_USER or not SMTP_PASSWORD:
        print(f"\n" + "="*60)
        print(f"【开发模式 - 验证码】")
        print(f"邮箱: {to_email}")
        print(f"验证码: {code}")
        print(f"有效期: {OTP_EXPIRE_MINUTES}分钟")
        print("="*60 + "\n")
        return True

    subject = "【验证码】注册验证"
    body = build_otp_email(code)
    msg = MIMEText(body, "html", "utf-8")
    msg["From"] = SMTP_FROM
    msg["To"] = to_email
    msg["Subject"] = subject

    try:
        await aiosmtplib.send(
            msg,
            hostname=SMTP_HOST,
            port=SMTP_PORT,
            username=SMTP_USER,
            password=SMTP_PASSWORD,
            use_tls=True,
        )
        print(f"Successfully sent OTP email to {to_email}")
        return True
    except Exception as e:
        print(f"Failed to send email to {to_email}: {e}")
        return False
