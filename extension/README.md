# G3DAI Grok Connector

This bridge lets G3DAI talk to the Grok website you are already signed into.

It does NOT ask G3DAI for your Grok email or password, and it does NOT use an xAI API key.

## Important: you do not create anything on a Grok developer/API page

There are no API-key boxes to fill in.

You only install the extension and sign in normally at grok.com.

## Firefox on Windows

### 1. Download G3DAI

1. Open the G3DAI GitHub repository.
2. Click the green Code button.
3. Click Download ZIP.
4. Open the downloaded ZIP.
5. Click Extract All.
6. Open the extracted folder.

Your folder will usually look like:

C:/Users/abegr/Downloads/G3DAI-main/G3DAI-main

### 2. Find the connector folder

Inside the extracted G3DAI folder, open:

extension

You should see:

- manifest.json
- background.js
- g3dai.js
- grok.js
- README.md

Do not rename the files.

### 3. Load the connector into Firefox

1. Open Firefox.
2. Type this in the address bar:

about:debugging#/runtime/this-firefox

3. Press Enter.
4. Choose This Firefox on the left.
5. Click Load Temporary Add-on...
6. A file picker appears.
7. Go to:

C:/Users/abegr/Downloads/G3DAI-main/G3DAI-main/extension

8. Select:

manifest.json

9. Click Open.

### 4. What goes in the boxes?

There are no settings boxes to fill in.

When Firefox asks you to choose a file:

File: manifest.json

Do not type:
- your Grok email
- your Grok password
- an API key
- your Grok username

Firefox should now show G3DAI Grok Connector as a temporary extension.

### 5. Sign into Grok

Open:

https://grok.com/

Sign in normally.

G3DAI does not receive your password.

### 6. Open G3DAI

Open:

https://methatsmeyesitsme.github.io/G3DAI/

### 7. Connect

1. Click Settings.
2. Under Grok connection, click Connect.
3. The status should show Connected when the extension is detected.

### 8. Test it

Try this:

Design a 100 mm wide phone stand with a 10 mm front lip and an adjustable back support. Make it suitable for PLA printing.

G3DAI should send the request to the Grok tab.

When Grok finishes, its response should be returned to the G3DAI chat automatically.

## If Firefox says the extension is missing

Make sure you selected:

extension/manifest.json

Do not select background.js, g3dai.js, or grok.js.

## If the connector disappears

Firefox's Load Temporary Add-on feature is temporary.

After restarting Firefox:

1. Open about:debugging#/runtime/this-firefox
2. Choose This Firefox.
3. Click Load Temporary Add-on...
4. Select the same extension/manifest.json file again.

## Chrome or Edge

### Chrome

1. Open chrome://extensions
2. Turn on Developer mode.
3. Click Load unpacked.
4. Select the extension folder itself.
5. Do not select an individual JavaScript file.

### Edge

1. Open edge://extensions
2. Turn on Developer mode.
3. Click Load unpacked.
4. Select the extension folder itself.

## Security

The connector is designed around your existing Grok browser session.

G3DAI does not collect:
- your Grok password
- your Grok cookies
- an xAI API key

The connector only communicates between your G3DAI tab and your Grok tab.

## Limitation

This connector interacts with the Grok web page rather than an official developer API. If Grok changes its page controls or layout, the connector may need an update.

## G3DAI

https://methatsmeyesitsme.github.io/G3DAI/

## Repository

https://github.com/methatsmeyesitsme/G3DAI
