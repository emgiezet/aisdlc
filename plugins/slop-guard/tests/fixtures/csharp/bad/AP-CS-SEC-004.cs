using System.IO;

// AP-CS-SEC-004: user-controlled filename embedded in interpolated path — path traversal
// ruleid: slopguard.cs.path-traversal
public class DocumentReader
{
    public string GetDocument(string filename)
    {
        // Unsafe: filename from request injected directly into the path string.
        // An attacker can pass "../../etc/passwd" to escape the directory.
        return File.ReadAllText($"uploads/{filename}");
    }

    public void SaveDocument(string filename, string content)
    {
        // Unsafe: same problem on the write path.
        File.WriteAllText($"uploads/{filename}", content);
    }
}
