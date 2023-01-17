module uim.http.exceptions;

import uim.cake.core.exceptions.UIMException;

/**
 * Missing Controller exception - used when a controller
 * cannot be found.
 */
class MissingControllerException : UIMException {

    protected _defaultCode = 404;


    protected _messageTemplate = "Controller class %s could not be found.";
}

// phpcs:disable
class_alias(
    "Cake\Http\exceptions.MissingControllerException",
    "Cake\routings.exceptions.MissingControllerException"
);
// phpcs:enable
