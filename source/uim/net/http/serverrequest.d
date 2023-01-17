module uim.net.http;

use BadMethodCallException;
import uim.net.core.Configure;
import uim.net.core.exceptions.UIMException;
import uim.net.http.Cookie\CookieCollection;
import uim.net.http.exceptions.MethodNotAllowedException;
import uim.net.utilities.Hash;
use InvalidArgumentException;
use Laminas\Diactoros\PhpInputStream;
use Laminas\Diactoros\Stream;
use Laminas\Diactoros\UploadedFile;
use Psr\Http\messages.IServerRequest;
use Psr\Http\messages.StreamInterface;
use Psr\Http\messages.UploadedFileInterface;
use Psr\Http\messages.UriInterface;

/**
 * A class that helps wrap Request information and particulars about a single request.
 * Provides methods commonly used to introspect on the request headers and request body.
 */
class ServerRequest : IServerRequest
{
    /**
     * Array of parameters parsed from the URL.
     *
     * @var array
     */
    protected $params = [
        "plugin": null,
        "controller": null,
        "action": null,
        "_ext": null,
        "pass": [],
    ];

    /**
     * Array of POST data. Will contain form data as well as uploaded files.
     * In PUT/PATCH/DELETE requests this property will contain the form-urlencoded
     * data.
     *
     * @var object|array|null
     */
    protected $data = null;

    /**
     * Array of query string arguments
     *
     * @var array
     */
    protected $query = null;

    /**
     * Array of cookie data.
     *
     * @var array<string, mixed>
     */
    protected $cookies = null;

    /**
     * Array of environment data.
     *
     * @var array<string, mixed>
     */
    protected _environment = null;

    /**
     * Base URL path.
     */
    protected string $base;

    /**
     * webroot path segment for the request.
     */
    protected string $webroot = "/";

    /**
     * Whether to trust HTTP_X headers set by most load balancers.
     * Only set to true if your application runs behind load balancers/proxies
     * that you control.
     *
     * @var bool
     */
    $trustProxy = false;

    /**
     * Trusted proxies list
     *
     * @var array<string>
     */
    protected $trustedProxies = null;

    /**
     * The built in detectors used with `is()` can be modified with `addDetector()`.
     *
     * There are several ways to specify a detector, see uim.net.http\ServerRequest::addDetector() for the
     * various formats and ways to define detectors.
     *
     * @var array<callable|array>
     */
    protected static _detectors = [
        "get": ["env": "REQUEST_METHOD", "value": "GET"],
        "post": ["env": "REQUEST_METHOD", "value": "POST"],
        "put": ["env": "REQUEST_METHOD", "value": "PUT"],
        "patch": ["env": "REQUEST_METHOD", "value": "PATCH"],
        "delete": ["env": "REQUEST_METHOD", "value": "DELETE"],
        "head": ["env": "REQUEST_METHOD", "value": "HEAD"],
        "options": ["env": "REQUEST_METHOD", "value": "OPTIONS"],
        "ssl": ["env": "HTTPS", "options": [1, "on"]],
        "ajax": ["env": "HTTP_X_REQUESTED_WITH", "value": "XMLHttpRequest"],
        "json": ["accept": ["application/json"], "param": "_ext", "value": "json"],
        "xml": [
            "accept": ["application/xml", "text/xml"],
            "exclude": ["text/html"],
            "param": "_ext",
            "value": "xml",
        ],
    ];

    /**
     * Instance cache for results of is(something) calls
     *
     * @var array<string, bool>
     */
    protected _detectorCache = null;

    /**
     * Request body stream. Contains php://input unless `input` constructor option is used.
     *
     * @var \Psr\Http\messages.StreamInterface
     */
    protected $stream;

    /**
     * Uri instance
     *
     * @var \Psr\Http\messages.UriInterface
     */
    protected $uri;

    /**
     * Instance of a Session object relative to this request
     *
     * var DHTP.Session
     */
    protected $session;

    /**
     * Instance of a FlashMessage object relative to this request
     *
     * var DHTP.FlashMessage
     */
    protected $flash;

    /**
     * Store the additional attributes attached to the request.
     *
     * @var array<string, mixed>
     */
    protected $attributes = null;

    /**
     * A list of properties that emulated by the PSR7 attribute methods.
     *
     * @var array<string>
     */
    protected $emulatedAttributes = ["session", "flash", "webroot", "base", "params", "here"];

    /**
     * Array of Psr\Http\messages.UploadedFileInterface objects.
     *
     * @var array
     */
    protected $uploadedFiles = null;

    /**
     * The HTTP protocol version used.
     *
     */
    protected Nullable!string protocol;

    /**
     * The request target if overridden
     *
     */
    protected Nullable!string requestTarget;

    /**
     * Create a new request object.
     *
     * You can supply the data as either an array or as a string. If you use
     * a string you can only supply the URL for the request. Using an array will
     * let you provide the following keys:
     *
     * - `post` POST data or non query string data
     * - `query` Additional data from the query string.
     * - `files` Uploaded files in a normalized structure, with each leaf an instance of UploadedFileInterface.
     * - `cookies` Cookies for this request.
     * - `environment` _SERVER and _ENV data.
     * - `url` The URL without the base path for the request.
     * - `uri` The PSR7 UriInterface object. If null, one will be created from `url` or `environment`.
     * - `base` The base URL for the request.
     * - `webroot` The webroot directory for the request.
     * - `input` The data that would come from php://input this is useful for simulating
     *   requests with put, patch or delete data.
     * - `session` An instance of a Session object
     *
     * @param array<string, mixed> aConfig An array of request data to create a request with.
     */
    this(Json aConfig = null) {
        aConfig += [
            "params": this.params,
            "query": [],
            "post": [],
            "files": [],
            "cookies": [],
            "environment": [],
            "url": "",
            "uri": null,
            "base": "",
            "webroot": "",
            "input": null,
        ];

        _setConfig(aConfig);
    }

    /**
     * Process the config/settings data into properties.
     *
     * @param array<string, mixed> aConfig The config data to use.
     */
    protected void _setConfig(Json aConfig) {
        if (empty(aConfig["session"])) {
            aConfig["session"] = new Session([
                "cookiePath": aConfig["base"],
            ]);
        }

        if (empty(aConfig["environment"]["REQUEST_METHOD"])) {
            aConfig["environment"]["REQUEST_METHOD"] = "GET";
        }

        this.cookies = aConfig["cookies"];

        if (isset(aConfig["uri"])) {
            if (!aConfig["uri"] instanceof UriInterface) {
                throw new UIMException("The `uri` key must be an instance of " ~ UriInterface::class);
            }
            $uri = aConfig["uri"];
        } else {
            if (aConfig["url"] != "") {
                aConfig = this.processUrlOption(aConfig);
            }
            $uri = ServerRequestFactory::createUri(aConfig["environment"]);
        }

        _environment = aConfig["environment"];

        this.uri = $uri;
        this.base = aConfig["base"];
        this.webroot = aConfig["webroot"];

        if (isset(aConfig["input"])) {
            $stream = new Stream("php://memory", "rw");
            $stream.write(aConfig["input"]);
            $stream.rewind();
        } else {
            $stream = new PhpInputStream();
        }
        this.stream = $stream;

        this.data = aConfig["post"];
        this.uploadedFiles = aConfig["files"];
        this.query = aConfig["query"];
        this.params = aConfig["params"];
        this.session = aConfig["session"];
        this.flash = new FlashMessage(this.session);
    }

    /**
     * Set environment vars based on `url` option to facilitate UriInterface instance generation.
     *
     * `query` option is also updated based on URL"s querystring.
     *
     * @param array<string, mixed> aConfig Config array.
     * @return array<string, mixed> Update config.
     */
    protected array processUrlOption(Json aConfig) {
        if (aConfig["url"][0] != "/") {
            aConfig["url"] = "/" ~ aConfig["url"];
        }

        if (strpos(aConfig["url"], "?") != false) {
            [aConfig["url"], aConfig["environment"]["QUERY_STRING"]] = explode("?", aConfig["url"]);

            parse_str(aConfig["environment"]["QUERY_STRING"], $queryArgs);
            aConfig["query"] += $queryArgs;
        }

        aConfig["environment"]["REQUEST_URI"] = aConfig["url"];

        return aConfig;
    }

    /**
     * Get the content type used in this request.
     *
     */
    Nullable!string contentType() {
        $type = this.getEnv("CONTENT_TYPE");
        if ($type) {
            return $type;
        }

        return this.getEnv("HTTP_CONTENT_TYPE");
    }

    /**
     * Returns the instance of the Session object for this request
     *
     * @return uim.net.http.Session
     */
    function getSession(): Session
    {
        return this.session;
    }

    /**
     * Returns the instance of the FlashMessage object for this request
     *
     * @return uim.net.http.FlashMessage
     */
    function getFlash(): FlashMessage
    {
        return this.flash;
    }

    /**
     * Get the IP the client is using, or says they are using.
     *
     * @return string The client IP.
     */
    string clientIp() {
        if (this.trustProxy && this.getEnv("HTTP_X_FORWARDED_FOR")) {
            $addresses = array_map("trim", explode(",", (string)this.getEnv("HTTP_X_FORWARDED_FOR")));
            $trusted = (count(this.trustedProxies) > 0);
            $n = count($addresses);

            if ($trusted) {
                $trusted = array_diff($addresses, this.trustedProxies);
                $trusted = (count($trusted) == 1);
            }

            if ($trusted) {
                return $addresses[0];
            }

            return $addresses[$n - 1];
        }

        if (this.trustProxy && this.getEnv("HTTP_X_REAL_IP")) {
            $ipaddr = this.getEnv("HTTP_X_REAL_IP");
        } elseif (this.trustProxy && this.getEnv("HTTP_CLIENT_IP")) {
            $ipaddr = this.getEnv("HTTP_CLIENT_IP");
        } else {
            $ipaddr = this.getEnv("REMOTE_ADDR");
        }

        return trim((string)$ipaddr);
    }

    /**
     * register trusted proxies
     *
     * @param array<string> $proxies ips list of trusted proxies
     */
    void setTrustedProxies(array $proxies) {
        this.trustedProxies = $proxies;
        this.trustProxy = true;
        this.uri = this.uri.withScheme(this.scheme());
    }

    /**
     * Get trusted proxies
     *
     * @return array<string>
     */
    string[] getTrustedProxies() {
        return this.trustedProxies;
    }

    /**
     * Returns the referer that referred this request.
     *
     * @param bool $local Attempt to return a local address.
     *   Local addresses do not contain hostnames.
     * @return string|null The referring address for this request or null.
     */
    Nullable!string referer(bool $local = true) {
        $ref = this.getEnv("HTTP_REFERER");

        $base = Configure::read("App.fullBaseUrl") . this.webroot;
        if (!empty($ref) && !empty($base)) {
            if ($local && strpos($ref, $base) == 0) {
                $ref = substr($ref, strlen($base));
                if ($ref == "" || strpos($ref, "//") == 0) {
                    $ref = "/";
                }
                if ($ref[0] != "/") {
                    $ref = "/" ~ $ref;
                }

                return $ref;
            }
            if (!$local) {
                return $ref;
            }
        }

        return null;
    }

    /**
     * Missing method handler, handles wrapping older style isAjax() type methods
     *
     * @param string aName The method called
     * @param array $params Array of parameters for the method call
     * @return bool
     * @throws \BadMethodCallException when an invalid method is called.
     */
    function __call(string aName, array $params) {
        if (strpos($name, "is") == 0) {
            $type = strtolower(substr($name, 2));

            array_unshift($params, $type);

            return this.is(...$params);
        }
        throw new BadMethodCallException(sprintf("Method "%s()" does not exist", $name));
    }

    /**
     * Check whether a Request is a certain type.
     *
     * Uses the built-in detection rules as well as additional rules
     * defined with {@link uim.net.http\ServerRequest::addDetector()}. Any detector can be called
     * as `is($type)` or `is$Type()`.
     *
     * @param array<string>|string $type The type of request you want to check. If an array
     *   this method will return true if the request matches any type.
     * @param mixed ...$args List of arguments
     * @return bool Whether the request is the type you are checking.
     */
    bool is($type, ...$args) {
        if (is_array($type)) {
            foreach ($type as _type) {
                if (this.is(_type)) {
                    return true;
                }
            }

            return false;
        }

        $type = strtolower($type);
        if (!isset(static::_detectors[$type])) {
            return false;
        }
        if ($args) {
            return _is($type, $args);
        }

        return _detectorCache[$type] = _detectorCache[$type] ?? _is($type, $args);
    }

    /**
     * Clears the instance detector cache, used by the is() function
     */
    void clearDetectorCache() {
        _detectorCache = null;
    }

    /**
     * Worker for the is() function
     *
     * @param string $type The type of request you want to check.
     * @param array $args Array of custom detector arguments.
     * @return bool Whether the request is the type you are checking.
     */
    protected bool _is(string $type, array $args) {
        $detect = static::_detectors[$type];
        if (is_callable($detect)) {
            array_unshift($args, this);

            return $detect(...$args);
        }
        if (isset($detect["env"]) && _environmentDetector($detect)) {
            return true;
        }
        if (isset($detect["header"]) && _headerDetector($detect)) {
            return true;
        }
        if (isset($detect["accept"]) && _acceptHeaderDetector($detect)) {
            return true;
        }
        if (isset($detect["param"]) && _paramDetector($detect)) {
            return true;
        }

        return false;
    }

    /**
     * Detects if a specific accept header is present.
     *
     * @param array $detect Detector options array.
     * @return bool Whether the request is the type you are checking.
     */
    protected bool _acceptHeaderDetector(array $detect) {
        $content = new ContentTypeNegotiation();
        $options = $detect["accept"];

        // Some detectors overlap with the default browser Accept header
        // For these types we use an exclude list to refine our content type
        // detection.
        $exclude = $detect["exclude"] ?? null;
        if ($exclude) {
            $options = array_merge($options, $exclude);
        }

        $accepted = $content.preferredType(this, $options);
        if ($accepted == null) {
            return false;
        }
        if ($exclude && hasAllValues($accepted, $exclude, true)) {
            return false;
        }

        return true;
    }

    /**
     * Detects if a specific header is present.
     *
     * @param array $detect Detector options array.
     * @return bool Whether the request is the type you are checking.
     */
    protected bool _headerDetector(array $detect) {
        foreach ($detect["header"] as $header: $value) {
            $header = this.getEnv("http_" ~ $header);
            if ($header != null) {
                if (!is_string($value) && !is_bool($value) && is_callable($value)) {
                    return $value($header);
                }

                return $header == $value;
            }
        }

        return false;
    }

    /**
     * Detects if a specific request parameter is present.
     *
     * @param array $detect Detector options array.
     * @return bool Whether the request is the type you are checking.
     */
    protected bool _paramDetector(array $detect) {
        $key = $detect["param"];
        if (isset($detect["value"])) {
            $value = $detect["value"];

            return isset(this.params[$key]) ? this.params[$key] == $value : false;
        }
        if (isset($detect["options"])) {
            return isset(this.params[$key]) ? hasAllValues(this.params[$key], $detect["options"]) : false;
        }

        return false;
    }

    /**
     * Detects if a specific environment variable is present.
     *
     * @param array $detect Detector options array.
     * @return bool Whether the request is the type you are checking.
     */
    protected bool _environmentDetector(array $detect) {
        if (isset($detect["env"])) {
            if (isset($detect["value"])) {
                return this.getEnv($detect["env"]) == $detect["value"];
            }
            if (isset($detect["pattern"])) {
                return (bool)preg_match($detect["pattern"], (string)this.getEnv($detect["env"]));
            }
            if (isset($detect["options"])) {
                $pattern = "/" ~ implode("|", $detect["options"]) ~ "/i";

                return (bool)preg_match($pattern, (string)this.getEnv($detect["env"]));
            }
        }

        return false;
    }

    /**
     * Check that a request matches all the given types.
     *
     * Allows you to test multiple types and union the results.
     * See Request::is() for how to add additional types and the
     * built-in types.
     *
     * @param array<string> $types The types to check.
     * @return bool Success.
     * @see uim.net.http.ServerRequest::is()
     */
    bool isAll(array $types) {
        foreach ($types as $type) {
            if (!this.is($type)) {
                return false;
            }
        }

        return true;
    }

    /**
     * Add a new detector to the list of detectors that a request can use.
     * There are several different types of detectors that can be set.
     *
     * ### Callback comparison
     *
     * Callback detectors allow you to provide a callable to handle the check.
     * The callback will receive the request object as its only parameter.
     *
     * ```
     * addDetector("custom", function ($request) { //Return a boolean });
     * ```
     *
     * ### Environment value comparison
     *
     * An environment value comparison, compares a value fetched from `env()` to a known value
     * the environment value is equality checked against the provided value.
     *
     * ```
     * addDetector("post", ["env": "REQUEST_METHOD", "value": "POST"]);
     * ```
     *
     * ### Request parameter comparison
     *
     * Allows for custom detectors on the request parameters.
     *
     * ```
     * addDetector("admin", ["param": "prefix", "value": "admin"]);
     * ```
     *
     * ### Accept comparison
     *
     * Allows for detector to compare against Accept header value.
     *
     * ```
     * addDetector("csv", ["accept": "text/csv"]);
     * ```
     *
     * ### Header comparison
     *
     * Allows for one or more headers to be compared.
     *
     * ```
     * addDetector("fancy", ["header": ["X-Fancy": 1]);
     * ```
     *
     * The `param`, `env` and comparison types allow the following
     * value comparison options:
     *
     * ### Pattern value comparison
     *
     * Pattern value comparison allows you to compare a value fetched from `env()` to a regular expression.
     *
     * ```
     * addDetector("iphone", ["env": "HTTP_USER_AGENT", "pattern": "/iPhone/i"]);
     * ```
     *
     * ### Option based comparison
     *
     * Option based comparisons use a list of options to create a regular expression. Subsequent calls
     * to add an already defined options detector will merge the options.
     *
     * ```
     * addDetector("mobile", ["env": "HTTP_USER_AGENT", "options": ["Fennec"]]);
     * ```
     *
     * You can also make compare against multiple values
     * using the `options` key. This is useful when you want to check
     * if a request value is in a list of options.
     *
     * `addDetector("extension", ["param": "_ext", "options": ["pdf", "csv"]]`
     *
     * @param string aName The name of the detector.
     * @param callable|array $detector A callable or options array for the detector definition.
     */
    static void addDetector(string aName, $detector) {
        $name = strtolower($name);
        if (is_callable($detector)) {
            static::_detectors[$name] = $detector;

            return;
        }
        if (isset(static::_detectors[$name], $detector["options"])) {
            /** @psalm-suppress PossiblyInvalidArgument */
            $detector = Hash::merge(static::_detectors[$name], $detector);
        }
        static::_detectors[$name] = $detector;
    }

    /**
     * Normalize a header name into the SERVER version.
     *
     * @param string aName The header name.
     * @return string The normalized header name.
     */
    protected string normalizeHeaderName(string aName) {
        $name = replace("-", "_", ($name).toUpper);
        if (!hasAllValues($name, ["CONTENT_LENGTH", "CONTENT_TYPE"], true)) {
            $name = "HTTP_" ~ $name;
        }

        return $name;
    }

    /**
     * Get all headers in the request.
     *
     * Returns an associative array where the header names are
     * the keys and the values are a list of header values.
     *
     * While header names are not case-sensitive, getHeaders() will normalize
     * the headers.
     *
     * @return array<string[]> An associative array of headers and their values.
     * @link https://www.php-fig.org/psr/psr-7/ This method is part of the PSR-7 server request interface.
     */
    array getHeaders() {
        $headers = null;
        foreach (_environment as $key: $value) {
            $name = null;
            if (strpos($key, "HTTP_") == 0) {
                $name = substr($key, 5);
            }
            if (strpos($key, "CONTENT_") == 0) {
                $name = $key;
            }
            if ($name != null) {
                $name = replace("_", " ", strtolower($name));
                $name = replace(" ", "-", ucwords($name));
                $headers[$name] = (array)$value;
            }
        }

        return $headers;
    }

    /**
     * Check if a header is set in the request.
     *
     * @param string aName The header you want to get (case-insensitive)
     * @return bool Whether the header is defined.
     * @link https://www.php-fig.org/psr/psr-7/ This method is part of the PSR-7 server request interface.
     */
    bool hasHeader($name) {
        $name = this.normalizeHeaderName($name);

        return isset(_environment[$name]);
    }

    /**
     * Get a single header from the request.
     *
     * Return the header value as an array. If the header
     * is not present an empty array will be returned.
     *
     * @param string aName The header you want to get (case-insensitive)
     * @return array<string> An associative array of headers and their values.
     *   If the header doesn"t exist, an empty array will be returned.
     * @link https://www.php-fig.org/psr/psr-7/ This method is part of the PSR-7 server request interface.
     */
    string[] getHeader($name) {
        $name = this.normalizeHeaderName($name);
        if (isset(_environment[$name])) {
            return (array)_environment[$name];
        }

        return [];
    }

    /**
     * Get a single header as a string from the request.
     *
     * @param string aName The header you want to get (case-insensitive)
     * @return string Header values collapsed into a comma separated string.
     * @link https://www.php-fig.org/psr/psr-7/ This method is part of the PSR-7 server request interface.
     */
    string getHeaderLine($name) {
        $value = this.getHeader($name);

        return implode(", ", $value);
    }

    /**
     * Get a modified request with the provided header.
     *
     * @param string aName The header name.
     * @param array|string aValue The header value
     * @return static
     * @link https://www.php-fig.org/psr/psr-7/ This method is part of the PSR-7 server request interface.
     */
    function withHeader($name, $value) {
        $new = clone this;
        $name = this.normalizeHeaderName($name);
        $new._environment[$name] = $value;

        return $new;
    }

    /**
     * Get a modified request with the provided header.
     *
     * Existing header values will be retained. The provided value
     * will be appended into the existing values.
     *
     * @param string aName The header name.
     * @param array|string aValue The header value
     * @return static
     * @link https://www.php-fig.org/psr/psr-7/ This method is part of the PSR-7 server request interface.
     */
    function withAddedHeader($name, $value) {
        $new = clone this;
        $name = this.normalizeHeaderName($name);
        $existing = null;
        if (isset($new._environment[$name])) {
            $existing = (array)$new._environment[$name];
        }
        $existing = array_merge($existing, (array)$value);
        $new._environment[$name] = $existing;

        return $new;
    }

    /**
     * Get a modified request without a provided header.
     *
     * @param string aName The header name to remove.
     * @return static
     * @link https://www.php-fig.org/psr/psr-7/ This method is part of the PSR-7 server request interface.
     */
    function withoutHeader($name) {
        $new = clone this;
        $name = this.normalizeHeaderName($name);
        unset($new._environment[$name]);

        return $new;
    }

    /**
     * Get the HTTP method used for this request.
     * There are a few ways to specify a method.
     *
     * - If your client supports it you can use native HTTP methods.
     * - You can set the HTTP-X-Method-Override header.
     * - You can submit an input with the name `_method`
     *
     * Any of these 3 approaches can be used to set the HTTP method used
     * by UIM internally, and will effect the result of this method.
     *
     * @return string The name of the HTTP method used.
     * @link https://www.php-fig.org/psr/psr-7/ This method is part of the PSR-7 server request interface.
     */
    string getMethod() {
        return (string)this.getEnv("REQUEST_METHOD");
    }

    /**
     * Update the request method and get a new instance.
     *
     * @param string $method The HTTP method to use.
     * @return static A new instance with the updated method.
     * @link https://www.php-fig.org/psr/psr-7/ This method is part of the PSR-7 server request interface.
     */
    function withMethod($method) {
        $new = clone this;

        if (
            !is_string($method) ||
            !preg_match("/^[!#$%&\"*+.^_`\|~0-9a-z-]+$/i", $method)
        ) {
            throw new InvalidArgumentException(sprintf(
                "Unsupported HTTP method '%s' provided",
                $method
            ));
        }
        $new._environment["REQUEST_METHOD"] = $method;

        return $new;
    }

    /**
     * Get all the server environment parameters.
     *
     * Read all of the "environment" or "server" data that was
     * used to create this request.
     *
     * @return array
     * @link https://www.php-fig.org/psr/psr-7/ This method is part of the PSR-7 server request interface.
     */
    array getServerParams() {
        return _environment;
    }

    /**
     * Get all the query parameters in accordance to the PSR-7 specifications. To read specific query values
     * use the alternative getQuery() method.
     *
     * @return array
     * @link https://www.php-fig.org/psr/psr-7/ This method is part of the PSR-7 server request interface.
     */
    array getQueryParams() {
        return this.query;
    }

    /**
     * Update the query string data and get a new instance.
     *
     * @param array $query The query string data to use
     * @return static A new instance with the updated query string data.
     * @link https://www.php-fig.org/psr/psr-7/ This method is part of the PSR-7 server request interface.
     */
    function withQueryParams(array $query) {
        $new = clone this;
        $new.query = $query;

        return $new;
    }

    /**
     * Get the host that the request was handled on.
     *
     */
    Nullable!string host() {
        if (this.trustProxy && this.getEnv("HTTP_X_FORWARDED_HOST")) {
            return this.getEnv("HTTP_X_FORWARDED_HOST");
        }

        return this.getEnv("HTTP_HOST");
    }

    /**
     * Get the port the request was handled on.
     *
     */
    Nullable!string port() {
        if (this.trustProxy && this.getEnv("HTTP_X_FORWARDED_PORT")) {
            return this.getEnv("HTTP_X_FORWARDED_PORT");
        }

        return this.getEnv("SERVER_PORT");
    }

    /**
     * Get the current url scheme used for the request.
     *
     * e.g~ "http", or "https"
     *
     * @return string|null The scheme used for the request.
     */
    Nullable!string scheme() {
        if (this.trustProxy && this.getEnv("HTTP_X_FORWARDED_PROTO")) {
            return this.getEnv("HTTP_X_FORWARDED_PROTO");
        }

        return this.getEnv("HTTPS") ? "https" : "http";
    }

    /**
     * Get the domain name and include $tldLength segments of the tld.
     *
     * @param int $tldLength Number of segments your tld contains. For example: `example.com` contains 1 tld.
     *   While `example.co.uk` contains 2.
     * @return string Domain name without subdomains.
     */
    string domain(int $tldLength = 1) {
        $host = this.host();
        if (empty($host)) {
            return "";
        }

        $segments = explode(".", $host);
        $domain = array_slice($segments, -1 * ($tldLength + 1));

        return implode(".", $domain);
    }

    /**
     * Get the subdomains for a host.
     *
     * @param int $tldLength Number of segments your tld contains. For example: `example.com` contains 1 tld.
     *   While `example.co.uk` contains 2.
     * @return array<string> An array of subdomains.
     */
    string[] subdomains(int $tldLength = 1) {
        $host = this.host();
        if (empty($host)) {
            return [];
        }

        $segments = explode(".", $host);

        return array_slice($segments, 0, -1 * ($tldLength + 1));
    }

    /**
     * Find out which content types the client accepts or check if they accept a
     * particular type of content.
     *
     * #### Get all types:
     *
     * ```
     * this.request.accepts();
     * ```
     *
     * #### Check for a single type:
     *
     * ```
     * this.request.accepts("application/json");
     * ```
     *
     * This method will order the returned content types by the preference values indicated
     * by the client.
     *
     * @param string|null $type The content type to check for. Leave null to get all types a client accepts.
     * @return array<string>|bool Either an array of all the types the client accepts or a boolean if they accept the
     *   provided type.
     */
    string[] accepts(Nullable!string $type = null) {
        $content = new ContentTypeNegotiation();
        if ($type) {
            return $content.preferredType(this, [$type]) != null;
        }

        $accept = null;
        foreach ($content.parseAccept(this) as $types) {
            $accept = array_merge($accept, $types);
        }

        return $accept;
    }

    /**
     * Parse the HTTP_ACCEPT header and return a sorted array with content types
     * as the keys, and pref values as the values.
     *
     * Generally you want to use {@link uim.net.http\ServerRequest::accepts()} to get a simple list
     * of the accepted content types.
     *
     * @return array An array of `prefValue: [content/types]`
     * @deprecated 4.4.0 Use `accepts()` or `ContentTypeNegotiation` class instead.
     */
    array parseAccept() {
        return (new ContentTypeNegotiation()).parseAccept(this);
    }

    /**
     * Get the languages accepted by the client, or check if a specific language is accepted.
     *
     * Get the list of accepted languages:
     *
     * ```$request.acceptLanguage();```
     *
     * Check if a specific language is accepted:
     *
     * ```$request.acceptLanguage("es-es");```
     *
     * @param string|null $language The language to test.
     * @return array|bool If a $language is provided, a boolean. Otherwise, the array of accepted languages.
     */
    function acceptLanguage(Nullable!string $language = null) {
        $content = new ContentTypeNegotiation();
        if ($language != null) {
            return $content.acceptLanguage(this, $language);
        }

        return $content.acceptedLanguages(this);
    }

    /**
     * Read a specific query value or dotted path.
     *
     * Developers are encouraged to use getQueryParams() if they need the whole query array,
     * as it is PSR-7 compliant, and this method is not. Using Hash::get() you can also get single params.
     *
     * ### PSR-7 Alternative
     *
     * ```
     * $value = Hash::get($request.getQueryParams(), "Post.id");
     * ```
     *
     * @param string|null $name The name or dotted path to the query param or null to read all.
     * @param mixed $default The default value if the named parameter is not set, and $name is not null.
     * @return array|string|null Query data.
     * @see ServerRequest::getQueryParams()
     */
    function getQuery(Nullable!string aName = null, $default = null) {
        if ($name == null) {
            return this.query;
        }

        return Hash::get(this.query, $name, $default);
    }

    /**
     * Provides a safe accessor for request data. Allows
     * you to use Hash::get() compatible paths.
     *
     * ### Reading values.
     *
     * ```
     * // get all data
     * $request.getData();
     *
     * // Read a specific field.
     * $request.getData("Post.title");
     *
     * // With a default value.
     * $request.getData("Post.not there", "default value");
     * ```
     *
     * When reading values you will get `null` for keys/values that do not exist.
     *
     * Developers are encouraged to use getParsedBody() if they need the whole data array,
     * as it is PSR-7 compliant, and this method is not. Using Hash::get() you can also get single params.
     *
     * ### PSR-7 Alternative
     *
     * ```
     * $value = Hash::get($request.getParsedBody(), "Post.id");
     * ```
     *
     * @param string|null $name Dot separated name of the value to read. Or null to read all data.
     * @param mixed $default The default data.
     * @return mixed The value being read.
     */
    function getData(Nullable!string aName = null, $default = null) {
        if ($name == null) {
            return this.data;
        }
        if (!is_array(this.data) && $name) {
            return $default;
        }

        /** @psalm-suppress PossiblyNullArgument */
        return Hash::get(this.data, $name, $default);
    }

    /**
     * Read data from `php://input`. Useful when interacting with XML or JSON
     * request body content.
     *
     * Getting input with a decoding function:
     *
     * ```
     * this.request.input("json_decode");
     * ```
     *
     * Getting input using a decoding function, and additional params:
     *
     * ```
     * this.request.input("Xml::build", ["return": "DOMDocument"]);
     * ```
     *
     * Any additional parameters are applied to the callback in the order they are given.
     *
     * @deprecated 4.1.0 Use `(string)$request.getBody()` to get the raw PHP input
     *  as string; use `BodyParserMiddleware` to parse the request body so that it"s
     *  available as array/object through `$request.getParsedBody()`.
     * @param callable|null $callback A decoding callback that will convert the string data to another
     *     representation. Leave empty to access the raw input data. You can also
     *     supply additional parameters for the decoding callback using var args, see above.
     * @param mixed ...$args The additional arguments
     * @return mixed The decoded/processed request data.
     */
    function input(?callable $callback = null, ...$args) {
        deprecationWarning(
            "Use `(string)$request.getBody()` to get the raw PHP input as string; "
            ~ "use `BodyParserMiddleware` to parse the request body so that it\"s available as array/object "
            ~ "through $request.getParsedBody()"
        );
        this.stream.rewind();
        $input = this.stream.getContents();
        if ($callback) {
            array_unshift($args, $input);

            return $callback(...$args);
        }

        return $input;
    }

    /**
     * Read cookie data from the request"s cookie data.
     *
     * @param string aKey The key or dotted path you want to read.
     * @param array|string|null $default The default value if the cookie is not set.
     * @return array|string|null Either the cookie value, or null if the value doesn"t exist.
     */
    function getCookie(string aKey, $default = null) {
        return Hash::get(this.cookies, $key, $default);
    }

    /**
     * Get a cookie collection based on the request"s cookies
     *
     * The CookieCollection lets you interact with request cookies using
     * `uim.net.http\Cookie\Cookie` objects and can make converting request cookies
     * into response cookies easier.
     *
     * This method will create a new cookie collection each time it is called.
     * This is an optimization that allows fewer objects to be allocated until
     * the more complex CookieCollection is needed. In general you should prefer
     * `getCookie()` and `getCookieParams()` over this method. Using a CookieCollection
     * is ideal if your cookies contain complex JSON encoded data.
     *
     * @return uim.net.http.Cookie\CookieCollection
     */
    function getCookieCollection(): CookieCollection
    {
        return CookieCollection::createFromServerRequest(this);
    }

    /**
     * Replace the cookies in the request with those contained in
     * the provided CookieCollection.
     *
     * @param uim.net.http.Cookie\CookieCollection $cookies The cookie collection
     * @return static
     */
    function withCookieCollection(CookieCollection $cookies) {
        $new = clone this;
        $values = null;
        foreach ($cookies as $cookie) {
            $values[$cookie.getName()] = $cookie.getValue();
        }
        $new.cookies = $values;

        return $new;
    }

    /**
     * Get all the cookie data from the request.
     *
     * @return array<string, mixed> An array of cookie data.
     */
    array getCookieParams() {
        return this.cookies;
    }

    /**
     * Replace the cookies and get a new request instance.
     *
     * @param array $cookies The new cookie data to use.
     * @return static
     */
    function withCookieParams(array $cookies) {
        $new = clone this;
        $new.cookies = $cookies;

        return $new;
    }

    /**
     * Get the parsed request body data.
     *
     * If the request Content-Type is either application/x-www-form-urlencoded
     * or multipart/form-data, and the request method is POST, this will be the
     * post data. For other content types, it may be the deserialized request
     * body.
     *
     * @return object|array|null The deserialized body parameters, if any.
     *     These will typically be an array.
     */
    function getParsedBody() {
        return this.data;
    }

    /**
     * Update the parsed body and get a new instance.
     *
     * @param object|array|null $data The deserialized body data. This will
     *     typically be in an array or object.
     * @return static
     */
    function withParsedBody($data) {
        $new = clone this;
        $new.data = $data;

        return $new;
    }

    /**
     * Retrieves the HTTP protocol version as a string.
     *
     * @return string HTTP protocol version.
     */
    string getProtocolVersion() {
        if (this.protocol) {
            return this.protocol;
        }

        // Lazily populate this data as it is generally not used.
        preg_match("/^HTTP\/([\d.]+)$/", (string)this.getEnv("SERVER_PROTOCOL"), $match);
        $protocol = "1.1";
        if (isset($match[1])) {
            $protocol = $match[1];
        }
        this.protocol = $protocol;

        return this.protocol;
    }

    /**
     * Return an instance with the specified HTTP protocol version.
     *
     * The version string MUST contain only the HTTP version number (e.g.,
     * "1.1", "1.0").
     *
     * @param string $version HTTP protocol version
     * @return static
     */
    function withProtocolVersion($version) {
        if (!preg_match("/^(1\.[01]|2)$/", $version)) {
            throw new InvalidArgumentException("Unsupported protocol version "{$version}" provided");
        }
        $new = clone this;
        $new.protocol = $version;

        return $new;
    }

    /**
     * Get a value from the request"s environment data.
     * Fallback to using env() if the key is not set in the $environment property.
     *
     * @param string aKey The key you want to read from.
     * @param string|null $default Default value when trying to retrieve an environment
     *   variable"s value that does not exist.
     * @return string|null Either the environment value, or null if the value doesn"t exist.
     */
    Nullable!string getEnv(string aKey, Nullable!string $default = null) {
        $key = ($key).toUpper;
        if (!array_key_exists($key, _environment)) {
            _environment[$key] = env($key);
        }

        return _environment[$key] != null ? (string)_environment[$key] : $default;
    }

    /**
     * Update the request with a new environment data element.
     *
     * Returns an updated request object. This method returns
     * a *new* request object and does not mutate the request in-place.
     *
     * @param string aKey The key you want to write to.
     * @param string aValue Value to set
     * @return static
     */
    function withEnv(string aKey, string aValue) {
        $new = clone this;
        $new._environment[$key] = $value;
        $new.clearDetectorCache();

        return $new;
    }

    /**
     * Allow only certain HTTP request methods, if the request method does not match
     * a 405 error will be shown and the required "Allow" response header will be set.
     *
     * Example:
     *
     * this.request.allowMethod("post");
     * or
     * this.request.allowMethod(["post", "delete"]);
     *
     * If the request would be GET, response header "Allow: POST, DELETE" will be set
     * and a 405 error will be returned.
     *
     * @param array<string>|string $methods Allowed HTTP request methods.
     * @return true
     * @throws uim.net.http.exceptions.MethodNotAllowedException
     */
    bool allowMethod($methods) {
        $methods = (array)$methods;
        foreach ($methods as $method) {
            if (this.is($method)) {
                return true;
            }
        }
        $allowed = (implode(", ", $methods)).toUpper;
        $e = new MethodNotAllowedException();
        $e.setHeader("Allow", $allowed);
        throw $e;
    }

    /**
     * Update the request with a new request data element.
     *
     * Returns an updated request object. This method returns
     * a *new* request object and does not mutate the request in-place.
     *
     * Use `withParsedBody()` if you need to replace the all request data.
     *
     * @param string aName The dot separated path to insert $value at.
     * @param mixed $value The value to insert into the request data.
     * @return static
     */
    function withData(string aName, $value) {
        $copy = clone this;

        if (is_array($copy.data)) {
            $copy.data = Hash::insert($copy.data, $name, $value);
        }

        return $copy;
    }

    /**
     * Update the request removing a data element.
     *
     * Returns an updated request object. This method returns
     * a *new* request object and does not mutate the request in-place.
     *
     * @param string aName The dot separated path to remove.
     * @return static
     */
    function withoutData(string aName) {
        $copy = clone this;

        if (is_array($copy.data)) {
            $copy.data = Hash::remove($copy.data, $name);
        }

        return $copy;
    }

    /**
     * Update the request with a new routing parameter
     *
     * Returns an updated request object. This method returns
     * a *new* request object and does not mutate the request in-place.
     *
     * @param string aName The dot separated path to insert $value at.
     * @param mixed $value The value to insert into the the request parameters.
     * @return static
     */
    function withParam(string aName, $value) {
        $copy = clone this;
        $copy.params = Hash::insert($copy.params, $name, $value);

        return $copy;
    }

    /**
     * Safely access the values in this.params.
     *
     * @param string aName The name or dotted path to parameter.
     * @param mixed $default The default value if `$name` is not set. Default `null`.
     * @return mixed
     */
    function getParam(string aName, $default = null) {
        return Hash::get(this.params, $name, $default);
    }

    /**
     * Return an instance with the specified request attribute.
     *
     * @param string aName The attribute name.
     * @param mixed $value The value of the attribute.
     * @return static
     */
    function withAttribute($name, $value) {
        $new = clone this;
        if (hasAllValues($name, this.emulatedAttributes, true)) {
            $new.{$name} = $value;
        } else {
            $new.attributes[$name] = $value;
        }

        return $new;
    }

    /**
     * Return an instance without the specified request attribute.
     *
     * @param string aName The attribute name.
     * @return static
     * @throws \InvalidArgumentException
     */
    function withoutAttribute($name) {
        $new = clone this;
        if (hasAllValues($name, this.emulatedAttributes, true)) {
            throw new InvalidArgumentException(
                "You cannot unset "$name". It is a required UIM attribute."
            );
        }
        unset($new.attributes[$name]);

        return $new;
    }

    /**
     * Read an attribute from the request, or get the default
     *
     * @param string aName The attribute name.
     * @param mixed|null $default The default value if the attribute has not been set.
     * @return mixed
     */
    function getAttribute($name, $default = null) {
        if (hasAllValues($name, this.emulatedAttributes, true)) {
            if ($name == "here") {
                return this.base . this.uri.getPath();
            }

            return this.{$name};
        }
        if (array_key_exists($name, this.attributes)) {
            return this.attributes[$name];
        }

        return $default;
    }

    /**
     * Get all the attributes in the request.
     *
     * This will include the params, webroot, base, and here attributes that UIM
     * provides.
     *
     * @return array<string, mixed>
     */
    array getAttributes() {
        $emulated = [
            "params": this.params,
            "webroot": this.webroot,
            "base": this.base,
            "here": this.base . this.uri.getPath(),
        ];

        return this.attributes + $emulated;
    }

    /**
     * Get the uploaded file from a dotted path.
     *
     * @param string $path The dot separated path to the file you want.
     * @return \Psr\Http\messages.UploadedFileInterface|null
     */
    function getUploadedFile(string $path): ?UploadedFileInterface
    {
        $file = Hash::get(this.uploadedFiles, $path);
        if (!$file instanceof UploadedFile) {
            return null;
        }

        return $file;
    }

    /**
     * Get the array of uploaded files from the request.
     */
    array getUploadedFiles() {
        return this.uploadedFiles;
    }

    /**
     * Update the request replacing the files, and creating a new instance.
     *
     * @param array $uploadedFiles An array of uploaded file objects.
     * @return static
     * @throws \InvalidArgumentException when $files contains an invalid object.
     */
    function withUploadedFiles(array $uploadedFiles) {
        this.validateUploadedFiles($uploadedFiles, "");
        $new = clone this;
        $new.uploadedFiles = $uploadedFiles;

        return $new;
    }

    /**
     * Recursively validate uploaded file data.
     *
     * @param array $uploadedFiles The new files array to validate.
     * @param string $path The path thus far.
     * @return void
     * @throws \InvalidArgumentException If any leaf elements are not valid files.
     */
    protected void validateUploadedFiles(array $uploadedFiles, string $path) {
        foreach ($uploadedFiles as $key: $file) {
            if (is_array($file)) {
                this.validateUploadedFiles($file, $key ~ ".");
                continue;
            }

            if (!$file instanceof UploadedFileInterface) {
                throw new InvalidArgumentException("Invalid file at "{$path}{$key}"");
            }
        }
    }

    /**
     * Gets the body of the message.
     *
     * @return \Psr\Http\messages.StreamInterface Returns the body as a stream.
     */
    function getBody(): StreamInterface
    {
        return this.stream;
    }

    /**
     * Return an instance with the specified message body.
     *
     * @param \Psr\Http\messages.StreamInterface $body The new request body
     * @return static
     */
    function withBody(StreamInterface $body) {
        $new = clone this;
        $new.stream = $body;

        return $new;
    }

    /**
     * Retrieves the URI instance.
     *
     * @return \Psr\Http\messages.UriInterface Returns a UriInterface instance
     *   representing the URI of the request.
     */
    function getUri(): UriInterface
    {
        return this.uri;
    }

    /**
     * Return an instance with the specified uri
     *
     * *Warning* Replacing the Uri will not update the `base`, `webroot`,
     * and `url` attributes.
     *
     * @param \Psr\Http\messages.UriInterface $uri The new request uri
     * @param bool $preserveHost Whether the host should be retained.
     * @return static
     */
    function withUri(UriInterface $uri, $preserveHost = false) {
        $new = clone this;
        $new.uri = $uri;

        if ($preserveHost && this.hasHeader("Host")) {
            return $new;
        }

        $host = $uri.getHost();
        if (!$host) {
            return $new;
        }
        $port = $uri.getPort();
        if ($port) {
            $host ~= ":" ~ $port;
        }
        $new._environment["HTTP_HOST"] = $host;

        return $new;
    }

    /**
     * Create a new instance with a specific request-target.
     *
     * You can use this method to overwrite the request target that is
     * inferred from the request"s Uri. This also lets you change the request
     * target"s form to an absolute-form, authority-form or asterisk-form
     *
     * @link https://tools.ietf.org/html/rfc7230#section-2.7 (for the various
     *   request-target forms allowed in request messages)
     * @param string $requestTarget The request target.
     * @return static
     * @psalm-suppress MoreSpecificImplementedParamType
     */
    function withRequestTarget($requestTarget) {
        $new = clone this;
        $new.requestTarget = $requestTarget;

        return $new;
    }

    /**
     * Retrieves the request"s target.
     *
     * Retrieves the message"s request-target either as it was requested,
     * or as set with `withRequestTarget()`. By default this will return the
     * application relative path without base directory, and the query string
     * defined in the SERVER environment.
     */
    string getRequestTarget() {
        if (this.requestTarget != null) {
            return this.requestTarget;
        }

        $target = this.uri.getPath();
        if (this.uri.getQuery()) {
            $target ~= "?" ~ this.uri.getQuery();
        }

        if (empty($target)) {
            $target = "/";
        }

        return $target;
    }

    /**
     * Get the path of current request.
     *
     * @return string
     * @since 3.6.1
     */
    string getPath() {
        if (this.requestTarget == null) {
            return this.uri.getPath();
        }

        [$path] = explode("?", this.requestTarget);

        return $path;
    }
}
