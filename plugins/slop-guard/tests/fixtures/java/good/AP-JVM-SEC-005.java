import com.fasterxml.jackson.annotation.JsonSubTypes;
import com.fasterxml.jackson.annotation.JsonTypeInfo;
import com.fasterxml.jackson.databind.ObjectMapper;

// ok: slopguard.jvm.jackson-default-typing
// Safe: per-class @JsonTypeInfo with an explicit named-subtype allowlist.
// Does not call enableDefaultTyping(), activateDefaultTyping(), or
// enableDefaultTypingAsProperty() on the mapper; type resolution is
// limited to the annotated hierarchy, not every polymorphic field.
public class JsonService {
    @JsonTypeInfo(use = JsonTypeInfo.Id.NAME, property = "type")
    @JsonSubTypes({
        @JsonSubTypes.Type(value = Dog.class, name = "dog"),
        @JsonSubTypes.Type(value = Cat.class, name = "cat")
    })
    public abstract static class Animal {}
    public static class Dog extends Animal {}
    public static class Cat extends Animal {}

    public ObjectMapper buildMapper() {
        return new ObjectMapper();
    }
}
