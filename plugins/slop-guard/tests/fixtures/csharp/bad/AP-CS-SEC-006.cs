using System;

// AP-CS-SEC-006: System.Random used for security-sensitive token generation
// ruleid: slopguard.cs.insecure-random
public class TokenService
{
    // Unsafe: System.Random is a PRNG seeded from the clock; output is predictable.
    public int GenerateOtp()
    {
        var rng = new Random();
        return rng.Next(100000, 1000000);
    }

    public byte[] GenerateSessionKey()
    {
        var rng = new Random();
        var buf = new byte[32];
        rng.NextBytes(buf);
        return buf;
    }
}
