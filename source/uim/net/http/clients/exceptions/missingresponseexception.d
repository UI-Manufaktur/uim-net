module uim.http.clients\Exception;

import uim.cake.core.exceptions\UIMException;

/**
 * Used to indicate that a request did not have a matching mock response.
 */
class MissingResponseException : UIMException {
    /**
     */
    protected string _messageTemplate = "Unable to find a mocked response for `%s` to `%s`.";
}
