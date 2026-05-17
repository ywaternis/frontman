---
title: 'Frontman WordPress Plugin Released'
pubDate: 2026-05-14T05:00:00Z
description: 'The Frontman WordPress plugin is now live in the WordPress Plugin Directory. Install it from wp-admin and edit your site with an AI agent.'
author: 'Itay A'
image: '/blog/frontman-wordpress-plugin-released-cover.png'
tags: ['announcement', 'wordpress']
---

Installing an AI tool on a WordPress site should not start with a GitHub tab, a ZIP file, and a quiet hope that you downloaded the right artifact.

That path worked for early testers. It was not good enough for the normal WordPress workflow. WordPress users install plugins from WordPress. Agencies expect the plugin to show up in wp-admin. Site owners expect updates to look like every other plugin update.

So we fixed the distribution problem.

The [Frontman WordPress plugin](https://wordpress.org/plugins/frontman-agentic-ai-editor/) is now live in the WordPress Plugin Directory as **Frontman - Agentic AI Editor**.

### Install Frontman from the WordPress Plugin Directory

The preferred install path is now the WordPress store inside wp-admin:

1. Open **Plugins -> Add New Plugin** in WordPress.
2. Search for **Frontman Agentic AI Editor**.
3. Click **Install Now**.
4. Click **Activate**.
5. Visit `/frontman` on your site while logged in as an administrator.

That is the whole setup. No terminal. No separate server. No manual release ZIP unless you specifically want one.

The GitHub [releases page](https://github.com/frontman-ai/frontman/releases) is still there, and it still matters. If you need to pin an exact version, audit a release artifact before installing it, or mirror the plugin into an internal deployment process, download the ZIP from GitHub. For everyone else, use the WordPress Plugin Directory. It is the path WordPress sites are built around.

### What the plugin gives you

Frontman puts an AI agent directly inside your WordPress site. Open `/frontman`, describe the change you want, and the agent works through WordPress-specific tools while you watch the live site preview.

It can handle the workflows that usually send you hunting through admin screens:

- Create, edit, and delete posts and pages
- Insert, update, and rearrange Gutenberg blocks
- Edit Elementor pages with Elementor-aware tools
- Update navigation menus and menu items
- Read and change safe site options like title, tagline, and permalink settings
- Browse block templates and template parts
- Search and read files across the WordPress installation for context

The important part is not that there is a chat box. WordPress already has plenty of AI chat boxes. The important part is that the agent operates next to a live preview of the page it is changing. You describe the result you want, the plugin runs the appropriate WordPress tools, and you verify the change in the same workflow.

That feedback loop is the difference between "AI generated some content" and "the page now looks right."

### Why the directory release matters

Early software usually makes users do early-software things. Download this build. Upload this ZIP. Check this release note. Make sure you picked the latest version. If something goes wrong, wonder whether the bug is in the product or the install path.

That friction changes who tries the product.

Developers will tolerate a release ZIP. Agencies will tolerate it on a staging site. A content editor with a broken homepage will not. They are already in WordPress. The fix needs to start where they are.

Being in the WordPress Plugin Directory makes Frontman behave like a WordPress plugin should behave:

- It is discoverable from wp-admin.
- It installs through the standard plugin screen.
- It updates through the normal WordPress update flow.
- It has a public plugin page, changelog, support forum, and distribution history.

None of that changes the agent architecture. It changes trust. The plugin is no longer something you fetch from the side door before using WordPress. It is part of the WordPress plugin ecosystem.

### What changed since the first WordPress beta

The first [WordPress beta announcement](/blog/wordpress-integration/) focused on proving that Frontman could run inside WordPress at all. The agent had to understand posts, blocks, menus, templates, widgets, settings, and the file context around a site. It also had to respect WordPress permissions instead of pretending a CMS is just another local codebase.

Since then, the plugin has become more WordPress-native. Tool calls run through the plugin. Admin access is restricted to users with the right capabilities. Site option writes stay on an allowlist. Destructive changes require more care. Elementor support is now part of the workflow instead of a vague future promise.

That is the direction: fewer special setup steps, more WordPress-specific tools, and a tighter feedback loop between the request, the change, and the preview.

### Still early, still use staging

This is a release announcement, not a claim that every WordPress edge case has been solved.

WordPress is not one platform in practice. It is thousands of themes, page builders, hosting environments, cache layers, security plugins, custom post types, and old decisions nobody remembers making. Usually in production. Usually five minutes before someone needs the page fixed.

Frontman is still experimental software. Start on a staging site. Keep backups. Review changes before trusting them. The plugin can make real changes to content, menus, templates, Elementor pages, and settings. That power is the point. It is also why the workflow has to be treated seriously.

### Try it

Install [Frontman - Agentic AI Editor from the WordPress Plugin Directory](https://wordpress.org/plugins/frontman-agentic-ai-editor/), activate it, and open `/frontman` on your site.

If you need the manual artifact, use the [GitHub releases page](https://github.com/frontman-ai/frontman/releases). If you just want the normal WordPress path, use the plugin directory.

The better workflow is simple: stay inside the site, describe the change, watch the preview, and review what changed before it ships.
