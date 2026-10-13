{**
 * Copyright 2026 eScire
 * Developed by eScire, with the collaboration of:
 *   - Gustavo Casiano Leon
 * Licensed under the Apache License, Version 2.0 (see LICENSE and NOTICE).
 *}
{**
 * templates/articleDeclaration.tpl
 *
 * Displays the AI transparency declaration badge in the published article detail sidebar.
 * Injected via Templates::Article::Details hook.
 *}

{if $aiDeclaration_used !== null}
<div class="item ai-declaration-badge">

    <h2 class="label">{translate key="plugins.generic.aiDeclaration.article.sectionTitle"}</h2>

    {if $aiDeclaration_used}

        {* ---- AI USED badge — always linked to declaration URL ---- *}
        {if $aiDeclaration_url}
            <a href="{$aiDeclaration_url|escape}" target="_blank" rel="noopener noreferrer"
               title="{translate key="plugins.generic.aiDeclaration.article.viewDeclaration"}">
                <img src="https://static.wixstatic.com/media/7af97a_a5b8e757a6ec4dd0b50c4d66bb9e4d6d~mv2.png"
                     alt="{translate key="plugins.generic.aiDeclaration.article.aiUsed"}"
                     class="ai-declaration-badge-img" style="max-width:70%; height:auto; display:block;" />
            </a>
        {else}
            <img src="https://static.wixstatic.com/media/7af97a_a5b8e757a6ec4dd0b50c4d66bb9e4d6d~mv2.png"
                 alt="{translate key="plugins.generic.aiDeclaration.article.aiUsed"}"
                 class="ai-declaration-badge-img" />
        {/if}

        {if $aiDeclaration_hash}
        <p class="ai-declaration-badge-hash">
            <span class="ai-declaration-badge-hash-label">{translate key="plugins.generic.aiDeclaration.article.verificationHash"}:</span>
            <code>{$aiDeclaration_hash|escape}</code>
        </p>
        {/if}

    {else}

        {* ---- NO AI used badge — link to declaration URL when available ---- *}
        {if $aiDeclaration_url}
            <a href="{$aiDeclaration_url|escape}" target="_blank" rel="noopener noreferrer"
               title="{translate key="plugins.generic.aiDeclaration.article.viewDeclaration"}">
                <img src="https://static.wixstatic.com/media/7af97a_d0748a3b02844bd49109b02e78f55ba9~mv2.png"
                     alt="{translate key="plugins.generic.aiDeclaration.article.aiNotUsed"}"
                     class="ai-declaration-badge-img" style="max-width:70%; height:auto; display:block;" />
            </a>
        {else}
            <img src="https://static.wixstatic.com/media/7af97a_d0748a3b02844bd49109b02e78f55ba9~mv2.png"
                 alt="{translate key="plugins.generic.aiDeclaration.article.aiNotUsed"}"
                 class="ai-declaration-badge-img" />
        {/if}

    {/if}

</div>
{/if}
