using System.Xml;

// AP-CS-SEC-007: XmlDocument loaded without disabling external entity resolution
// ruleid: slopguard.cs.xxe-xml
public class FeedParser
{
    // Unsafe: XmlDocument defaults allow DTD processing and external entities.
    // An attacker can supply XML with an XXE payload to read local files.
    public XmlDocument ParseFeed(string xmlContent)
    {
        var doc = new XmlDocument();
        doc.LoadXml(xmlContent);
        return doc;
    }
}
