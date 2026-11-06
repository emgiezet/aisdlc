using System.Xml;

// AP-CS-SEC-007: XmlResolver re-enabled after null assignment then LoadXml called
// ruleid: slopguard.cs.xxe-xml
public class XmlResolverReenabled
{
    // Unsafe: XmlResolver is initially set to null (looks safe) but then explicitly
    // re-enabled with new XmlUrlResolver() before LoadXml, restoring external-entity
    // resolution and enabling XXE on the attacker-controlled userXml argument.
    public XmlDocument Parse(string userXml)
    {
        var doc = new XmlDocument();
        doc.XmlResolver = null;                  // initially disables resolution...
        doc.XmlResolver = new XmlUrlResolver();  // ...but then re-enables it
        doc.LoadXml(userXml);                    // unsafe: external entities active
        return doc;
    }
}

// ruleid: slopguard.cs.xxe-xml
// UC-AP-CS-SEC-007-REENABLED2: XmlUrlResolver set directly (no prior null) before LoadXml.
public class XmlResolverDirectUnsafe
{
    public XmlDocument ParseDirect(string userXml)
    {
        var doc = new XmlDocument();
        doc.XmlResolver = new XmlUrlResolver();  // resolver enabled — no null guard
        doc.LoadXml(userXml);
        return doc;
    }
}
