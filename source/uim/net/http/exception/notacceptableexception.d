

/**
 * UIM(tm) : Rapid Development Framework (https://cakephp.org)
 * Copyright (c) Cake Software Foundation, Inc. (https://cakefoundation.org)
 *
 * Licensed under The MIT License
 * Redistributions of files must retain the above copyright notice.
 *

 * @since         3.1.7
  */module uim.http.exceptions;

use Throwable;

/**
 * Represents an HTTP 406 error.
 */
class NotAcceptableException : HttpException {

    protected _defaultCode = 406;

    /**
     * Constructor
     *
     * @param string|null $message If no message is given "Not Acceptable" will be the message
     * @param int|null $code Status code, defaults to 406
     * @param \Throwable|null $previous The previous exception.
     */
    this(Nullable!string $message = null, Nullable!int $code = null, ?Throwable $previous = null) {
        if (empty($message)) {
            $message = "Not Acceptable";
        }
        super(($message, $code, $previous);
    }
}
