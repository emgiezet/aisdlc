using System.DirectoryServices;

// AP-CS-SEC-008: LDAP query using a static, pre-defined filter string
// ok: slopguard.cs.ldap-injection
public class UserDirectory
{
    // Filter is a compile-time constant — no user input reaches the LDAP expression.
    private const string EngineersFilter = "(&(objectClass=user)(department=Engineering))";

    // Safe: constructor receives a constant, not an interpolated or concatenated string.
    public SearchResultCollection FindEngineers()
    {
        using var searcher = new DirectorySearcher(EngineersFilter);
        return searcher.FindAll();
    }

    // Safe: Filter property assigned a constant, no runtime string building involved.
    public SearchResult FindAdminAccount()
    {
        using var searcher = new DirectorySearcher();
        searcher.Filter = EngineersFilter;
        return searcher.FindOne();
    }
}
