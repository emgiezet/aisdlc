using System.Security.Cryptography;

// AP-CS-SEC-006: cryptographically secure random number generation
// ok: slopguard.cs.insecure-random
public class TokenService
{
    // Safe: RandomNumberGenerator is backed by the OS CSPRNG.
    public int GenerateOtp()
    {
        return RandomNumberGenerator.GetInt32(100000, 1000000);
    }

    public byte[] GenerateSessionKey()
    {
        return RandomNumberGenerator.GetBytes(32);
    }
}
