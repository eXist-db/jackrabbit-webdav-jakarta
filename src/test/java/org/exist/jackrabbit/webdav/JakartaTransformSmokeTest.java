package org.exist.jackrabbit.webdav;

import jakarta.servlet.http.HttpServletRequest;
import org.apache.jackrabbit.webdav.WebdavRequestImpl;
import org.junit.jupiter.api.Test;

import java.io.IOException;
import java.io.InputStream;
import java.lang.reflect.Constructor;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

/**
 * Litmus test that the OpenRewrite Jakarta EE 10 transform produced a linkable
 * artifact: a class that consumes {@code jakarta.servlet} types and contains no
 * surviving {@code javax/servlet} references in its bytecode.
 */
class JakartaTransformSmokeTest {

    @Test
    void webdavRequestImplConsumesJakartaServletApi() {
        Constructor<?>[] ctors = WebdavRequestImpl.class.getConstructors();
        boolean foundJakartaCtor = false;
        for (Constructor<?> ctor : ctors) {
            for (Class<?> param : ctor.getParameterTypes()) {
                if (param.getName().startsWith("jakarta.servlet.")) {
                    foundJakartaCtor = true;
                }
                assertFalse(param.getName().startsWith("javax.servlet."),
                        "Constructor still references javax.servlet: " + ctor);
            }
        }
        assertTrue(foundJakartaCtor,
                "Expected at least one WebdavRequestImpl constructor to accept a jakarta.servlet.* type");
    }

    @Test
    void webdavRequestImplConstructsAgainstJakartaServletStub() {
        HttpServletRequest req = mock(HttpServletRequest.class);
        when(req.getHeader("Host")).thenReturn("localhost");
        when(req.getScheme()).thenReturn("http");
        when(req.getContextPath()).thenReturn("");

        WebdavRequestImpl webdavRequest = new WebdavRequestImpl(req, null);
        assertNotNull(webdavRequest);
    }

    @Test
    void compiledBytecodeContainsNoJavaxServletReferences() throws IOException {
        String resource = "org/apache/jackrabbit/webdav/WebdavRequestImpl.class";
        try (InputStream in = getClass().getClassLoader().getResourceAsStream(resource)) {
            assertNotNull(in, "Could not locate " + resource + " on the test classpath");
            byte[] bytes = in.readAllBytes();
            String asLatin1 = new String(bytes, java.nio.charset.StandardCharsets.ISO_8859_1);
            assertFalse(asLatin1.contains("javax/servlet"),
                    "Compiled bytecode still references javax/servlet — OpenRewrite transform incomplete");
            assertTrue(asLatin1.contains("jakarta/servlet"),
                    "Compiled bytecode missing expected jakarta/servlet references");
        }
    }
}
