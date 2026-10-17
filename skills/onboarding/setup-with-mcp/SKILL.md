---
name: linkrunner-setup-with-mcp
description: >-
  Set up Linkrunner from zero through the Linkrunner connector (remote MCP
  server at mcp.linkrunner.io/mcp): check the signed-in account, look
  for an existing project, find the app in the Play Store or App Store and
  confirm it with the user, create the project, install the SDK with the
  returned token using the matching platform skill, then verify. Use when
  someone asks to "set up Linkrunner", "create a Linkrunner project", "get my
  SDK token", or "onboard my app to Linkrunner" and the Linkrunner connector
  tools (get_my_account, create_project) are available.
metadata:
  category: onboarding
  slug: setup-with-mcp
  docs: https://docs.linkrunner.io
---

# Linkrunner - set up with the connector

You are taking a person from no Linkrunner project to a working SDK install
using the **Linkrunner connector** (remote MCP server,
`https://mcp.linkrunner.io/mcp`). Do the steps in order and **ask before every
write**. Do not guess app names, store links, companies, or timezones.

If the connector tools are not available in this session, tell the user to add
the connector first and stop:

- Claude Code: `claude mcp add --transport http linkrunner https://mcp.linkrunner.io/mcp`,
  then run `/mcp` to sign in.
- Claude (web, desktop, mobile): Customize -> Connectors -> Add custom
  connector, URL `https://mcp.linkrunner.io/mcp`, Authentication "Sign in when
  needed".

Sign-in is OAuth in a popup. There is no token to copy. New users can sign up
in the same popup (Google or an email link). Until the person signs in, only
`get_linkrunner_overview` and `search_documentation` work; any other tool asks
them to sign in and then continues.

## The two rules

1. **A company email is needed to create a project.** Gmail accounts can sign
   up and be invited to projects, but cannot create one.
2. **An app project needs a live App Store or Play Store listing.** An app that
   is not published yet cannot be set up until it is. A website-only project
   needs the website URL instead.

Also true: an assistant can create up to 3 projects per person per day, and to
use an existing project from an assistant the person must be its Admin, Owner
or Manager.

## 1. Check the account

Call `get_my_account`. Read back the signed-in email and whether this account
can create projects.

- If it cannot create projects because of a personal (for example Gmail)
  address, apply rule 1 and go to "When you are refused".
- If the email is not the one the user expects, ask them to sign in again with
  the right one (disconnect and reconnect the connector). Do not continue on
  the wrong account.

## 2. Look for an existing project

Call `list_projects`. If the app is already there, do not create a duplicate:
skip to step 5 and call `get_sdk_configuration(project_id)` to get the SDK
token. If the person is not Admin, Owner or Manager of that project, say so and
ask them to get that role from a project admin.

## 3. Find the app and confirm it

Inspect the user's repo first for the app name and bundle id or package name
(`pubspec.yaml`, `app.json`, `build.gradle`, `Info.plist`, and similar). Then
call `find_app_in_store` with the name, or with the store URL if the user has
one.

**Show the match to the user (name, publisher, store, link) and get an explicit
yes before going on.** If there are several results or none, ask which one or
for the store link. If the app is not published, apply rule 2 and go to "When
you are refused". For a website-only project, ask for the website URL instead.

## 4. Create the project

Confirm these with the user, then call `create_project`:

| Argument | Source |
| --- | --- |
| name | confirmed app or site name |
| company | ask; do not infer from the email domain without asking |
| type | `app` or `website` |
| store link(s) | from step 3 |
| timezone | IANA name such as `Asia/Kolkata`; ask if unsure |
| billing_currency | optional, `USD` or `INR`; ask only if the user cares |
| billing_account_id | only if `get_my_account` lists `billing_accounts`: ask which company the project is billed to and pass that id. With an empty list, leave it out and a new billing account is created |

If the tool answers that a billing account must be chosen, show the listed
options to the user, ask, and call again with `billing_account_id`. Never pick one
for them.

It returns the project id and the SDK token. Do not quote free allowance or
pricing numbers; point the user to the dashboard for billing. New projects get
the same free allowance and billing setup as projects created in the dashboard.

## 5. Install the SDK with the token

Pick the platform from the repo (see the table), then **load that platform
skill and follow it**. It already inspects the project first and verifies at
the end. Pass the project token from step 4 (or from
`get_sdk_configuration(project_id)`, which returns it again at any time).

| Project is | Platform skill | Short name (Claude Code plugin skill name, `npx ... add` name) |
| --- | --- | --- |
| Flutter | `linkrunner-flutter` | `flutter` |
| React Native | `linkrunner-react-native` | `react-native` |
| Expo | `linkrunner-expo` | `expo` |
| iOS (Swift) | `linkrunner-ios` | `ios` |
| Android (Kotlin) | `linkrunner-android` | `android` |
| Capacitor / Ionic | `linkrunner-capacitor` | `capacitor` |
| Cordova | `linkrunner-cordova` | `cordova` |
| Unity | `linkrunner-unity` | `unity` |

If the platform skill is not installed, run `npx @linkrunner/skills add <name>`
in the app repo, or use `search_documentation` for the platform guide at
docs.linkrunner.io and follow it.

Put the token where the project keeps config (env file, config module), not in
chat summaries, commits, or logs beyond what the platform guide requires.

## 6. Verify

1. Run the platform skill's own verification (build, deep-link validator).
2. Call `get_sdk_configuration(project_id)` and check the token in the app
   matches the one returned.
3. Tell the user the next step is to run the app on a device or emulator and
   open it once, then check the project's install in the dashboard
   (https://dashboard.linkrunner.io) or ask for project stats with `project_id`.
   Report what you checked and what you could not check. Do not claim an
   install is attributed until the user has seen it.

After setup, the other connector tools (stats, campaigns, funnels, domains,
postbacks, webhooks, link checks) work with a `project_id` argument. Ad-account
tools (Meta and Google reads) are not available on the sign-in connection yet.

## When you are refused

Do not retry with different inputs to get around a refusal, and do not use a
different person's details.

| Refusal | What to tell the user |
| --- | --- |
| Personal email (for example Gmail) cannot create a project | Sign in with a company email, or ask a teammate who has a company email to create the project and invite them. Help: support@linkrunner.io |
| App is not live in the Play Store or App Store | Linkrunner can set the app up once it is published. Come back then. A website-only project needs the website URL |
| Daily limit of 3 projects reached | Try again tomorrow, or create the project in the dashboard |
| Not Admin, Owner or Manager of an existing project | Ask a project admin to change their role |
| Any other refusal | Show the message as it is and point to support@linkrunner.io |

## References

- Connector and docs: https://docs.linkrunner.io
- Platform skills: the table in step 5
