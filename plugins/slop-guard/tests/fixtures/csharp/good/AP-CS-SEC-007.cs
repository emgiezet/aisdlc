using System.IO;
using System.Xml;

// AP-CS-SEC-007: Safe XML parsing with DTD processing explicitly disabled
// ok: slopguard.cs.xxe-xml
public class SafeFeedParser
{
    // UC-AP-CS-SEC-007-GOOD: XmlReader configured with DtdProcessing.Prohibit and
    // XmlResolver = null provides the parser; doc.Load(XmlReader) receives
    // pre-validated nodes rather than raw XML bytes, so DTD injection cannot
    // occur through the document load path.
    public XmlDocument ParseFeed(string xmlContent)
    {
        var settings = new XmlReaderSettings
        {
            DtdProcessing = DtdProcessing.Prohibit,
            XmlResolver = null
        };
        using var reader = XmlReader.Create(new StringReader(xmlContent), settings);
        var doc = new XmlDocument();
        doc.XmlResolver = null;
        doc.Load(reader);
        return doc;
    }
}

// ok: slopguard.cs.xxe-xml
// UC-AP-CS-SEC-007-GOOD2: XmlDocument with XmlResolver = null set before LoadXml
// neutralises external-entity resolution, so the load is safe even though
// XmlReader is not used. The rule must stay silent here.
public class SafeDirectXmlDocParser
{
    public XmlDocument ParseDirect(string xmlContent)
    {
        var doc = new XmlDocument();
        doc.XmlResolver = null;
        doc.LoadXml(xmlContent);
        return doc;
    }
}
