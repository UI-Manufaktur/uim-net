


 *


 * @since         4.3.0
  */module uim.net.http.TestSuite;

import uim.net.http.Client;
import uim.net.http.Client\Response;

/**
 * Define mock responses and have mocks automatically cleared.
 */
trait HttpClientTrait
{
    /**
     * Resets mocked responses
     *
     * @after
     */
    void cleanupMockResponses() {
        Client::clearMockResponses();
    }

    /**
     * Create a new response.
     *
     * @param int $code The response code to use. Defaults to 200
     * @param array<string> $headers A list of headers for the response. Example `Content-Type: application/json`
     * @param string $body The body for the response.
     * returns DHTPResponse
     */
    function newClientResponse(int $code = 200, array $headers = null, string $body = ""): Response
    {
        $headers = array_merge(["HTTP/1.1 {$code}"], $headers);

        return new Response($headers, $body);
    }

    /**
     * Add a mock response for a POST request.
     *
     * @param string $url The URL to mock
     * @param uim.net.http.Client\Response $response The response for the mock.
     * @param array<string, mixed> $options Additional options. See Client::addMockResponse()
     */
    void mockClientPost(string $url, Response $response, STRINGAA someOptions = null) {
        Client::addMockResponse("POST", $url, $response, $options);
    }

    /**
     * Add a mock response for a GET request.
     *
     * @param string $url The URL to mock
     * @param uim.net.http.Client\Response $response The response for the mock.
     * @param array<string, mixed> $options Additional options. See Client::addMockResponse()
     */
    void mockClientGet(string $url, Response $response, STRINGAA someOptions = null) {
        Client::addMockResponse("GET", $url, $response, $options);
    }

    /**
     * Add a mock response for a PATCH request.
     *
     * @param string $url The URL to mock
     * @param uim.net.http.Client\Response $response The response for the mock.
     * @param array<string, mixed> $options Additional options. See Client::addMockResponse()
     */
    void mockClientPatch(string $url, Response $response, STRINGAA someOptions = null) {
        Client::addMockResponse("PATCH", $url, $response, $options);
    }

    /**
     * Add a mock response for a PUT request.
     *
     * @param string $url The URL to mock
     * @param uim.net.http.Client\Response $response The response for the mock.
     * @param array<string, mixed> $options Additional options. See Client::addMockResponse()
     */
    void mockClientPut(string $url, Response $response, STRINGAA someOptions = null) {
        Client::addMockResponse("PUT", $url, $response, $options);
    }

    /**
     * Add a mock response for a DELETE request.
     *
     * @param string $url The URL to mock
     * @param uim.net.http.Client\Response $response The response for the mock.
     * @param array<string, mixed> $options Additional options. See Client::addMockResponse()
     */
    void mockClientDelete(string $url, Response $response, STRINGAA someOptions = null) {
        Client::addMockResponse("DELETE", $url, $response, $options);
    }
}
