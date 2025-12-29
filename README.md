# Pholder Renamer
Phish show folder renamer, powered by phish.net

## What It Does

1. It starts by asking you to select the folder containing your shows.
2. It scans each folder name within for a date (like `1997-11-17`). If it cannot find one, it pauses and asks you to type it in manually.
3. It uses the date to query the Phish.net API and downloads the official City, State, Country, and Venue
4. It looks inside the specific folder name to preserve optional details:
   * **Etree Source ID:** Looks for a unique 6-digit ID number (e.g., `137384`) sandwiched between dots.
   * **Set Number:** Looks for indicators like "set1" or "set2".
   * **Source Info:** Grabs text inside brackets `[]`, or finds hidden "flac" details buried in the middle.
   * **Misc Tags:** Anything sandwiched within parentheses will be retained.
8. It assembles the proposed new folder name in this specific order:
   `Date Location - Venue (SHNID) (Set Number) (Misc Tag) [Source]`
9. It pops up a window displaying the **Old Name** vs. the **New Name** and gives you an opportunity to override the proposed new name.

## How to Use

### 1. Retrieve a Phish.net API Key
To use this script, you need a free API key from Phish.net.

1. **Log In or Register:** Go to [api.phish.net](https://api.phish.net/) and log in. If you don't have an account, you will need to register for one first.
2. **Navigate to API Keys:** Once logged in, visit the [API Keys page](https://phish.net/api/keys).
3. **Copy Key:** Look for your **Private Key** and copy that string. We don't need your Private Salt.

### 2. Configure the Script
1. Open the script file in a text editor (Notepad, VS Code, or PowerShell ISE).
2. Locate the `$ApiKey` variable at the top of the file:
   ```powershell
   $ApiKey = "PUT_YOUR_KEY_HERE"
   ```
3. Paste your API key inside the quotes, replacing the placeholder text.
4. Save the file.

### 3. Running the Script
1. Open PowerShell.
2. Navigate to the directory containing the script.
3. Run the script:
   ```powershell
   .\PholderRenamer.ps1
   ```

## Troubleshooting

### Script Won't Run (Security Warning)
**Error:** *"File C:\...\PholderRenamer.ps1 cannot be loaded because running scripts is disabled on this system."*

**Solution:** 
PowerShell restricts scripts by default for security. To allow this script to run:
1. Open PowerShell as Administrator.
2. Run the following command:
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```
3. Type **Y** (Yes) when prompted.

### API Key Errors
**Error:** *"403 Forbidden"* or *"API Key Invalid"*

**Solution:**
* Ensure you copied the **Private Key** from Phish.net, not the Private Salt key.
* Check that there are no extra spaces inside the quotes in the `$ApiKey` variable.
* Verify your Phish.net account is active.

### Folder Access Denied
**Error:** *"The process cannot access the file because it is being used by another process."*

**Solution:**
* Make sure none of the music files inside the folder are currently open in a music player (like Foobar2000, VLC, or Spotify).
* Close any other File Explorer windows that might be open to that specific folder.

### "Date Not Found" Pop-ups
**Issue:** The script keeps pausing and asking you to manually enter a date.

**Solution:**
* The script looks for standard formats like `YYYY-MM-DD` or `MM-DD-YY`.
* If your folders are named vaguely (e.g., "Phish Hampton" or "MSG Night 1"), the script cannot guess the date. You must enter the date manually in the pop-up window (format: `YYYY-MM-DD`) so the script can look up the correct show info.
