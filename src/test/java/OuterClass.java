import java.lang.reflect.Constructor;
import java.lang.reflect.InvocationTargetException;

public class OuterClass {

    private class InnerClass {

    }

    public OuterClass() {
        super();
    }

    public static void main(String[] args) {
        // instantiate outer class
        OuterClass outer = new OuterClass();

        // List all available constructors.
        // We must use the method getDeclaredConstructors() instead
        // of getConstructors() to get also private constructors.
        for (Constructor<?> ctor : OuterClass.InnerClass.class
                .getDeclaredConstructors()) {
            System.out.println(ctor);
        }

        try {
            // Try to get the constructor with the expected signature.
            Constructor<InnerClass> ctor = OuterClass.InnerClass.class
                    .getDeclaredConstructor(OuterClass.class);
            // This forces the security manager to allow a call
            ctor.setAccessible(true);

            // the call
            try {
                OuterClass.InnerClass inner = ctor.newInstance(outer);
                System.out.println(inner);
            } catch (InstantiationException e) {
                // TODO Auto-generated catch block
                e.printStackTrace();
            } catch (IllegalAccessException e) {
                // TODO Auto-generated catch block
                e.printStackTrace();
            } catch (IllegalArgumentException e) {
                // TODO Auto-generated catch block
                e.printStackTrace();
            } catch (InvocationTargetException e) {
                // TODO Auto-generated catch block
                e.printStackTrace();
            }
        } catch (NoSuchMethodException e) {
            // TODO Auto-generated catch block
            e.printStackTrace();
        } catch (SecurityException e) {
            // TODO Auto-generated catch block
            e.printStackTrace();
        }
    }

}