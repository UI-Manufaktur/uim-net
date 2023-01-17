/*********************************************************************************************************
	Copyright: © 2015-2023 Ozan Nurettin Süel (Sicherheitsschmiede)                                        
	License: Subject to the terms of the Apache 2.0 license, as written in the included LICENSE.txt file.  
	Authors: Ozan Nurettin Süel (Sicherheitsschmiede)                                                      
**********************************************************************************************************/module uim.http.exceptions;

@safe:
import uim.cake;

/**
 * Parent class for all the HTTP related exceptions in UIM.
 * All HTTP status/error related exceptions should extend this class so
 * catch blocks can be specifically typed.
 *
 * You may also use this as a meaningful bridge to {@link uim.cake.Core\exceptions.UIMException}, e.g.:
 * throw new uim.cake.Network\exceptions.HttpException("HTTP Version Not Supported", 505);
 */
class HttpException : UIMException {

    protected _defaultCode = 500;

    /**
     * @var array
     */
    protected headers = null;

    /**
     * Set a single HTTP response header.
     *
     * @param string header Header name
     * @param array<string>|string|null myValue Header value
     */
    void setHeader(string aHeader, myValue = null) {
        this.headers[aHeader] = myValue;
    }

    /**
     * Sets HTTP response headers.
     *
     * @param array $headers Array of header name and value pairs.
     */
    void setHeaders(array $headers) {
        this.headers = $headers;
    }

    /**
     * Returns array of response headers.
     */
    array getHeaders() {
        return this.headers;
    }
}
