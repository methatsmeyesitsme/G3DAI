# G3DAI Grok Connector

This extension lets G3DAI use the Grok website you are already signed into.

It does not ask G3DAI for your Grok password and it does not use an xAI API key.

## Chrome or Edge

Open the browser extensions page, turn on Developer mode, choose Load unpacked, and select this extension folder.

## Firefox

Open about:debugging#/runtime/this-firefox, choose Load Temporary Add-on, and select manifest.json inside this folder. Firefox removes temporary extensions when the browser restarts.

## Use

1. Sign in normally at https://grok.com/.
2. Open G3DAI at https://methatsmeyesitsme.github.io/G3DAI/.
3. Press Send in G3DAI.
4. The connector sends the prompt to your signed-in Grok tab.
5. The Grok response is returned to the G3DAI chat automatically.

This connector works through the Grok web interface rather than a developer API, so a future Grok website UI change could require an extension update.