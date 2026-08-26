# Mira App Store Metadata

## App Name

Mira

## Subtitle

Chat With Your AI Machines

## Promotional Text

Bring the model endpoints you control into one calm native workspace. Configure machines, inspect route health, and stream chat directly from LM Studio.

## Description

Mira is a chat-first AI studio for the machines and model endpoints you control.

Start with the task instead of the infrastructure. Mira opens to a focused native chat workspace, with route selection and an Inspector close by when you want to understand the machine, endpoint, or model behind the friendly name.

CONNECT YOUR MACHINES
Add machine display names, hosts, and expected endpoint ports at runtime. Mira can run read-only probes for LM Studio, Automatic1111-compatible or Forge, and ComfyUI endpoints, then organize discovered routes across Chat, Inspector, Machines, and Library.

CHAT THROUGH A ROUTE YOU CHOOSE
Select an available LM Studio text route and stream a Free Chat response through its OpenAI-compatible endpoint. Requests travel directly from your device to the endpoint you configure; Mira does not route them through a developer-operated AI backend.

KEEP THE DETAILS NEARBY
Use the responsive Inspector for route health and diagnostics. Developer Mode reveals inventory and request details without crowding the normal workspace.

PRIVATE BY DESIGN
The current app contains no advertising, cross-app tracking, or third-party analytics. Real hosts, private addresses, keys, and machine inventories are runtime configuration rather than bundled public data.

CURRENT RELEASE SCOPE
This first release focuses on runtime machine setup, read-only endpoint discovery, route hydration, and one selected LM Studio Free Chat route. Configured machine state and chat transcripts are in memory in this version. Group Chat, Compare, persistent transcripts, cloud streaming, and broader media workflows are planned rather than presented as complete.

Mira keeps the machinery nearby without making setup the product.

## Keywords

AI,chat,local,LM Studio,models,endpoint,machine,private,route,inspector,developer,studio

## What's New for 0.1.5

Mira's first App Store candidate introduces the native chat workspace, responsive Inspector and navigation, runtime machine setup, read-only endpoint probes, route hydration, and streaming Free Chat through a selected LM Studio route.

## Privacy Policy

https://sankofa06.github.io/Lucidity/privacy.html

## Support URL

https://sankofa06.github.io/Lucidity/support.html

## Marketing URL

https://sankofa06.github.io/Lucidity/

## Content Rights

Set App Store Connect to `USES_THIRD_PARTY_CONTENT`. Mira can connect to user-configured third-party model servers and display model-generated responses supplied by those services.

## App Review Notes

Mira has no accounts and requires no test login.

The app connects directly to local or private-network model services configured by the user. The current live chat path uses an explicitly selected LM Studio text route and its OpenAI-compatible chat-completions endpoint. A reviewer without a reachable LM Studio server can still inspect the native Chat, Inspector, Machines, Library, Settings, route-selection, and diagnostics interfaces, but cannot complete a live model response.

To configure a route, open Settings > Machines & Endpoints, add a machine display name and reachable host, choose the expected LM Studio port, and refresh inventory. Return to Chat, choose Free Chat, and select the hydrated text route.

Automatic1111-compatible / Forge and ComfyUI endpoints are probed read-only in this release. Their broader media workflows are not represented as complete.

The app does not route prompts or provider traffic through a developer-operated AI backend and includes no advertising, cross-app tracking, or third-party analytics. Real endpoint data is entered at runtime. No private hosts, API keys, endpoint snapshots, or model inventory are bundled in the app.
