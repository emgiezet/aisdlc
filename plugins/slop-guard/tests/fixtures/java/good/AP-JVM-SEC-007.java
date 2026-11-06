import javax.xml.stream.XMLInputFactory;
import javax.xml.stream.XMLStreamReader;
import java.io.InputStream;

// ok: slopguard.jvm.xml-external-entity
// Safe: StAX parser (XMLInputFactory) with external-entity resolution and
// DTD support explicitly disabled.  Does not call
// DocumentBuilderFactory.newInstance() or SAXParserFactory.newInstance(),
// so neither pattern-1 nor pattern-3 of the rule fires.
public class XmlParser {
    public void parse(InputStream xml) throws Exception {
        XMLInputFactory factory = XMLInputFactory.newInstance();
        factory.setProperty(XMLInputFactory.IS_SUPPORTING_EXTERNAL_ENTITIES, Boolean.FALSE);
        factory.setProperty(XMLInputFactory.SUPPORT_DTD, Boolean.FALSE);
        XMLStreamReader reader = factory.createXMLStreamReader(xml);
        while (reader.hasNext()) {
            reader.next();
        }
        reader.close();
    }
}
