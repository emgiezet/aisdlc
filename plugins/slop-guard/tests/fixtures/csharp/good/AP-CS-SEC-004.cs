using System;
using System.IO;

// AP-CS-SEC-004: path traversal prevented by canonicalization and base-directory check
// ok: slopguard.cs.path-traversal
public class DocumentReader
{
    private static readonly string BaseDir =
        Path.GetFullPath("uploads") + Path.DirectorySeparatorChar;

    public string GetDocument(string filename)
    {
        // Safe: resolve the full path first and verify it stays inside BaseDir.
        var full = Path.GetFullPath(Path.Combine(BaseDir, filename));
        if (!full.StartsWith(BaseDir, StringComparison.Ordinal))
            throw new ArgumentException("Path traversal detected");
        // Safe: 'full' is a pre-validated variable, not an interpolated or concatenated string.
        return File.ReadAllText(full);
    }

    public void SaveDocument(string filename, string content)
    {
        var full = Path.GetFullPath(Path.Combine(BaseDir, filename));
        if (!full.StartsWith(BaseDir, StringComparison.Ordinal))
            throw new ArgumentException("Path traversal detected");
        File.WriteAllText(full, content);
    }
}
