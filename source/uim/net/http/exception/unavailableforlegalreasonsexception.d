

/**
 * UIM(tm) : Rapid Development Framework (https://cakephp.org)
 * Copyright (c) Cake Software Foundation, Inc. (https://cakefoundation.org)
 *
 * Licensed under The MIT License
 * Redistributions of files must retain the above copyright notice.
 *

 * @since         3.2.12
  */module uim.net.http.exceptions;

use Throwable;

/**
 * Represents an HTTP 451 error.
 */
class UnavailableForLegalReasonsException : HttpException {

    protected _defaultCode = 451;

    /**
     * Constructor
     *
     * @param string|null $message If no message is given "Unavailable For Legal Reasons" will be the message
     * @param int|null $code Status code, defaults to 451
     * @param \Throwable|null $previous The previous exception.
     */
    this(Nullable!string $message = null, Nullable!int $code = null, ?Throwable $previous = null) {
        if (empty($message)) {
            $message = "Unavailable For Legal Reasons";
        }
        super(($message, $code, $previous);
    }
}
