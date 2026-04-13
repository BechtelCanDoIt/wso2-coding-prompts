# WSO2 Enterprise — Java Coding Standard

> **Scope:** All WSO2 Java services and Carbon components across all repositories.
> Based on patterns observed in `carbon-apimgt`, `product-apim`, and `msf4j`.
> Project-specific guides layer on top and win on conflict.

---

## 1. Project and Module Structure

WSO2 Java projects follow a **Maven multi-module** structure. The module hierarchy is deep and consistent.

```
product-root/
├── pom.xml                          # Root parent POM (groupId: org.wso2.*)
├── component/
│   ├── org.wso2.*.feature/          # OSGi P2 feature packaging
│   └── org.wso2.*.impl/             # Core implementation bundle
├── features/                        # P2 feature aggregators
├── distribution/                    # Assembly and distribution modules
└── tests/
    ├── integration/                 # TestNG integration test suites
    └── unit/                        # JUnit/TestNG unit tests
```

### Module Naming
- `groupId`: always `org.wso2.<product>` or `org.wso2.carbon.<component>`
- `artifactId`: mirrors the Java package name — `org.wso2.carbon.apimgt.impl`
- Bundle symbolic names match the `artifactId`
- Never use version numbers in module names — versions belong in the POM

### Maven Best Practices
- All dependency versions are declared in the root parent POM's `<dependencyManagement>` section. Child modules declare dependencies **without versions**.
- Use `maven-bundle-plugin` for all OSGi bundles. Declare `Export-Package`, `Import-Package`, and `Private-Package` explicitly — do not use wildcards in production bundles.

---

## 2. Naming Conventions

| Construct | Convention | Example |
|---|---|---|
| Package | `org.wso2.<product>.<module>` | `org.wso2.carbon.apimgt.impl` |
| Class | `PascalCase` | `APIManagerComponent`, `ApiMgtDAO` |
| Interface | `PascalCase`, no `I` prefix | `APIManager`, `TokenValidator` |
| Abstract class | `Abstract` prefix | `AbstractAPIManager` |
| Implementation class | Name reflects role, not `Impl` suffix unless generated | `APIManagerImpl` (generated), `DefaultAPIManager` (hand-written) |
| Constants class | `<Domain>Constants` | `APIConstants`, `APIManagerConstants` |
| Constant fields | `SCREAMING_SNAKE_CASE` | `API_STATUS_CREATED`, `DEFAULT_PAGE_SIZE` |
| Methods | `camelCase` | `getAPIById`, `validateToken` |
| Test class | `<ClassUnderTest>Test` | `APIConsumerImplTest`, `APIMgtDAOTest` |

### Package Structure Within a Bundle
```
org.wso2.carbon.apimgt.impl/
├── internal/        # OSGi activator, service component registrations
├── dao/             # Data access objects
├── dto/             # Data transfer objects (API ↔ DB mapping)
├── utils/           # Utility classes (static helpers)
├── factory/         # Factory classes
└── APIManagerImpl.java
```

---

## 3. OSGi Component Patterns

WSO2 Java services are deployed as OSGi bundles in a Carbon runtime. Use **Declarative Services (DS)** annotations — not XML files.

### Registering a Service Component

```java
@Component(
    name = "org.wso2.carbon.apimgt.impl.APIManagerComponent",
    immediate = true
)
public class APIManagerComponent {

    private static final Log log = LogFactory.getLog(APIManagerComponent.class);

    @Activate
    protected void activate(ComponentContext context) {
        try {
            // Register services, initialize resources
            context.getBundleContext().registerService(
                APIManager.class.getName(),
                new APIManagerImpl(),
                null
            );
            log.info("API Manager component activated");
        } catch (Exception e) {
            log.error("Failed to activate API Manager component", e);
        }
    }

    @Deactivate
    protected void deactivate(ComponentContext context) {
        log.info("API Manager component deactivated");
    }
}
```

### Consuming a Service via `@Reference`

```java
@Reference(
    name = "api.manager.config.service",
    service = APIManagerConfigurationService.class,
    cardinality = ReferenceCardinality.MANDATORY,
    policy = ReferencePolicy.DYNAMIC,
    unbind = "unsetAPIManagerConfigurationService"
)
protected void setAPIManagerConfigurationService(APIManagerConfigurationService service) {
    ServiceReferenceHolder.getInstance().setAPIManagerConfigurationService(service);
}

protected void unsetAPIManagerConfigurationService(APIManagerConfigurationService service) {
    ServiceReferenceHolder.getInstance().setAPIManagerConfigurationService(null);
}
```

### Rules
- Always provide an `unbind` method for every `@Reference`. Forgetting unbind causes memory leaks in dynamic OSGi environments.
- `@Activate` must be defensive — wrap initialization in `try/catch` and log failures. A component activation failure must not crash the entire runtime.
- Use `ServiceReferenceHolder` (singleton) to make OSGi services available to non-component code, not static fields on the component class itself.
- Prefer `ReferenceCardinality.MANDATORY` and `ReferencePolicy.DYNAMIC` for required services.

---

## 4. Exception Handling

### Custom Exception Hierarchy

WSO2 products define a product-level checked exception as the root of their exception hierarchy:

```
Exception
└── APIManagementException          ← root checked exception for the product
    ├── APIMgtDAOException           ← data layer failures
    ├── APIImportExportException     ← import/export failures
    └── ...
```

### Patterns

```java
// Throw with message and cause — always preserve the cause
throw new APIManagementException("Failed to retrieve API: " + apiId, e);

// Throw typed exception from DAO — let the service layer map to domain exceptions
throw new APIMgtDAOException("SQL error reading API metadata", sqlException);

// Use error codes where the client needs to distinguish failure types
throw new APIManagementException(
    "API quota exceeded",
    ExceptionCodes.API_THROTTLE_OUT
);
```

### REST API Exception Mapping

Never leak `APIManagementException` to the HTTP layer. Use JAX-RS `ExceptionMapper` implementations:

```java
@Provider
public class GlobalThrowableMapper implements ExceptionMapper<Throwable> {
    @Override
    public Response toResponse(Throwable throwable) {
        if (throwable instanceof APIManagementException) {
            APIManagementException e = (APIManagementException) throwable;
            ErrorDTO errorDTO = RestApiUtil.getErrorDTO(e.getErrorHandler());
            return Response.status(e.getErrorHandler().getHttpStatusCode())
                           .entity(errorDTO)
                           .build();
        }
        return Response.status(500)
                       .entity(new ErrorDTO().message("Internal server error"))
                       .build();
    }
}
```

### Rules
- Never swallow exceptions with an empty `catch` block.
- Always log and re-throw, or translate and throw — never both log and throw the same exception (this double-logs).
- Use checked exceptions (`APIManagementException` and subclasses) for recoverable domain failures.
- Use unchecked exceptions (`RuntimeException`) for programming errors and unrecoverable states.

---

## 5. Logging

WSO2 Java services use **Apache Commons Logging** (`org.apache.commons.logging`). Do not use `java.util.logging`, `SLF4J` directly, or `System.out.print`.

```java
import org.apache.commons.logging.Log;
import org.apache.commons.logging.LogFactory;

public class ApiMgtDAO {

    private static final Log log = LogFactory.getLog(ApiMgtDAO.class);

    public API getAPI(String apiId) throws APIMgtDAOException {
        if (log.isDebugEnabled()) {
            log.debug("Retrieving API with ID: " + apiId);
        }
        try {
            // ...
        } catch (SQLException e) {
            log.error("Error retrieving API with ID: " + apiId, e);
            throw new APIMgtDAOException("Error retrieving API", e);
        }
    }
}
```

### Rules
- Declare the logger as `private static final` on every class that logs.
- Wrap `log.debug(...)` calls in `if (log.isDebugEnabled())` when the message involves string concatenation — avoids building the string in production.
- Always pass the `Throwable` as the second argument when logging exceptions: `log.error("message", e)`.
- Never log passwords, tokens, or PII.

---

## 6. REST API Layer (JAX-RS + Apache CXF)

WSO2 REST APIs follow an **OpenAPI-first, code-generated** pattern.

### Workflow
1. Define the API in an OpenAPI 3.0 YAML file (e.g., `publisher-api.yaml`).
2. Generate JAX-RS interfaces and DTO classes using `openapi-generator-maven-plugin`.
3. Implement the generated interface in a `*ApiServiceImpl` class.
4. Register the service in `web.xml` via `CustomCXFNonSpringJaxrsServlet`.

### Service Structure

```java
// Generated interface — do not edit
public interface ApisApi {
    @GET
    @Path("/{apiId}")
    @Produces(MediaType.APPLICATION_JSON)
    Response apisApiIdGet(@PathParam("apiId") String apiId, @Context MessageContext messageContext);
}

// Hand-written implementation
public class ApisApiServiceImpl implements ApisApi {

    @Override
    public Response apisApiIdGet(String apiId, MessageContext messageContext) {
        try {
            APIProvider provider = RestApiUtil.getLoggedInUserProvider();
            API api = provider.getAPIbyUUID(apiId, RestApiUtil.getLoggedInUserTenantDomain());
            APIDTO apiDTO = APIMappingUtil.fromAPItoDTO(api);
            return Response.ok().entity(apiDTO).build();
        } catch (APIManagementException e) {
            String errorMessage = "Error while retrieving API: " + apiId;
            RestApiUtil.handleInternalServerError(errorMessage, e, log);
            return null;
        }
    }
}
```

### CXF Interceptors for Cross-Cutting Concerns

Apply cross-cutting logic (auth, tenant context, correlation ID) via CXF interceptors — not inside service implementations:

```java
// Applied in web.xml or programmatically — ordered by phase
PreAuthenticationInterceptor      // extract token from header
AuthenticationInterceptor         // validate JWT, set security context
PostAuthenticationInterceptor     // rate limiting, quota checks
OrganizationInterceptor           // resolve tenant/org context
```

### Rules
- Generated files must never be edited by hand. Regenerate from the spec.
- All request/response mapping between domain objects and DTOs goes in `*MappingUtil` classes.
- Business logic belongs in the service/manager layer — not in `*ApiServiceImpl`.
- `RestApiUtil.handleInternalServerError(...)` and `RestApiUtil.handleResourceNotFoundError(...)` are the standard error helpers — use them.

---

## 7. DAO / Persistence Layer

WSO2 uses a **DAO pattern** with direct JDBC (not ORM) for the core data layer.

```java
public class ApiMgtDAO {

    // SQL as named constants — never inline SQL strings
    private static final String GET_API_BY_UUID_SQL =
        SQLConstants.GET_API_BY_UUID;

    public API getAPIbyUUID(String uuid, String organization) throws APIMgtDAOException {
        Connection conn = null;
        PreparedStatement ps = null;
        ResultSet rs = null;
        try {
            conn = APIMgtDBUtil.getConnection();
            ps = conn.prepareStatement(GET_API_BY_UUID_SQL);
            ps.setString(1, uuid);
            ps.setString(2, organization);
            rs = ps.executeQuery();
            if (rs.next()) {
                return toAPI(rs);
            }
            return null;
        } catch (SQLException e) {
            throw new APIMgtDAOException("Error retrieving API by UUID: " + uuid, e);
        } finally {
            APIMgtDBUtil.closeAllConnections(ps, conn, rs);
        }
    }
}
```

### Rules
- All SQL queries are constants in a `SQLConstants` class — never inline SQL.
- Always close connections in a `finally` block via `APIMgtDBUtil.closeAllConnections(ps, conn, rs)`.
- Never use ORM (Hibernate, JPA) in Carbon components — JDBC is the WSO2 standard for the core data layer.
- Use `APIMgtDBUtil.getConnection()` — never create connections directly.
- DAO methods throw `APIMgtDAOException` (or product-equivalent), not `SQLException`.

---

## 8. Testing

### Unit Tests

JUnit 4 + PowerMock is the standard for unit testing Carbon components.

```java
@RunWith(PowerMockRunner.class)
@PrepareForTest({ APIManagerFactory.class, ServiceReferenceHolder.class })
public class APIConsumerImplTest {

    @Before
    public void setUp() {
        PowerMockito.mockStatic(APIManagerFactory.class);
        // ...
    }

    @Test
    public void testGetAPIById_success() throws APIManagementException {
        // Arrange
        String apiId = "test-api-id";
        Mockito.when(apiProvider.getAPIbyUUID(apiId, "carbon.super"))
               .thenReturn(mockAPI);

        // Act
        API result = consumer.getAPIById(apiId);

        // Assert
        Assert.assertNotNull(result);
        Assert.assertEquals(apiId, result.getUUID());
    }

    @Test(expected = APIManagementException.class)
    public void testGetAPIById_notFound() throws APIManagementException {
        Mockito.when(apiProvider.getAPIbyUUID(anyString(), anyString()))
               .thenThrow(new APIManagementException("API not found"));
        consumer.getAPIById("non-existent-id");
    }
}
```

### Integration Tests

TestNG + WSO2 Carbon Automation Framework for integration tests:

```java
@Test(groups = "wso2.am", description = "Test API creation and publishing")
public class APICreationTestCase extends APIMIntegrationBaseTest {

    @BeforeClass
    public void init() throws Exception {
        super.init(TestUserMode.SUPER_TENANT_ADMIN);
    }

    @Test
    public void testCreateAPI() throws Exception {
        // Use automation framework clients
        HttpResponse response = restAPIPublisher.addAPI(apiRequest);
        Assert.assertEquals(response.getResponseCode(), 201);
    }
}
```

### Rules
- Unit test location: `src/test/java` within each Maven module.
- Integration tests live in a dedicated `tests/integration/` Maven module.
- Use `Mockito` for interface mocking; use `PowerMock` only when static/final mocking is unavoidable.
- Test method names describe the scenario: `testGetAPIById_notFound`, `testCreateAPI_duplicateName_throwsConflict`.
- Every thrown exception path must have a corresponding test case with `@Test(expected = ...)` or `assertThrows`.

---

## 9. Code Quality

- Code style follows the [WSO2 Java Coding Standards](https://github.com/wso2/code-quality-tools).
- Checkstyle is run in CI — do not suppress rules without justification.
- No unused imports, no raw types, no unchecked cast warnings without `@SuppressWarnings("unchecked")` and a comment.
- Javadoc is required on all public classes and public methods.

```java
/**
 * Retrieves an API by its unique identifier.
 *
 * @param apiId        the UUID of the API
 * @param organization the organization (tenant domain) context
 * @return the API object, or {@code null} if not found
 * @throws APIManagementException if a data access error occurs
 */
public API getAPIbyUUID(String apiId, String organization) throws APIManagementException { ... }
```

---

*WSO2 Java base standard. See project-specific guide for overrides and additions.*
