using System.Security.Cryptography;

// AP-CS-SEC-005: strong cryptographic algorithms — SHA-256 and AES-GCM
// ok: slopguard.cs.crypto-weak-algorithm
public class PasswordStore
{
    // Safe: SHA-256 is collision-resistant and approved for security use.
    public byte[] HashData(byte[] data)
    {
        return SHA256.HashData(data);
    }

    // Safe: PBKDF2 with a per-user salt for password storage.
    public byte[] DeriveKey(byte[] password, byte[] salt)
    {
        using var kdf = new Rfc2898DeriveBytes(password, salt, 600_000, HashAlgorithmName.SHA256);
        return kdf.GetBytes(32);
    }
}
