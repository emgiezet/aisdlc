using System.Diagnostics;

// AP-CS-SEC-003 direct variable FileName — no interpolation/concat needed
// ruleid: slopguard.cs.process-start-user-input
public class DirectRunner
{
    // Unsafe: FileName is taken directly from a caller-supplied variable.
    // An attacker controls which executable is launched.
    public void Execute(string userSuppliedExecutable)
    {
        var psi = new ProcessStartInfo
        {
            FileName = userSuppliedExecutable,
            UseShellExecute = false
        };
        Process.Start(psi);
    }
}
