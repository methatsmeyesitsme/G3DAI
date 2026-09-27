# G3DAI local Grok setup

This is the one-time Windows setup.

1. Download the G3DAI ZIP from GitHub.
2. Click Extract All.
3. Open the extracted G3DAI folder.
4. Double-click Start-G3DAI.bat.
5. The launcher installs the official Grok CLI if needed.
6. G3DAI copies itself to %LOCALAPPDATA%\G3DAI.
7. It creates a G3DAI shortcut in your Windows Startup folder.
8. It starts the server in the background and opens G3DAI.
9. In G3DAI, open Settings -> Connect -> Sign in with Grok.
10. Sign in normally in the browser.
11. Return to G3DAI and click Check connection.

After the one-time setup you can close the launcher. You do not need to run Start-G3DAI.bat again. G3DAI starts automatically when you sign into Windows.

You can delete the downloaded ZIP and the extracted G3DAI folder after the setup finishes because a copy is installed under %LOCALAPPDATA%\G3DAI.

No xAI API key is used. No Node.js is required.

xAI documents browser login for the official Grok CLI:
https://docs.x.ai/build/overview
