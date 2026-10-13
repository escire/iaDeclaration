<?php
/**
 * Copyright 2026 eScire
 * Developed by eScire, with the collaboration of:
 *   - Gustavo Casiano Leon
 *   - Rebeca Maria Sirbu
 * Licensed under the Apache License, Version 2.0 (see LICENSE and NOTICE).
 */

/**
 * @file plugins/generic/aiDeclaration/classes/AiDeclarationHandler.php
 *
 * @class AiDeclarationHandler
 * @ingroup plugins_generic_aiDeclaration
 *
 * Component handler for AJAX endpoints used by the AI Declaration plugin.
 * Accessible by any logged-in user (authors during the submission wizard).
 */

namespace APP\plugins\generic\aiDeclaration\classes;

use PKP\core\JSONMessage;
use PKP\handler\PKPHandler;
use PKP\plugins\PluginRegistry;
use PKP\security\authorization\UserRequiredPolicy;

class AiDeclarationHandler extends PKPHandler
{
    /**
     * Authorize the request. Requires the user to be logged in.
     */
    public function authorize($request, &$args, $roleAssignments)
    {
        $this->addPolicy(new UserRequiredPolicy($request));
        return parent::authorize($request, $args, $roleAssignments);
    }

    /**
     * Delegate to AiDeclarationPlugin::manage() for the actual AJAX handling.
     * Verbs handled: ajaxCreateDeclaration, ajaxFindDeclaration.
     */
    public function manage($args, $request)
    {
        if (!$request->checkCSRF()) {
            return new JSONMessage(false, ['error' => 'Invalid CSRF token']);
        }

        $plugin = PluginRegistry::getPlugin('generic', 'aideclarationplugin');
        if (!$plugin) {
            return new JSONMessage(false, ['error' => 'Plugin not available']);
        }

        return $plugin->manage($args, $request);
    }
}
