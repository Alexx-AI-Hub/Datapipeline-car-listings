"""Encrypt and decrypt text deterministically with AES-SIV.

The same text and key produce the same encrypted value. Encryption
preserves text exactly; normalize identifiers before calling if needed.

Keep the persistent key separate from data and source control. Matching values
remain linkable, so this is pseudonymization rather than anonymization.
"""
import base64
import binascii
import os
from pathlib import Path

from cryptography.hazmat.primitives.ciphers.aead import AESSIV
from dotenv import load_dotenv

load_dotenv(Path(__file__).resolve().parents[1] / "airflow" / ".env")




def get_cipher() -> AESSIV:
    """Load a Base64-encoded 512-bit AES-SIV key from ENCRYPTION_KEY.

    Generate the key once with AESSIV.generate_key(bit_length=512), Base64-encode
    it and supply it through the environment. Never regenerate it per run.
    Raise ValueError if the environment variable is missing or invalid.
    """
    encoded_key = os.environ.get("ENCRYPTION_KEY")
    if not encoded_key:
        raise ValueError("Set ENCRYPTION_KEY to a Base64-encoded 64-byte key.")
    try:
        key = base64.b64decode(encoded_key, validate=True)
    except (binascii.Error, ValueError):
        raise ValueError("ENCRYPTION_KEY must contain valid Base64.") from None
    if len(key) != 64:
        raise ValueError("ENCRYPTION_KEY must decode to exactly 64 bytes.")
    return AESSIV(key)


def encrypt_value(value: str | None, cipher: AESSIV) -> str | None:
    """Return URL-safe Base64 ciphertext, preserving None.

    Keep the same key across runs for comparable encrypted values.
    No associated data or random nonce is supplied.
    """
    if value is None:
        return None
    encrypted = cipher.encrypt(value.encode("utf-8"), None)
    return base64.urlsafe_b64encode(encrypted).decode("ascii")


def decrypt_value(value: str | None, cipher: AESSIV) -> str | None:
    """Recover the original text using the same key, preserving None.

    Invalid Base64 raises ValueError. A wrong key or modified
    ciphertext raises cryptography.exceptions.InvalidTag.
    """
    if value is None:
        return None
    try:
        encrypted = base64.b64decode(value, altchars=b"-_", validate=True)
    except (binascii.Error, ValueError):
        raise ValueError("Encrypted value must contain valid Base64.") from None
    decrypted = cipher.decrypt(encrypted, None)
    return decrypted.decode("utf-8")
