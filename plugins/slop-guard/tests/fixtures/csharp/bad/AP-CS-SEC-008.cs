using System.DirectoryServices;

// AP-CS-SEC-008: LDAP filter constructed from user input via string interpolation
// ruleid: slopguard.cs.ldap-injection
public class UserDirectory
{
    // Unsafe: username injected directly into the LDAP filter expression.
    // An attacker can supply ")(uid=*)(" to broaden the query.
    public SearchResult FindUser(string username)
    {
        using var searcher = new DirectorySearcher($"(sAMAccountName={username})");
        return searcher.FindOne();
    }

    public void SetDepartmentFilter(DirectorySearcher searcher, string dept)
    {
        // Unsafe: filter assigned via concatenation allows filter-logic manipulation.
        searcher.Filter = "(department=" + dept + ")";
    }
}
