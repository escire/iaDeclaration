<?php
/**
 * Copyright 2026 eScire
 * Developed by eScire, with the collaboration of:
 *   - Gustavo Casiano Leon
 *   - Rebeca Maria Sirbu
 * Licensed under the Apache License, Version 2.0 (see LICENSE and NOTICE).
 */

/**
 * @file plugins/generic/aiDeclaration/form/AiDeclarationSettingsForm.php
 *
 * @class AiDeclarationSettingsForm
 * @ingroup plugins_generic_aiDeclaration
 *
 * Plugin settings form: API key, declarador URL, and require/optional toggle.
 */

namespace APP\plugins\generic\aiDeclaration\form;

use APP\template\TemplateManager;
use PKP\form\Form;
use PKP\form\validation\FormValidatorCSRF;
use PKP\form\validation\FormValidatorPost;

class AiDeclarationSettingsForm extends Form
{
    /** @var int */
    public $contextId;

    /** @var \PKP\plugins\Plugin */
    public $plugin;

    public function __construct($plugin, $contextId)
    {
        $this->contextId = $contextId;
        $this->plugin    = $plugin;
        parent::__construct($plugin->getTemplateResource('settingsForm.tpl'));
        $this->addCheck(new FormValidatorPost($this));
        $this->addCheck(new FormValidatorCSRF($this));
    }

    public function fetch($request, $template = null, $display = false)
    {
        $templateMgr = TemplateManager::getManager($request);
        $declaradorUrl = $this->plugin->getSetting($this->contextId, 'declaradorUrl');
        if (empty($declaradorUrl)) {
            $declaradorUrl = 'https://declarador.usoeticoia.org';
        }

        $templateMgr->assign([
            'pluginName'         => $this->plugin->getName(),
            'declaradorUrl'      => $declaradorUrl,
            'apiKey'             => $this->plugin->getSetting($this->contextId, 'apiKey'),
            'requireDeclaration' => (bool) $this->plugin->getSetting($this->contextId, 'requireDeclaration'),
        ]);
        return parent::fetch($request, $template, $display);
    }

    public function readInputData()
    {
        $this->readUserVars(['declaradorUrl', 'apiKey', 'requireDeclaration']);
    }

    public function execute(...$functionArgs)
    {
        // Normalize the URL: strip trailing slash, default to official instance if empty
        $declaradorUrl = rtrim(trim((string) $this->getData('declaradorUrl')), '/');
        if (empty($declaradorUrl)) {
            $declaradorUrl = 'https://declarador.usoeticoia.org';
        }
        $this->plugin->updateSetting($this->contextId, 'declaradorUrl', $declaradorUrl);
        $this->plugin->updateSetting($this->contextId, 'apiKey', trim((string) $this->getData('apiKey')));
        $this->plugin->updateSetting($this->contextId, 'requireDeclaration', (bool) $this->getData('requireDeclaration'));
        parent::execute(...$functionArgs);
    }
}
