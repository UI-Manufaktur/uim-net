/*********************************************************************************************************
	Copyright: © 2015-2023 Ozan Nurettin Süel (Sicherheitsschmiede)                                        
	License: Subject to the terms of the Apache 2.0 license, as written in the included LICENSE.txt file.  
	Authors: Ozan Nurettin Süel (Sicherheitsschmiede)                                                      
**********************************************************************************************************/
module uim.net.http;

import uim.net.core.IHttpApplication;
use Psr\Http\messages.IResponse;
use Psr\Http\messages.IServerRequest;

/**
 * Base class for standalone HTTP applications
 *
 * Provides a base class to inherit from for applications using
 * only the http package. This class defines a fallback handler
 * that renders a simple 404 response.
 *
 * You can overload the `handle` method to provide your own logic
 * to run when no middleware generates a response.
 */
abstract class MiddlewareApplication : IHttpApplication
{

    abstract void bootstrap();

    abstract function middleware(MiddlewareQueue $middlewareQueue): MiddlewareQueue;

    /**
     * Generate a 404 response as no middleware handled the request.
     *
     * @param \Psr\Http\messages.IServerRequest $request The request
     * @return \Psr\Http\messages.IResponse
     */
    function handle(
        IServerRequest $request
    ): IResponse {
        return new Response(["body": "Not found", "status": 404]);
    }
}
