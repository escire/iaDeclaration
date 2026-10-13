<?php
/**
 * Copyright 2026 eScire
 * Developed by eScire, with the collaboration of:
 *   - Gustavo Casiano Leon
 * Licensed under the Apache License, Version 2.0 (see LICENSE and NOTICE).
 */

/**
 * @file plugins/generic/aiDeclaration/classes/AiDeclarationHandler.inc.php
 *
 * @class AiDeclarationHandler
 * @ingroup plugins_generic_aiDeclaration
 *
 * Component handler for AJAX endpoints used by the AI Declaration plugin.
 * Accessible by any logged-in user (authors during submission step 3).
 *
 * URL pattern (path info enabled):
 *   .../index.php/{journal}/$$$call$$$/plugins/generic/ai-declaration/classes/ai-declaration/manage
 *
 * The LoadComponentHandler hook in AiDeclarationPlugin intercepts this component
 * path and allows instantiation of this class.
 */

import('lib.pkp.classes.handler.PKPHandler');

class AiDeclarationHandler extends PKPHandler
{
    /**
     * Authorize the request. Requires the user to be logged in.
     */
    public function authorize($request, &$args, $roleAssignments)
    {
        import('lib.pkp.classes.security.authorization.UserRequiredPolicy');
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
            import('lib.pkp.classes.core.JSONMessage');
            return new JSONMessage(false, array('error' => 'Invalid CSRF token'));
        }

        $plugin = PluginRegistry::getPlugin('generic', 'aideclarationplugin');
        if (!$plugin) {
            import('lib.pkp.classes.core.JSONMessage');
            return new JSONMessage(false, array('error' => 'Plugin not available'));
        }

        return $plugin->manage($args, $request);
    }
}
