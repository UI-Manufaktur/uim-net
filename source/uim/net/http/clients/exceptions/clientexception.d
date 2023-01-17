module uim.net.http.clients\Exception;

@safe:
import uim.net;

use Psr\Http\Client\ClientExceptionInterface;
use RuntimeException;

/**
 * Thrown when a request cannot be sent or response cannot be parsed into a PSR-7 response object.
 */
class ClientException : RuntimeException : ClientExceptionInterface
{
}
