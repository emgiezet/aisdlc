using System.Security.Cryptography;

// AP-CS-SEC-005: MD5 and SHA1 are cryptographically broken
// ruleid: slopguard.cs.crypto-weak-algorithm
public class PasswordStore
{
    // Unsafe: MD5 is collision-prone and preimage-vulnerable; unsuitable for security use.
    public byte[] HashWithMd5(byte[] data)
    {
        using var md5 = MD5.Create();
        return md5.ComputeHash(data);
    }

    // Unsafe: SHA1 is deprecated for security-sensitive operations.
    public byte[] HashWithSha1(byte[] data)
    {
        using var sha1 = SHA1.Create();
        return sha1.ComputeHash(data);
    }
}
